import 'dart:math';

import '../engine/level_validator.dart';
import '../engine/sliding_puzzle_engine.dart';
import '../models/puzzle_models.dart';
import 'world_catalog.dart';

/// Difficulty bands. Move-limit ranges follow the game design document.
class DifficultyBand {
  const DifficultyBand(this.name, this.minOpt, this.maxOpt, this.limitMin, this.limitMax, this.slack);
  final String name;
  final int minOpt, maxOpt; // optimal solution length window
  final int limitMin, limitMax; // configured move-limit range
  final int slack; // extra moves above optimal

  static const beginner = DifficultyBand('beginner', 1, 3, 15, 25, 12);
  static const easy = DifficultyBand('easy', 3, 5, 12, 20, 9);
  static const medium = DifficultyBand('medium', 4, 6, 10, 16, 6);
  static const hard = DifficultyBand('hard', 5, 7, 8, 13, 4);
  static const expert = DifficultyBand('expert', 5, 8, 6, 10, 2);

  static DifficultyBand forLevel(int n) => n <= 15
      ? beginner
      : n <= 35
      ? easy
      : n <= 60
      ? medium
      : n <= 85
      ? hard
      : expert;
}

/// Offline generator: random construction + BFS verification. Only levels
/// with a proven solution inside their move limit are emitted.
class LevelGenerator {
  LevelGenerator({int seed = 1, this.engine = const SlidingPuzzleEngine()}) : _rng = Random(seed);

  final Random _rng;
  final SlidingPuzzleEngine engine;

  static const colors = ['red', 'blue', 'green', 'yellow', 'purple'];

  PuzzleLevel generate(int worldId, int levelId, {int maxAttempts = 4000}) {
    final band = DifficultyBand.forLevel(levelId);
    final world = WorldCatalog.byId(worldId);
    final size = levelId <= 50 ? 6 : (levelId <= 85 ? 7 : 8);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final draft = _draft(worldId, levelId, size, band, world.mechanics);
      if (draft == null) continue;
      final probe = _withLimits(draft, band.maxOpt, band.maxOpt, band.maxOpt);
      final result = const LevelValidator(nodeLimit: 30000).validate(probe);
      final sol = result.solution;
      if (sol == null || sol.length < band.minOpt) continue;
      final opt = sol.length;
      final int limit = max(opt, (opt + band.slack).clamp(band.limitMin, band.limitMax).toInt());
      final three = opt + (band == DifficultyBand.beginner ? 1 : 0);
      final int two = min(limit, opt + max(1, band.slack ~/ 2));
      final level = _withLimits(draft, limit, two, three);
      if (const LevelValidator(nodeLimit: 60000).validate(level).isValid) return level;
    }
    throw StateError('Could not generate level $worldId-$levelId');
  }

  PuzzleLevel _withLimits(PuzzleLevel d, int limit, int two, int three) => PuzzleLevel(
    worldId: d.worldId,
    levelId: d.levelId,
    rows: d.rows,
    columns: d.columns,
    moveLimit: limit,
    twoStarMoves: two,
    threeStarMoves: three,
    difficulty: d.difficulty,
    objectives: d.objectives,
    blocks: d.blocks,
    targets: d.targets,
    stars: d.stars,
    exits: d.exits,
    matchRule: d.matchRule,
    chainReactions: d.chainReactions,
    rewardCoins: d.rewardCoins,
    tip: d.tip,
  );

  int _r(int n) => _rng.nextInt(n);
  bool _chance(double p) => _rng.nextDouble() < p;

  PuzzleLevel? _draft(int worldId, int levelId, int size, DifficultyBand band, Set<Mechanic> mech) {
    final occupied = <Cell>{};
    final blocks = <PuzzleBlock>[];
    final targets = <Cell, String>{};
    final stars = <Cell>{};
    final exits = <Cell>{};
    final objectives = <PuzzleObjective>[];
    var idSeq = 0;
    String nextId(String p) => '$p${idSeq++}';

    Cell randCell() => Cell(_r(size), _r(size));
    bool free(Iterable<Cell> cells) =>
        cells.every((c) => c.row >= 0 && c.col >= 0 && c.row < size && c.col < size && !occupied.contains(c));

    PuzzleBlock? place(PuzzleBlock Function(Cell at) make) {
      for (var i = 0; i < 40; i++) {
        final b = make(randCell());
        if (free(b.cells) && b.cells.every((c) => !targets.containsKey(c) || b.kind != BlockKind.stone)) {
          blocks.add(b);
          occupied.addAll(b.cells);
          return b;
        }
      }
      return null;
    }

    final tier = band == DifficultyBand.beginner
        ? 0
        : band == DifficultyBand.easy
        ? 1
        : band == DifficultyBand.medium
        ? 2
        : 3;

    // Group-rule variation (Ocean World onwards, some levels).
    final useGroup = mech.contains(Mechanic.group) && levelId % 4 == 0;
    if (useGroup) {
      final colorCount = tier >= 2 ? 2 : 1;
      for (var k = 0; k < colorCount; k++) {
        final color = colors[k];
        for (var i = 0; i < 3; i++) {
          if (place(
                (at) => PuzzleBlock(
                  id: nextId('c'),
                  kind: BlockKind.normal,
                  color: color,
                  row: at.row,
                  col: at.col,
                  axis: _chance(0.5) ? MoveAxis.both : (_chance(0.5) ? MoveAxis.horizontal : MoveAxis.vertical),
                ),
              ) ==
              null) {
            return null;
          }
        }
      }
      for (var i = 0; i < 1 + tier; i++) {
        place(
          (at) => PuzzleBlock(id: nextId('s'), kind: BlockKind.stone, row: at.row, col: at.col, axis: MoveAxis.both),
        );
      }
      objectives.add(const PuzzleObjective(ObjectiveType.clearAll));
      return PuzzleLevel(
        worldId: worldId,
        levelId: levelId,
        rows: size,
        columns: size,
        moveLimit: 1,
        objectives: objectives,
        blocks: blocks,
        matchRule: const MatchRule.group(3),
        difficulty: band.name,
        rewardCoins: 50,
        tip: 'Line up 3 blocks of the same colour to clear them.',
      );
    }

    // Stones first so pads never sit under them.
    final stoneCount = levelId <= 5 ? 0 : _r(2 + tier);
    for (var i = 0; i < stoneCount; i++) {
      place((at) => PuzzleBlock(id: nextId('s'), kind: BlockKind.stone, row: at.row, col: at.col, axis: MoveAxis.both));
    }

    // Coloured blocks + their pads.
    final colourCount = [1, 2, 2, 3][tier] + (levelId > 70 && _chance(0.4) ? 1 : 0);
    final useBomb = mech.contains(Mechanic.bomb) && levelId > 3 && _chance(0.6);
    for (var k = 0; k < colourCount; k++) {
      final color = colors[k];
      final long = levelId > 8 && _chance(0.25 + tier * 0.1);
      final len = long ? (_chance(0.7) ? 2 : 3) : 1;
      final horizontal = _chance(0.5);
      final axis = len > 1
          ? (horizontal ? MoveAxis.horizontal : MoveAxis.vertical)
          : (tier == 0 || _chance(tier >= 2 ? 0.15 : 0.4)
                ? MoveAxis.both
                : (horizontal ? MoveAxis.horizontal : MoveAxis.vertical));
      final isBomb = useBomb && k == 0 && len == 1;
      final b = place(
        (at) => PuzzleBlock(
          id: nextId(isBomb ? 'b' : 'c'),
          kind: isBomb ? BlockKind.bomb : BlockKind.normal,
          color: color,
          row: at.row,
          col: at.col,
          width: horizontal ? len : 1,
          height: horizontal ? 1 : len,
          axis: axis,
          radius: 1,
        ),
      );
      if (b == null) return null;
      // Pad footprint reachable along the block's axis.
      List<Cell>? pad;
      for (var i = 0; i < 40 && pad == null; i++) {
        final at = switch (axis) {
          MoveAxis.horizontal => Cell(b.row, _r(size)),
          MoveAxis.vertical => Cell(_r(size), b.col),
          MoveAxis.both => randCell(),
        };
        final cells = [for (final c in b.cells) Cell(c.row - b.row + at.row, c.col - b.col + at.col)];
        final inside = cells.every((c) => c.row < size && c.col < size);
        final overStone = blocks.any((o) => o.kind == BlockKind.stone && cells.any(o.covers));
        final onSelf = cells.every(b.covers);
        if (inside && !overStone && !onSelf && cells.every((c) => !targets.containsKey(c))) pad = cells;
      }
      if (pad == null) return null;
      for (final c in pad) {
        targets[c] = color;
      }
    }
    objectives.add(const PuzzleObjective(ObjectiveType.clearTargets));

    // Crates (uncoloured movable obstacles).
    final crates = [0, 1, 2, 3][tier] + _r(2);
    for (var i = 0; i < crates; i++) {
      final len = _chance(0.3) ? 2 : 1;
      final horizontal = _chance(0.5);
      place(
        (at) => PuzzleBlock(
          id: nextId('n'),
          kind: BlockKind.normal,
          row: at.row,
          col: at.col,
          width: horizontal ? len : 1,
          height: horizontal ? 1 : len,
          axis: len > 1
              ? (horizontal ? MoveAxis.horizontal : MoveAxis.vertical)
              : (_chance(0.5) ? MoveAxis.both : (horizontal ? MoveAxis.horizontal : MoveAxis.vertical)),
        ),
      );
    }

    String? tip;
    if (mech.contains(Mechanic.ice) && levelId > 2 && _chance(0.7)) {
      final n = 1 + (tier >= 2 ? 1 : 0);
      for (var i = 0; i < n; i++) {
        place(
          (at) => PuzzleBlock(
            id: nextId('i'),
            kind: BlockKind.ice,
            row: at.row,
            col: at.col,
            hp: tier >= 3 && _chance(0.4) ? 2 : 1,
            axis: MoveAxis.both,
          ),
        );
      }
      objectives.add(const PuzzleObjective(ObjectiveType.destroyIce));
      tip = 'Slide a block into ice to crack it.';
    }
    if (mech.contains(Mechanic.stars) && _chance(0.7)) {
      for (var i = 0; i < 1 + tier ~/ 2; i++) {
        for (var t = 0; t < 20; t++) {
          final c = randCell();
          if (!occupied.contains(c) && !targets.containsKey(c)) {
            stars.add(c);
            break;
          }
        }
      }
      objectives.add(const PuzzleObjective(ObjectiveType.collectStars));
      tip ??= 'Slide any block across a star to collect it.';
    }
    if (mech.contains(Mechanic.locks) && levelId > 2 && colourCount >= 2 && _chance(0.7)) {
      // Lock the last coloured block until one block has been cleared.
      final idx = blocks.lastIndexWhere((b) => b.isMatchable);
      final b = blocks[idx];
      blocks[idx] = PuzzleBlock(
        id: b.id,
        kind: b.kind,
        color: b.color,
        row: b.row,
        col: b.col,
        width: b.width,
        height: b.height,
        axis: b.axis,
        lockClears: 1,
        radius: b.radius,
      );
      objectives.add(const PuzzleObjective(ObjectiveType.freeLocked));
      tip ??= 'Locked blocks open after you clear another block.';
    }
    if (useBomb) tip ??= 'Bombs blast nearby blocks when they reach their pad.';
    if (mech.contains(Mechanic.exit) && _chance(0.7)) {
      final key = place(
        (at) => PuzzleBlock(id: nextId('k'), kind: BlockKind.key, row: at.row, col: at.col, axis: MoveAxis.both),
      );
      if (key == null) return null;
      final edge = _r(4);
      final p = _r(size);
      final exit = switch (edge) {
        0 => Cell(0, p),
        1 => Cell(size - 1, p),
        2 => Cell(p, 0),
        _ => Cell(p, size - 1),
      };
      if (occupied.contains(exit) && blocks.any((b) => b.kind == BlockKind.stone && b.covers(exit))) return null;
      if (key.covers(exit)) return null;
      exits.add(exit);
      objectives.add(const PuzzleObjective(ObjectiveType.reachExit, target: 1));
      tip ??= 'Guide the key block to the exit.';
    }
    if (levelId == 1) tip = 'Drag or swipe a block onto the pad of the same colour.';

    return PuzzleLevel(
      worldId: worldId,
      levelId: levelId,
      rows: size,
      columns: size,
      moveLimit: 1,
      objectives: objectives,
      blocks: blocks,
      targets: targets,
      stars: stars,
      exits: exits,
      difficulty: band.name,
      rewardCoins: 50,
      tip: tip,
    );
  }
}
