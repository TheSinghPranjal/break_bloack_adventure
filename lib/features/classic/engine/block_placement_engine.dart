import 'dart:math';

import '../models/block_shape.dart';
import '../models/classic_state.dart';
import '../models/shape_library.dart';

/// Deterministic rules engine for Classic mode. Pure Dart, no UI.
class BlockPlacementEngine {
  BlockPlacementEngine({
    this.config = const ClassicScoringConfig(),
    Random? random,
    List<BlockShape>? shapes,
    this.maxUndoDepth = 5,
  }) : _random = random ?? Random(),
       shapes = shapes ?? ShapeLibrary.all;

  final ClassicScoringConfig config;
  final List<BlockShape> shapes;
  final int maxUndoDepth;
  final Random _random;

  static const traySize = 3;

  // ---------------------------------------------------------------- setup

  ClassicGameState initializeBoard({int size = 10}) {
    final board = ClassicBoard.empty(size);
    return ClassicGameState(board: board, tray: generateNextShapes(board));
  }

  // ------------------------------------------------------------ placement

  bool validatePlacement(ClassicBoard board, BlockShape shape, GridPoint origin) {
    for (final c in shape.cells) {
      final r = origin.row + c.row, col = origin.col + c.col;
      if (!board.inBounds(r, col) || !board.isEmpty(r, col)) return false;
    }
    return true;
  }

  /// Places tray shape [trayIndex] with its top-left at [origin].
  /// Returns `null` if the placement is invalid (state is untouched).
  PlacementResult? placeBlock(ClassicGameState state, int trayIndex, GridPoint origin) {
    if (state.isGameOver) return null;
    if (trayIndex < 0 || trayIndex >= state.tray.length) return null;
    final shape = state.tray[trayIndex];
    if (shape == null) return null;
    if (!validatePlacement(state.board, shape, origin)) return null;

    final placed = {for (final c in shape.cells) origin + c};
    var board = state.board.withCells({for (final p in placed) p: CellValue.fromColor(shape.colorIndex)});

    // Detect all completed lines *before* modifying the board.
    final rows = getCompletedRows(board);
    final cols = getCompletedColumns(board);
    final cleared = clearedCellsFor(board.size, rows, cols);
    board = clearLines(board, rows, cols);

    final lines = rows.length + cols.length;
    final combo = lines > 0 ? state.combo + 1 : 0;
    final points = calculateScore(cellsPlaced: shape.size, linesCleared: lines, combo: combo);

    var tray = List<BlockShape?>.of(state.tray)..[trayIndex] = null;
    var refilled = false;
    if (tray.every((s) => s == null)) {
      tray = generateNextShapes(board);
      refilled = true;
    }

    final stack = [...state.undoStack, state.snapshot];
    if (stack.length > maxUndoDepth) stack.removeAt(0);

    var next = state.copyWith(
      board: board,
      tray: tray,
      score: state.score + points,
      combo: combo,
      maxCombo: max(state.maxCombo, combo),
      linesCleared: state.linesCleared + lines,
      shapesPlaced: state.shapesPlaced + 1,
      multiLineClears: state.multiLineClears + (lines >= 2 ? 1 : 0),
      undoStack: stack,
    );
    next = next.copyWith(isGameOver: checkGameOver(next));

    return PlacementResult(
      state: next,
      placedCells: placed,
      clearedRows: rows,
      clearedColumns: cols,
      clearedCells: cleared,
      pointsGained: points,
      trayRefilled: refilled,
    );
  }

  // --------------------------------------------------------- line clearing

  List<int> getCompletedRows(ClassicBoard board) => [
    for (var r = 0; r < board.size; r++)
      if (List.generate(board.size, (c) => board.at(r, c)).every((v) => v != CellValue.empty)) r,
  ];

  List<int> getCompletedColumns(ClassicBoard board) => [
    for (var c = 0; c < board.size; c++)
      if (List.generate(board.size, (r) => board.at(r, c)).every((v) => v != CellValue.empty)) c,
  ];

  /// Unique cells covered by the given rows/columns (intersections once).
  Set<GridPoint> clearedCellsFor(int size, List<int> rows, List<int> cols) => {
    for (final r in rows)
      for (var c = 0; c < size; c++) GridPoint(r, c),
    for (final c in cols)
      for (var r = 0; r < size; r++) GridPoint(r, c),
  };

  ClassicBoard clearLines(ClassicBoard board, List<int> rows, List<int> cols) {
    if (rows.isEmpty && cols.isEmpty) return board;
    return board.withCells({for (final p in clearedCellsFor(board.size, rows, cols)) p: CellValue.empty});
  }

  int calculateScore({required int cellsPlaced, required int linesCleared, required int combo}) {
    return cellsPlaced * config.pointsPerCell +
        config.lineBonus(linesCleared) +
        (linesCleared > 0 ? config.comboBonus(combo) : 0);
  }

  // ------------------------------------------------------- shape generation

  BlockShape _weightedPick() {
    final total = shapes.fold<int>(0, (s, e) => s + e.weight);
    var roll = _random.nextInt(total);
    for (final s in shapes) {
      roll -= s.weight;
      if (roll < 0) return s;
    }
    return shapes.last;
  }

  /// Generates three shapes. Tries to guarantee at least one placeable shape
  /// whenever the board allows any shape at all (fair generation).
  List<BlockShape> generateNextShapes(ClassicBoard board) {
    List<BlockShape> pick() => [for (var i = 0; i < traySize; i++) _weightedPick()];
    var set = pick();
    for (var attempt = 0; attempt < 30 && !canPlaceAnyShape(board, set); attempt++) {
      set = pick();
    }
    if (!canPlaceAnyShape(board, set)) {
      // Fall back to the smallest shape that fits anywhere, if any exists.
      final fitting = shapes.where((s) => canPlaceShape(board, s)).toList()..sort((a, b) => a.size.compareTo(b.size));
      if (fitting.isNotEmpty) set[0] = fitting.first;
    }
    return set;
  }

  // -------------------------------------------------------------- game over

  bool canPlaceShape(ClassicBoard board, BlockShape shape) {
    for (var r = 0; r <= board.size - shape.height; r++) {
      for (var c = 0; c <= board.size - shape.width; c++) {
        if (validatePlacement(board, shape, GridPoint(r, c))) return true;
      }
    }
    return false;
  }

  bool canPlaceAnyShape(ClassicBoard board, List<BlockShape> shapes) => shapes.any((s) => canPlaceShape(board, s));

  /// Game over only when *none* of the actual remaining shapes fits anywhere.
  bool checkGameOver(ClassicGameState state) {
    final remaining = state.remainingShapes;
    if (remaining.isEmpty) return false;
    return !canPlaceAnyShape(state.board, remaining);
  }

  // ------------------------------------------------------------------- undo

  ClassicGameState? undoPlacement(ClassicGameState state) {
    if (state.undoStack.isEmpty) return null;
    final stack = List<ClassicGameState>.of(state.undoStack);
    final previous = stack.removeLast();
    return previous.copyWith(undoStack: stack, isGameOver: false);
  }

  // --------------------------------------------------------------- boosters
  // Boosters return null when they would have no valid effect, so the caller
  // never charges for a no-op. They reset the undo history to keep the
  // board/tray/score history consistent.

  ClassicGameState _afterBooster(ClassicGameState s) {
    final next = s.copyWith(undoStack: const []);
    return next.copyWith(isGameOver: checkGameOver(next));
  }

  /// Hammer: destroy a single occupied cell.
  ClassicGameState? hammer(ClassicGameState state, GridPoint cell) => removeCells(state, [cell], maxCells: 1);

  /// Remove Block: clear up to [maxCells] selected occupied cells.
  ClassicGameState? removeCells(ClassicGameState state, List<GridPoint> cells, {int maxCells = 3}) {
    final unique = cells.toSet();
    if (unique.isEmpty || unique.length > maxCells) return null;
    for (final p in unique) {
      if (!state.board.inBounds(p.row, p.col) || state.board.isEmpty(p.row, p.col)) {
        return null;
      }
    }
    return _afterBooster(state.copyWith(board: state.board.withCells({for (final p in unique) p: CellValue.empty})));
  }

  /// Shuffle: replace the remaining tray shapes with a new set.
  ClassicGameState? shuffle(ClassicGameState state) {
    if (state.remainingShapes.isEmpty) return null;
    return _afterBooster(state.copyWith(tray: generateNextShapes(state.board)));
  }

  /// Rainbow: fill one empty cell with a wild block, then resolve any lines
  /// it completes. Returns the resulting placement for animation.
  PlacementResult? rainbow(ClassicGameState state, GridPoint cell) {
    final b = state.board;
    if (!b.inBounds(cell.row, cell.col) || !b.isEmpty(cell.row, cell.col)) {
      return null;
    }
    var board = b.withCells({cell: CellValue.wild});
    final rows = getCompletedRows(board);
    final cols = getCompletedColumns(board);
    final cleared = clearedCellsFor(board.size, rows, cols);
    board = clearLines(board, rows, cols);
    final lines = rows.length + cols.length;
    final points = config.lineBonus(lines);
    final next = _afterBooster(
      state.copyWith(board: board, score: state.score + points, linesCleared: state.linesCleared + lines),
    );
    return PlacementResult(
      state: next,
      placedCells: {cell},
      clearedRows: rows,
      clearedColumns: cols,
      clearedCells: cleared,
      pointsGained: points,
      trayRefilled: false,
    );
  }

  /// Extra Space (rescue): clears the most crowded row (ties: topmost).
  ClassicGameState? extraSpace(ClassicGameState state) {
    final b = state.board;
    var bestRow = -1, bestCount = 0;
    for (var r = 0; r < b.size; r++) {
      final count = List.generate(b.size, (c) => b.at(r, c)).where((v) => v != CellValue.empty).length;
      if (count > bestCount) {
        bestCount = count;
        bestRow = r;
      }
    }
    if (bestRow < 0) return null;
    return _afterBooster(
      state.copyWith(board: b.withCells({for (var c = 0; c < b.size; c++) GridPoint(bestRow, c): CellValue.empty})),
    );
  }
}
