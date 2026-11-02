/// Pure-Dart models for the Adventure (sliding block) mode.
library;

enum Direction {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  const Direction(this.dr, this.dc);
  final int dr;
  final int dc;

  bool get isHorizontal => this == left || this == right;
}

enum MoveAxis { horizontal, vertical, both }

/// normal: movable block, optionally coloured (uncoloured = crate obstacle).
/// stone: static, indestructible. ice: static, destroyed by hits/explosions.
/// bomb: coloured movable block that explodes when matched.
/// key: movable hero block that must reach an exit cell.
enum BlockKind { normal, stone, ice, bomb, key }

enum ObjectiveType {
  clearColor('clear_color'),
  clearAll('clear_all'),
  clearCount('clear_count'),
  reachExit('reach_exit'),
  collectStars('collect_stars'),
  destroyIce('destroy_ice'),
  freeLocked('free_locked'),
  clearTargets('clear_targets');

  const ObjectiveType(this.key);
  final String key;
  static ObjectiveType fromKey(String key) =>
      values.firstWhere((e) => e.key == key, orElse: () => throw FormatException('Unknown objective: $key'));
}

enum MatchRuleType { target, group }

enum PuzzleStatus { playing, won, lost }

class Cell {
  const Cell(this.row, this.col);
  final int row;
  final int col;

  Cell move(Direction d, [int n = 1]) => Cell(row + d.dr * n, col + d.dc * n);

  @override
  bool operator ==(Object other) => other is Cell && other.row == row && other.col == col;
  @override
  int get hashCode => row * 1000 + col;
  @override
  String toString() => '($row,$col)';

  List<int> toJson() => [row, col];
  static Cell fromJson(dynamic j) => Cell((j as List)[0] as int, j[1] as int);
}

class PuzzleBlock {
  const PuzzleBlock({
    required this.id,
    required this.kind,
    required this.row,
    required this.col,
    this.color,
    this.width = 1,
    this.height = 1,
    this.axis = MoveAxis.both,
    this.lockClears = 0,
    this.hp = 1,
    this.radius = 1,
  });

  final String id;
  final BlockKind kind;
  final String? color;
  final int row;
  final int col;
  final int width;
  final int height;
  final MoveAxis axis;

  /// Block stays locked until this many blocks have been cleared (0 = free).
  final int lockClears;

  /// Remaining hits for ice blocks.
  final int hp;

  /// Explosion radius for bombs (Chebyshev distance).
  final int radius;

  bool get isMovableKind => kind == BlockKind.normal || kind == BlockKind.bomb || kind == BlockKind.key;
  bool get isMatchable => color != null && (kind == BlockKind.normal || kind == BlockKind.bomb);
  bool get isDestructible => kind != BlockKind.stone && kind != BlockKind.key;
  bool get isLong => width > 1 || height > 1;
  bool isLocked(int totalCleared) => lockClears > totalCleared;

  bool allows(Direction d) => switch (axis) {
    MoveAxis.both => true,
    MoveAxis.horizontal => d.isHorizontal,
    MoveAxis.vertical => !d.isHorizontal,
  };

  Iterable<Cell> get cells sync* {
    for (var r = 0; r < height; r++) {
      for (var c = 0; c < width; c++) {
        yield Cell(row + r, col + c);
      }
    }
  }

  bool covers(Cell cell) => cell.row >= row && cell.row < row + height && cell.col >= col && cell.col < col + width;

  PuzzleBlock copyWith({int? row, int? col, int? hp}) => PuzzleBlock(
    id: id,
    kind: kind,
    color: color,
    row: row ?? this.row,
    col: col ?? this.col,
    width: width,
    height: height,
    axis: axis,
    lockClears: lockClears,
    hp: hp ?? this.hp,
    radius: radius,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    if (color != null) 'color': color,
    'row': row,
    'col': col,
    if (width != 1) 'width': width,
    if (height != 1) 'height': height,
    'axis': axis.name,
    if (lockClears != 0) 'lockClears': lockClears,
    if (kind == BlockKind.ice) 'hp': hp,
    if (kind == BlockKind.bomb) 'radius': radius,
  };

  factory PuzzleBlock.fromJson(Map<String, dynamic> j) => PuzzleBlock(
    id: j['id'] as String,
    kind: BlockKind.values.byName(j['kind'] as String),
    color: j['color'] as String?,
    row: j['row'] as int,
    col: j['col'] as int,
    width: (j['width'] as int?) ?? 1,
    height: (j['height'] as int?) ?? 1,
    axis: MoveAxis.values.byName((j['axis'] as String?) ?? 'both'),
    lockClears: (j['lockClears'] as int?) ?? 0,
    hp: (j['hp'] as int?) ?? 1,
    radius: (j['radius'] as int?) ?? 1,
  );
}

class PuzzleObjective {
  const PuzzleObjective(this.type, {this.color, this.target = 0});
  final ObjectiveType type;
  final String? color;
  final int target;

  Map<String, dynamic> toJson() => {
    'type': type.key,
    if (color != null) 'color': color,
    if (target != 0) 'target': target,
  };
  factory PuzzleObjective.fromJson(Map<String, dynamic> j) => PuzzleObjective(
    ObjectiveType.fromKey(j['type'] as String),
    color: j['color'] as String?,
    target: (j['target'] as int?) ?? 0,
  );
}

class MatchRule {
  const MatchRule.target() : type = MatchRuleType.target, minGroup = 0;
  const MatchRule.group(this.minGroup) : type = MatchRuleType.group;
  final MatchRuleType type;
  final int minGroup;

  Map<String, dynamic> toJson() => {'type': type.name, if (type == MatchRuleType.group) 'minGroup': minGroup};
  factory MatchRule.fromJson(Map<String, dynamic>? j) {
    if (j == null || j['type'] == 'target') return const MatchRule.target();
    return MatchRule.group((j['minGroup'] as int?) ?? 3);
  }
}

class PuzzleLevel {
  const PuzzleLevel({
    required this.worldId,
    required this.levelId,
    required this.rows,
    required this.columns,
    required this.moveLimit,
    required this.objectives,
    required this.blocks,
    this.targets = const {},
    this.stars = const {},
    this.exits = const {},
    this.matchRule = const MatchRule.target(),
    this.chainReactions = false,
    this.twoStarMoves,
    this.threeStarMoves,
    this.difficulty = 'beginner',
    this.rewardCoins = 50,
    this.tip,
  });

  final int worldId;
  final int levelId;
  final int rows;
  final int columns;
  final int moveLimit;
  final List<PuzzleObjective> objectives;
  final List<PuzzleBlock> blocks;

  /// Target pads: cell -> colour.
  final Map<Cell, String> targets;
  final Set<Cell> stars;
  final Set<Cell> exits;
  final MatchRule matchRule;

  /// Bombs destroyed by an explosion also explode.
  final bool chainReactions;
  final int? twoStarMoves;
  final int? threeStarMoves;
  final String difficulty;
  final int rewardCoins;

  /// Optional one-line instruction shown at level start.
  final String? tip;

  String get key => '$worldId-$levelId';

  /// Stars earned for finishing with [movesUsed] moves.
  int starsFor(int movesUsed) {
    if (threeStarMoves != null && movesUsed <= threeStarMoves!) return 3;
    if (twoStarMoves != null && movesUsed <= twoStarMoves!) return 2;
    return 1;
  }

  Map<String, dynamic> toJson() => {
    'levelId': levelId,
    'worldId': worldId,
    'rows': rows,
    'columns': columns,
    'moveLimit': moveLimit,
    if (twoStarMoves != null) 'twoStarMoves': twoStarMoves,
    if (threeStarMoves != null) 'threeStarMoves': threeStarMoves,
    'difficulty': difficulty,
    'matchRule': matchRule.toJson(),
    if (chainReactions) 'chainReactions': true,
    if (tip != null) 'tip': tip,
    'objectives': [for (final o in objectives) o.toJson()],
    'blocks': [for (final b in blocks) b.toJson()],
    'targets': [
      for (final e in targets.entries) {'cell': e.key.toJson(), 'color': e.value},
    ],
    if (stars.isNotEmpty) 'stars': [for (final s in stars) s.toJson()],
    if (exits.isNotEmpty) 'exits': [for (final s in exits) s.toJson()],
    'rewards': {'coins': rewardCoins},
  };

  factory PuzzleLevel.fromJson(Map<String, dynamic> j) {
    final rewards = (j['rewards'] as Map<String, dynamic>?) ?? const {};
    return PuzzleLevel(
      worldId: j['worldId'] as int,
      levelId: j['levelId'] as int,
      rows: j['rows'] as int,
      columns: j['columns'] as int,
      moveLimit: j['moveLimit'] as int,
      twoStarMoves: j['twoStarMoves'] as int?,
      threeStarMoves: j['threeStarMoves'] as int?,
      difficulty: (j['difficulty'] as String?) ?? 'beginner',
      matchRule: MatchRule.fromJson(j['matchRule'] as Map<String, dynamic>?),
      chainReactions: (j['chainReactions'] as bool?) ?? false,
      tip: j['tip'] as String?,
      objectives: [for (final o in j['objectives'] as List) PuzzleObjective.fromJson(o as Map<String, dynamic>)],
      blocks: [for (final b in j['blocks'] as List) PuzzleBlock.fromJson(b as Map<String, dynamic>)],
      targets: {
        for (final t in (j['targets'] as List?) ?? const []) Cell.fromJson((t as Map)['cell']): t['color'] as String,
      },
      stars: {for (final s in (j['stars'] as List?) ?? const []) Cell.fromJson(s)},
      exits: {for (final s in (j['exits'] as List?) ?? const []) Cell.fromJson(s)},
      rewardCoins: (rewards['coins'] as int?) ?? 50,
    );
  }
}

/// A single player move.
class PuzzleMove {
  const PuzzleMove(this.blockId, this.direction, this.distance);
  final String blockId;
  final Direction direction;
  final int distance;

  @override
  String toString() => '$blockId ${direction.name} $distance';
}

/// Immutable puzzle state. Everything needed for undo lives here.
class PuzzleState {
  const PuzzleState({
    required this.blocks,
    required this.targets,
    required this.stars,
    this.movesUsed = 0,
    this.clearedByColor = const {},
    this.totalCleared = 0,
    this.iceDestroyed = 0,
    this.exitsReached = 0,
    this.combo = 0,
    this.maxCombo = 0,
    this.status = PuzzleStatus.playing,
  });

  final List<PuzzleBlock> blocks;
  final Map<Cell, String> targets;
  final Set<Cell> stars;
  final int movesUsed;
  final Map<String, int> clearedByColor;
  final int totalCleared;
  final int iceDestroyed;
  final int exitsReached;
  final int combo;
  final int maxCombo;
  final PuzzleStatus status;

  PuzzleBlock? blockById(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  PuzzleBlock? blockAt(Cell cell) {
    for (final b in blocks) {
      if (b.covers(cell)) return b;
    }
    return null;
  }

  PuzzleState copyWith({
    List<PuzzleBlock>? blocks,
    Map<Cell, String>? targets,
    Set<Cell>? stars,
    int? movesUsed,
    Map<String, int>? clearedByColor,
    int? totalCleared,
    int? iceDestroyed,
    int? exitsReached,
    int? combo,
    int? maxCombo,
    PuzzleStatus? status,
  }) => PuzzleState(
    blocks: blocks ?? this.blocks,
    targets: targets ?? this.targets,
    stars: stars ?? this.stars,
    movesUsed: movesUsed ?? this.movesUsed,
    clearedByColor: clearedByColor ?? this.clearedByColor,
    totalCleared: totalCleared ?? this.totalCleared,
    iceDestroyed: iceDestroyed ?? this.iceDestroyed,
    exitsReached: exitsReached ?? this.exitsReached,
    combo: combo ?? this.combo,
    maxCombo: maxCombo ?? this.maxCombo,
    status: status ?? this.status,
  );

  /// Canonical key used by the solver for de-duplication.
  String get solverKey {
    final ids = [for (final b in blocks) '${b.id}${b.row}.${b.col}.${b.hp}']..sort();
    final t = [for (final c in targets.keys) c.hashCode]..sort();
    final s = [for (final c in stars) c.hashCode]..sort();
    final cc = [for (final e in clearedByColor.entries) '${e.key}${e.value}']..sort();
    return '${ids.join(',')}|${t.join(',')}|${s.join(',')}|${cc.join(',')}|$totalCleared|$exitsReached|$iceDestroyed';
  }
}

class ObjectiveProgress {
  const ObjectiveProgress(this.objective, this.current, this.target);
  final PuzzleObjective objective;
  final int current;
  final int target;
  bool get done => current >= target;
}

/// Result of a move, with events for the UI to animate.
class MoveOutcome {
  const MoveOutcome({
    required this.state,
    required this.move,
    this.cleared = const [],
    this.explosions = const [],
    this.iceHits = const [],
    this.starsCollected = const [],
    this.exited,
  });

  final PuzzleState state;
  final PuzzleMove move;

  /// Blocks removed this move (matched, exploded, melted).
  final List<PuzzleBlock> cleared;

  /// Centre cells of explosions.
  final List<Cell> explosions;
  final List<String> iceHits;
  final List<Cell> starsCollected;
  final PuzzleBlock? exited;

  bool get clearedAnything => cleared.isNotEmpty || exited != null;
}
