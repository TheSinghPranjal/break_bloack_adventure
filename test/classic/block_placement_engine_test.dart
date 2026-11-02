import 'dart:math';

import 'package:break_block_adventure/features/classic/engine/block_placement_engine.dart';
import 'package:break_block_adventure/features/classic/models/block_shape.dart';
import 'package:break_block_adventure/features/classic/models/classic_state.dart';
import 'package:break_block_adventure/features/classic/models/shape_library.dart';
import 'package:flutter_test/flutter_test.dart';

ClassicGameState stateWith(ClassicBoard board, List<String?> trayIds) =>
    ClassicGameState(board: board, tray: [for (final id in trayIds) id == null ? null : ShapeLibrary.get(id)]);

void main() {
  late BlockPlacementEngine engine;
  setUp(() => engine = BlockPlacementEngine(random: Random(42)));

  group('shape library', () {
    test('has at least 30 unique shapes with valid coordinates', () {
      expect(ShapeLibrary.all.length, greaterThanOrEqualTo(30));
      expect(ShapeLibrary.byId.length, ShapeLibrary.all.length);
      for (final s in ShapeLibrary.all) {
        expect(s.cells.toSet().length, s.cells.length, reason: s.id);
        expect(s.cells.every((c) => c.row >= 0 && c.col >= 0), isTrue);
        // normalised: touches row 0 and col 0
        expect(s.cells.any((c) => c.row == 0), isTrue, reason: s.id);
        expect(s.cells.any((c) => c.col == 0), isTrue, reason: s.id);
      }
    });
  });

  group('initializeBoard', () {
    test('creates empty 10x10 by default with 3 shapes', () {
      final s = engine.initializeBoard();
      expect(s.board.size, 10);
      expect(s.board.filledCount, 0);
      expect(s.tray.length, 3);
      expect(s.tray.every((e) => e != null), isTrue);
    });
    test('supports 8x8', () {
      expect(engine.initializeBoard(size: 8).board.size, 8);
    });
  });

  group('validatePlacement', () {
    final board = ClassicBoard.empty(10);
    test('valid inside board', () {
      expect(engine.validatePlacement(board, ShapeLibrary.get('sq3'), const GridPoint(7, 7)), isTrue);
    });
    test('invalid outside board', () {
      expect(engine.validatePlacement(board, ShapeLibrary.get('sq3'), const GridPoint(8, 0)), isFalse);
      expect(engine.validatePlacement(board, ShapeLibrary.get('h2'), const GridPoint(0, -1)), isFalse);
    });
    test('invalid when overlapping', () {
      final b = board.withCells({const GridPoint(1, 1): 1});
      expect(engine.validatePlacement(b, ShapeLibrary.get('sq2'), const GridPoint(0, 0)), isFalse);
    });
  });

  group('placeBlock', () {
    test('fills cells and scores 1 per cell', () {
      final s = stateWith(ClassicBoard.empty(10), ['sq2', 'single', 'h2']);
      final r = engine.placeBlock(s, 0, const GridPoint(0, 0))!;
      expect(r.state.board.filledCount, 4);
      expect(r.pointsGained, 4);
      expect(r.state.tray[0], isNull);
      expect(r.state.shapesPlaced, 1);
    });

    test('invalid placement returns null and leaves state intact', () {
      final s = stateWith(ClassicBoard.empty(10), ['sq3', 'single', 'h2']);
      expect(engine.placeBlock(s, 0, const GridPoint(9, 9)), isNull);
      expect(engine.placeBlock(s, 5, const GridPoint(0, 0)), isNull);
    });

    test('used slot cannot be placed again', () {
      final s = stateWith(ClassicBoard.empty(10), [null, 'single', 'h2']);
      expect(engine.placeBlock(s, 0, const GridPoint(0, 0)), isNull);
    });

    test('refills tray when all three shapes used', () {
      var s = stateWith(ClassicBoard.empty(10), ['single', 'single', 'single']);
      s = engine.placeBlock(s, 0, const GridPoint(0, 0))!.state;
      s = engine.placeBlock(s, 1, const GridPoint(0, 2))!.state;
      final r = engine.placeBlock(s, 2, const GridPoint(0, 4))!;
      expect(r.trayRefilled, isTrue);
      expect(r.state.tray.every((e) => e != null), isTrue);
    });
  });

  group('line clearing', () {
    test('row clear', () {
      final b = ClassicBoard.fromRows(['#########.', for (var i = 0; i < 9; i++) '..........']);
      final r = engine.placeBlock(stateWith(b, ['single', 'h2', 'h2']), 0, const GridPoint(0, 9))!;
      expect(r.clearedRows, [0]);
      expect(r.clearedColumns, isEmpty);
      expect(r.state.board.filledCount, 0);
      expect(r.pointsGained, 1 + 10);
      expect(r.state.combo, 1);
    });

    test('column clear', () {
      final b = ClassicBoard.fromRows([for (var i = 0; i < 9; i++) '#.........', '..........']);
      final r = engine.placeBlock(stateWith(b, ['single', 'h2', 'h2']), 0, const GridPoint(9, 0))!;
      expect(r.clearedColumns, [0]);
      expect(r.state.board.filledCount, 0);
    });

    test('simultaneous rows clear together (2 lines = 30)', () {
      final b = ClassicBoard.fromRows(['########..', '########..', for (var i = 0; i < 8; i++) '..........']);
      final r = engine.placeBlock(stateWith(b, ['sq2', 'h2', 'h2']), 0, const GridPoint(0, 8))!;
      expect(r.clearedRows, [0, 1]);
      expect(r.pointsGained, 4 + 30);
      expect(r.state.multiLineClears, 1);
      expect(r.state.board.filledCount, 0);
    });

    test('intersecting row+column cells counted once', () {
      // Row 0 full except (0,0); column 0 full except (0,0).
      final b = ClassicBoard.fromRows(['.#########', for (var i = 0; i < 9; i++) '#.........']);
      final r = engine.placeBlock(stateWith(b, ['single', 'h2', 'h2']), 0, const GridPoint(0, 0))!;
      expect(r.clearedRows, [0]);
      expect(r.clearedColumns, [0]);
      expect(r.clearedCells.length, 19); // 10 + 10 - 1 shared
      expect(r.pointsGained, 1 + 30);
      expect(r.state.board.filledCount, 0);
    });

    test('combo increases on consecutive clears and resets otherwise', () {
      final b = ClassicBoard.fromRows(['#########.', '#########.', for (var i = 0; i < 8; i++) '..........']);
      var s = stateWith(b, ['single', 'single', 'single']);
      var r = engine.placeBlock(s, 0, const GridPoint(0, 9))!;
      expect(r.state.combo, 1);
      r = engine.placeBlock(r.state, 1, const GridPoint(1, 9))!;
      expect(r.state.combo, 2);
      expect(r.pointsGained, 1 + 10 + 10); // combo bonus 10*(2-1)
      s = r.state;
      r = engine.placeBlock(s, 2, const GridPoint(5, 5))!;
      expect(r.state.combo, 0);
      expect(r.state.maxCombo, 2);
    });
  });

  group('score config', () {
    test('line bonus table and 5+ formula', () {
      const c = ClassicScoringConfig();
      expect([1, 2, 3, 4].map(c.lineBonus), [10, 30, 60, 100]);
      expect(c.lineBonus(5), 150);
      expect(c.lineBonus(6), 200);
      expect(engine.calculateScore(cellsPlaced: 3, linesCleared: 0, combo: 0), 3);
    });
  });

  group('game over', () {
    test('not over when any remaining shape fits somewhere', () {
      // Only (9,9) empty.
      final rows = [for (var i = 0; i < 9; i++) '##########', '#########.'];
      final s = stateWith(ClassicBoard.fromRows(rows), ['sq3', null, 'single']);
      expect(engine.checkGameOver(s), isFalse);
    });

    test('over when no remaining shape fits', () {
      final rows = [for (var i = 0; i < 9; i++) '##########', '#########.'];
      final s = stateWith(ClassicBoard.fromRows(rows), ['sq3', 'h2', null]);
      expect(engine.checkGameOver(s), isTrue);
    });

    test('ignores used slots (does not test shapes not in tray)', () {
      final rows = [for (var i = 0; i < 9; i++) '##########', '#########.'];
      final s = stateWith(ClassicBoard.fromRows(rows), [null, 'v2', null]);
      expect(engine.checkGameOver(s), isTrue);
    });

    test('exhaustive search finds a fit in an unusual hole', () {
      final rows = ['##########', '##########', '#####..###', '######.###', for (var i = 0; i < 6; i++) '##########'];
      final s = stateWith(ClassicBoard.fromRows(rows), ['c90', 'sq3', 'h5']);
      expect(engine.checkGameOver(s), isFalse);
    });

    test('placement that leaves no fit flags game over', () {
      // Two holes per row/column, never orthogonally adjacent: no line is
      // full and no 2-cell straight shape fits.
      final rows = [
        for (var i = 0; i < 10; i++) List.generate(10, (c) => c == i || c == (i + 5) % 10 ? '.' : '#').join(),
      ];
      final s = stateWith(ClassicBoard.fromRows(rows), ['single', 'sq2', 'h2']);
      expect(engine.checkGameOver(s), isFalse);
      final r = engine.placeBlock(s, 0, const GridPoint(0, 0))!;
      expect(r.linesCleared, 0);
      expect(r.state.isGameOver, isTrue);
    });
  });

  group('undo', () {
    test('restores board, tray and score including line clears', () {
      final b = ClassicBoard.fromRows(['#########.', for (var i = 0; i < 9; i++) '..........']);
      final s0 = stateWith(b, ['single', 'h2', 'h2']);
      final r = engine.placeBlock(s0, 0, const GridPoint(0, 9))!;
      final undone = engine.undoPlacement(r.state)!;
      expect(undone.board.cells, s0.board.cells);
      expect(undone.tray.map((e) => e?.id), s0.tray.map((e) => e?.id));
      expect(undone.score, 0);
      expect(undone.linesCleared, 0);
      expect(undone.canUndo, isFalse);
    });

    test('nothing to undo returns null', () {
      expect(engine.undoPlacement(engine.initializeBoard()), isNull);
    });
  });

  group('boosters', () {
    final rows = [for (var i = 0; i < 9; i++) '##########', '#########.'];
    test('hammer removes one occupied cell and revives game', () {
      final s = stateWith(ClassicBoard.fromRows(rows), ['h2', null, null]).copyWith(isGameOver: true);
      final n = engine.hammer(s, const GridPoint(9, 8))!;
      expect(n.board.isEmpty(9, 8), isTrue);
      expect(n.isGameOver, isFalse);
    });
    test('hammer on empty cell is rejected', () {
      final s = stateWith(ClassicBoard.empty(10), ['h2', null, null]);
      expect(engine.hammer(s, const GridPoint(0, 0)), isNull);
    });
    test('remove cells limited to 3', () {
      final s = stateWith(ClassicBoard.fromRows(rows), ['h2', null, null]);
      expect(engine.removeCells(s, [for (var c = 0; c < 4; c++) GridPoint(0, c)]), isNull);
      expect(engine.removeCells(s, [for (var c = 0; c < 3; c++) GridPoint(0, c)])!.board.filledCount, 96);
    });
    test('shuffle replaces tray', () {
      final s = stateWith(ClassicBoard.empty(10), ['sq3', null, null]);
      final n = engine.shuffle(s)!;
      expect(n.remainingShapes.length, 3);
    });
    test('rainbow fills an empty cell and clears completed lines', () {
      final s = stateWith(ClassicBoard.fromRows(rows), ['sq3', null, null]);
      final r = engine.rainbow(s, const GridPoint(9, 9))!;
      expect(r.linesCleared, 20);
      expect(r.state.board.filledCount, 0);
    });
    test('extra space clears the fullest row', () {
      final s = stateWith(
        ClassicBoard.fromRows(['..........', '#####.....', for (var i = 0; i < 8; i++) '..........']),
        ['sq3', null, null],
      );
      expect(engine.extraSpace(s)!.board.filledCount, 0);
      expect(engine.extraSpace(stateWith(ClassicBoard.empty(10), ['h2', null, null])), isNull);
    });
  });

  test('state JSON round-trip', () {
    final s = engine.placeBlock(engine.initializeBoard(), 0, const GridPoint(0, 0))!.state;
    final back = ClassicGameState.fromJson(s.toJson());
    expect(back.board.cells, s.board.cells);
    expect(back.score, s.score);
    expect(back.tray.map((e) => e?.id), s.tray.map((e) => e?.id));
  });

  test('random play never places overlapping blocks and game-over is exact', () {
    final e = BlockPlacementEngine(random: Random(7));
    var s = e.initializeBoard();
    for (var turn = 0; turn < 500 && !s.isGameOver; turn++) {
      PlacementResult? r;
      outer:
      for (var i = 0; i < 3; i++) {
        final shape = s.tray[i];
        if (shape == null) continue;
        for (var row = 0; row < 10; row++) {
          for (var col = 0; col < 10; col++) {
            r = e.placeBlock(s, i, GridPoint(row, col));
            if (r != null) break outer;
          }
        }
      }
      expect(r, isNotNull, reason: 'game not over but no placement found');
      s = r!.state;
    }
    if (s.isGameOver) {
      for (final shape in s.remainingShapes) {
        expect(e.canPlaceShape(s.board, shape), isFalse);
      }
    }
  });
}
