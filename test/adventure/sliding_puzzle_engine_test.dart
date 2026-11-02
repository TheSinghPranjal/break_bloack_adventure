import 'package:break_block_adventure/features/adventure/engine/level_validator.dart';
import 'package:break_block_adventure/features/adventure/engine/sliding_puzzle_engine.dart';
import 'package:break_block_adventure/features/adventure/models/puzzle_models.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = SlidingPuzzleEngine();

PuzzleBlock blk(
  String id,
  int r,
  int c, {
  String? color,
  BlockKind kind = BlockKind.normal,
  MoveAxis axis = MoveAxis.both,
  int w = 1,
  int h = 1,
  int lock = 0,
  int hp = 1,
}) => PuzzleBlock(
  id: id,
  kind: kind,
  row: r,
  col: c,
  color: color,
  axis: axis,
  width: w,
  height: h,
  lockClears: lock,
  hp: hp,
);

PuzzleLevel lvl(
  List<PuzzleBlock> blocks, {
  Map<Cell, String> targets = const {},
  Set<Cell> stars = const {},
  Set<Cell> exits = const {},
  List<PuzzleObjective> objectives = const [PuzzleObjective(ObjectiveType.clearTargets)],
  int moveLimit = 10,
  MatchRule rule = const MatchRule.target(),
  bool chain = false,
  int size = 6,
}) => PuzzleLevel(
  worldId: 1,
  levelId: 1,
  rows: size,
  columns: size,
  moveLimit: moveLimit,
  objectives: objectives,
  blocks: blocks,
  targets: targets,
  stars: stars,
  exits: exits,
  matchRule: rule,
  chainReactions: chain,
  twoStarMoves: 3,
  threeStarMoves: 2,
);

MoveOutcome mv(PuzzleLevel l, PuzzleState s, String id, Direction d, int n) {
  final o = engine.moveBlock(l, s, PuzzleMove(id, d, n));
  expect(o, isNotNull, reason: 'move $id $d $n should be valid');
  return o!;
}

void main() {
  group('movement', () {
    test('slides along axis and counts a move', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal)],
        targets: {const Cell(5, 5): 'red'},
      );
      final s = engine.initializeLevel(l);
      expect(engine.maxDistance(l, s, 'a', Direction.right), 5);
      final o = mv(l, s, 'a', Direction.right, 3);
      expect(o.state.blockById('a')!.col, 3);
      expect(o.state.movesUsed, 1);
    });

    test('cannot move against its axis, off the board, or diagonally', () {
      final l = lvl(
        [blk('a', 0, 0, axis: MoveAxis.horizontal)],
        targets: {const Cell(5, 5): 'red'},
        objectives: const [PuzzleObjective(ObjectiveType.clearCount, target: 1)],
      );
      final s = engine.initializeLevel(l);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.down, 1)), isFalse);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.left, 1)), isFalse);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.right, 6)), isFalse);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.right, 0)), isFalse);
      expect(engine.moveBlock(l, s, const PuzzleMove('a', Direction.down, 1)), isNull);
    });

    test('collides with blocks and stones', () {
      final l = lvl(
        [blk('a', 0, 0), blk('b', 0, 3), blk('s', 3, 0, kind: BlockKind.stone)],
        objectives: const [PuzzleObjective(ObjectiveType.clearCount, target: 1)],
      );
      final s = engine.initializeLevel(l);
      expect(engine.maxDistance(l, s, 'a', Direction.right), 2);
      expect(engine.maxDistance(l, s, 'a', Direction.down), 2);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.right, 3)), isFalse);
      expect(engine.maxDistance(l, s, 's', Direction.up), 0);
    });

    test('long blocks move as one object and collide with every cell', () {
      final l = lvl(
        [blk('long', 2, 0, w: 3, axis: MoveAxis.horizontal), blk('x', 2, 5)],
        objectives: const [PuzzleObjective(ObjectiveType.clearCount, target: 1)],
      );
      final s = engine.initializeLevel(l);
      expect(engine.maxDistance(l, s, 'long', Direction.right), 2);
      final o = mv(l, s, 'long', Direction.right, 2);
      expect(o.state.blockById('long')!.cells.toList(), [const Cell(2, 2), const Cell(2, 3), const Cell(2, 4)]);
    });

    test('locked block cannot move until enough clears', () {
      final l = lvl(
        [
          blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal),
          blk('lk', 3, 0, color: 'blue', lock: 1, axis: MoveAxis.horizontal),
        ],
        targets: {const Cell(0, 5): 'red', const Cell(3, 5): 'blue'},
        objectives: const [PuzzleObjective(ObjectiveType.clearTargets), PuzzleObjective(ObjectiveType.freeLocked)],
      );
      var s = engine.initializeLevel(l);
      expect(engine.maxDistance(l, s, 'lk', Direction.right), 0);
      s = mv(l, s, 'a', Direction.right, 5).state;
      expect(engine.checkObjectives(l, s).last.done, isTrue);
      final o = mv(l, s, 'lk', Direction.right, 5);
      expect(o.state.status, PuzzleStatus.won);
    });
  });

  group('matching & destruction', () {
    test('block on matching pad clears and consumes pad', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red'), blk('b', 2, 2, color: 'blue')],
        targets: {const Cell(0, 4): 'red', const Cell(5, 2): 'blue'},
      );
      final o = mv(l, engine.initializeLevel(l), 'a', Direction.right, 4);
      expect(o.cleared.map((b) => b.id), ['a']);
      expect(o.state.targets.containsKey(const Cell(0, 4)), isFalse);
      expect(o.state.clearedByColor['red'], 1);
      expect(o.state.status, PuzzleStatus.playing);
    });

    test('wrong colour on pad does not clear; passing over pad does not clear', () {
      final l = lvl([blk('a', 0, 0, color: 'blue')], targets: {const Cell(0, 2): 'red', const Cell(5, 5): 'blue'});
      final s = engine.initializeLevel(l);
      expect(mv(l, s, 'a', Direction.right, 2).cleared, isEmpty);
      expect(mv(l, s, 'a', Direction.right, 5).cleared, isEmpty);
    });

    test('long block clears only when every cell is on its pads', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red', w: 2, axis: MoveAxis.horizontal)],
        targets: {const Cell(0, 3): 'red', const Cell(0, 4): 'red'},
      );
      final s = engine.initializeLevel(l);
      expect(mv(l, s, 'a', Direction.right, 2).cleared, isEmpty); // covers (0,2),(0,3)
      final o = mv(l, s, 'a', Direction.right, 3);
      expect(o.cleared.length, 1);
      expect(o.state.status, PuzzleStatus.won);
    });

    test('touching same-colour blocks do not clear under the target rule', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red'), blk('b', 0, 2, color: 'red')],
        targets: {const Cell(5, 5): 'red'},
      );
      expect(mv(l, engine.initializeLevel(l), 'a', Direction.right, 1).cleared, isEmpty);
    });

    test('group rule clears a connected group of 3', () {
      final l = lvl(
        [
          blk('a', 0, 0, color: 'red'),
          blk('b', 1, 1, color: 'red'),
          blk('c', 1, 2, color: 'red'),
          blk('d', 4, 4, color: 'blue'),
        ],
        rule: const MatchRule.group(3),
        objectives: const [PuzzleObjective(ObjectiveType.clearColor, color: 'red', target: 3)],
      );
      final s = engine.initializeLevel(l);
      final o = mv(l, s, 'a', Direction.down, 1); // (1,0) joins (1,1),(1,2)
      expect(o.cleared.map((b) => b.id).toSet(), {'a', 'b', 'c'});
      expect(o.state.status, PuzzleStatus.won);
    });

    test('group of 2 is not enough', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red'), blk('b', 1, 1, color: 'red')],
        rule: const MatchRule.group(3),
        objectives: const [PuzzleObjective(ObjectiveType.clearAll)],
      );
      expect(mv(l, engine.initializeLevel(l), 'a', Direction.down, 1).cleared, isEmpty);
    });

    test('ice is hit when a block stops against it and breaks at 0 hp', () {
      final l = lvl(
        [blk('a', 0, 0), blk('ice', 0, 5, kind: BlockKind.ice, hp: 2)],
        objectives: const [PuzzleObjective(ObjectiveType.destroyIce)],
      );
      var s = engine.initializeLevel(l);
      var o = mv(l, s, 'a', Direction.right, 4);
      expect(o.iceHits, ['ice']);
      expect(o.state.blockById('ice')!.hp, 1);
      s = mv(l, o.state, 'a', Direction.left, 1).state;
      o = mv(l, s, 'a', Direction.right, 1);
      expect(o.state.blockById('ice'), isNull);
      expect(o.state.status, PuzzleStatus.won);
    });

    test('bomb explodes destructible blocks in radius but not stones/keys', () {
      final l = lvl(
        [
          blk('bomb', 0, 0, kind: BlockKind.bomb, color: 'red'),
          blk('n1', 2, 3),
          blk('ice', 3, 2, kind: BlockKind.ice),
          blk('st', 3, 4, kind: BlockKind.stone),
          blk('far', 5, 5, color: 'blue'),
        ],
        targets: {const Cell(2, 2): 'red', const Cell(0, 5): 'blue'},
        objectives: const [PuzzleObjective(ObjectiveType.clearCount, target: 3)],
      );
      var s = engine.initializeLevel(l);
      s = mv(l, s, 'bomb', Direction.down, 2).state; // (2,0)
      final o = mv(l, s, 'bomb', Direction.right, 2); // onto pad (2,2)
      expect(o.cleared.map((b) => b.id).toSet(), {'bomb', 'n1', 'ice'});
      expect(o.explosions, isNotEmpty);
      expect(o.state.blockById('st'), isNotNull);
      expect(o.state.blockById('far'), isNotNull);
      expect(o.state.status, PuzzleStatus.won);
    });

    test('chain reactions only when enabled', () {
      List<PuzzleBlock> blocks() => [
        blk('b1', 0, 0, kind: BlockKind.bomb, color: 'red'),
        blk('b2', 1, 2, kind: BlockKind.bomb, color: 'blue'),
        blk('n', 2, 3),
      ];
      final targets = {const Cell(0, 1): 'red', const Cell(5, 5): 'blue'};
      const obj = [PuzzleObjective(ObjectiveType.clearCount, target: 10)];
      final off = lvl(blocks(), targets: targets, objectives: obj);
      final on = lvl(blocks(), targets: targets, objectives: obj, chain: true);
      expect(mv(off, engine.initializeLevel(off), 'b1', Direction.right, 1).cleared.length, 2);
      expect(mv(on, engine.initializeLevel(on), 'b1', Direction.right, 1).cleared.length, 3);
    });

    test('stars are collected along the path', () {
      final l = lvl(
        [blk('a', 0, 0)],
        stars: {const Cell(0, 2), const Cell(0, 4)},
        objectives: const [PuzzleObjective(ObjectiveType.collectStars)],
      );
      final o = mv(l, engine.initializeLevel(l), 'a', Direction.right, 5);
      expect(o.starsCollected.length, 2);
      expect(o.state.status, PuzzleStatus.won);
    });

    test('key reaching exit leaves the board', () {
      final l = lvl(
        [blk('k', 2, 0, kind: BlockKind.key)],
        exits: {const Cell(2, 5)},
        objectives: const [PuzzleObjective(ObjectiveType.reachExit, target: 1)],
      );
      final o = mv(l, engine.initializeLevel(l), 'k', Direction.right, 5);
      expect(o.exited?.id, 'k');
      expect(o.state.status, PuzzleStatus.won);
    });
  });

  group('objectives, win & loss', () {
    test('multiple objectives must all be satisfied', () {
      final l = lvl(
        [
          blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal),
          blk('b', 5, 0, color: 'blue', axis: MoveAxis.horizontal),
        ],
        targets: {const Cell(0, 5): 'red', const Cell(5, 5): 'blue'},
        objectives: const [
          PuzzleObjective(ObjectiveType.clearColor, color: 'red', target: 1),
          PuzzleObjective(ObjectiveType.clearTargets),
        ],
      );
      var s = engine.initializeLevel(l);
      s = mv(l, s, 'a', Direction.right, 5).state;
      final p = engine.checkObjectives(l, s);
      expect(p[0].done, isTrue);
      expect(p[1].done, isFalse);
      expect(s.status, PuzzleStatus.playing);
      expect(mv(l, s, 'b', Direction.right, 5).state.status, PuzzleStatus.won);
    });

    test('running out of moves loses', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal)],
        targets: {const Cell(0, 5): 'red'},
        moveLimit: 2,
      );
      var s = engine.initializeLevel(l);
      s = mv(l, s, 'a', Direction.right, 1).state;
      expect(s.status, PuzzleStatus.playing);
      s = mv(l, s, 'a', Direction.right, 1).state;
      expect(s.status, PuzzleStatus.lost);
      expect(engine.validateMove(l, s, const PuzzleMove('a', Direction.right, 1)), isFalse);
    });

    test('winning on the last move is a win, not a loss', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal)],
        targets: {const Cell(0, 5): 'red'},
        moveLimit: 1,
      );
      expect(mv(l, engine.initializeLevel(l), 'a', Direction.right, 5).state.status, PuzzleStatus.won);
    });

    test('star rating uses level thresholds', () {
      final l = lvl([blk('a', 0, 0)]);
      expect(l.starsFor(2), 3);
      expect(l.starsFor(3), 2);
      expect(l.starsFor(9), 1);
    });
  });

  group('undo & hints', () {
    test('undo restores positions, objectives, pads and move count', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red'), blk('b', 3, 3, color: 'blue')],
        targets: {const Cell(0, 4): 'red', const Cell(5, 5): 'blue'},
      );
      final s0 = engine.initializeLevel(l);
      final o = mv(l, s0, 'a', Direction.right, 4);
      final history = [s0];
      final u = engine.undoMove(history)!;
      expect(u.state.blockById('a')!.col, 0);
      expect(u.state.targets.length, 2);
      expect(u.state.movesUsed, 0);
      expect(u.history, isEmpty);
      expect(o.state.targets.length, 1);
      expect(engine.undoMove(const []), isNull);
    });

    test('hint returns the first move of a shortest solution without moving', () {
      // Red needs blocker moved first.
      final l = lvl(
        [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal), blk('x', 0, 2, axis: MoveAxis.vertical)],
        targets: {const Cell(0, 4): 'red'},
      );
      final s = engine.initializeLevel(l);
      final hint = engine.getHint(l, s)!;
      expect(hint.blockId, 'x');
      expect(s.blockById('x')!.row, 0); // not executed
      final sol = engine.solve(l, s)!;
      expect(sol.length, 2);
    });

    test('hint is null for an unsolvable state', () {
      final l = lvl(
        [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal)],
        targets: {const Cell(3, 3): 'red'},
      );
      expect(engine.getHint(l, engine.initializeLevel(l)), isNull);
    });
  });

  group('validator', () {
    test('rejects overlaps, out of bounds and unsolvable levels', () {
      const v = LevelValidator();
      expect(v.validate(lvl([blk('a', 0, 0), blk('b', 0, 0)])).isValid, isFalse);
      expect(v.validate(lvl([blk('a', 6, 0)])).isValid, isFalse);
      expect(
        v
            .validate(
              lvl(
                [blk('a', 0, 0, color: 'red', axis: MoveAxis.horizontal)],
                targets: {const Cell(3, 3): 'red'},
              ),
            )
            .isValid,
        isFalse,
      );
      expect(v.validate(lvl([blk('a', 0, 0, color: 'red')], targets: {const Cell(0, 0): 'red'})).isValid, isFalse);
    });
    test('accepts a solvable level and reports the solution', () {
      final r = const LevelValidator().validate(
        lvl([blk('a', 0, 0, color: 'red')], targets: {const Cell(0, 3): 'red'}),
      );
      expect(r.isValid, isTrue, reason: r.errors.join());
      expect(r.solution!.length, 1);
    });
  });

  test('level JSON round-trip', () {
    final l = lvl(
      [blk('a', 0, 0, color: 'red', w: 2, axis: MoveAxis.horizontal), blk('i', 3, 3, kind: BlockKind.ice, hp: 2)],
      targets: {const Cell(0, 3): 'red', const Cell(0, 4): 'red'},
      stars: {const Cell(1, 1)},
      exits: {const Cell(5, 0)},
    );
    final back = PuzzleLevel.fromJson(l.toJson());
    expect(back.blocks.length, 2);
    expect(back.blocks.first.width, 2);
    expect(back.blocks.last.hp, 2);
    expect(back.targets, l.targets);
    expect(back.stars, l.stars);
    expect(back.exits, l.exits);
    expect(back.threeStarMoves, 2);
  });
}
