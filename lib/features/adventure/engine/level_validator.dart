import '../models/puzzle_models.dart';
import 'sliding_puzzle_engine.dart';

class LevelValidationResult {
  const LevelValidationResult(this.level, this.errors, this.solution);
  final PuzzleLevel level;
  final List<String> errors;

  /// Shortest solution found (null when unsolvable / not searched).
  final List<PuzzleMove>? solution;
  bool get isValid => errors.isEmpty;

  @override
  String toString() => 'Level ${level.key}: ${isValid ? 'OK (${solution?.length} moves)' : errors.join('; ')}';
}

/// Ensures levels are well-formed and provably solvable within their limit.
class LevelValidator {
  const LevelValidator({this.engine = const SlidingPuzzleEngine(), this.nodeLimit = 400000});
  final SlidingPuzzleEngine engine;
  final int nodeLimit;

  LevelValidationResult validate(PuzzleLevel level, {bool checkSolvable = true}) {
    final errors = <String>[];
    bool inBounds(Cell c) => c.row >= 0 && c.col >= 0 && c.row < level.rows && c.col < level.columns;

    if (level.rows < 4 || level.columns < 4 || level.rows > 10 || level.columns > 10) {
      errors.add('board size ${level.rows}x${level.columns} out of range');
    }
    if (level.moveLimit < 1) errors.add('moveLimit must be positive');
    if (level.objectives.isEmpty) errors.add('no objectives');

    final ids = <String>{};
    final occupied = <Cell, String>{};
    for (final b in level.blocks) {
      if (!ids.add(b.id)) errors.add('duplicate block id ${b.id}');
      if (b.isLong && b.width > 1 && b.height > 1) {
        errors.add('block ${b.id} must be a straight line');
      }
      if (b.width > 3 || b.height > 3) errors.add('block ${b.id} longer than 3');
      if (b.kind == BlockKind.bomb && b.color == null) {
        errors.add('bomb ${b.id} needs a colour');
      }
      for (final c in b.cells) {
        if (!inBounds(c)) errors.add('block ${b.id} out of bounds at $c');
        final prev = occupied[c];
        if (prev != null) errors.add('blocks $prev and ${b.id} overlap at $c');
        occupied[c] = b.id;
      }
    }
    for (final e in level.targets.entries) {
      if (!inBounds(e.key)) errors.add('target out of bounds at ${e.key}');
      final b = occupied[e.key];
      if (b != null) {
        final block = level.blocks.firstWhere((x) => x.id == b);
        if (block.kind == BlockKind.stone) errors.add('target under stone at ${e.key}');
      }
    }
    for (final s in level.stars) {
      if (!inBounds(s)) errors.add('star out of bounds at $s');
    }
    for (final s in level.exits) {
      if (!inBounds(s)) errors.add('exit out of bounds at $s');
    }
    // A block must not start already matched.
    if (level.matchRule.type == MatchRuleType.target) {
      for (final b in level.blocks.where((b) => b.isMatchable)) {
        if (b.cells.every((c) => level.targets[c] == b.color)) {
          errors.add('block ${b.id} starts on its own target');
        }
      }
    }
    final t2 = level.twoStarMoves, t3 = level.threeStarMoves;
    if (t2 != null && t3 != null && t3 > t2) errors.add('threeStarMoves > twoStarMoves');
    if (t2 != null && t2 > level.moveLimit) errors.add('twoStarMoves > moveLimit');

    List<PuzzleMove>? solution;
    if (errors.isEmpty && checkSolvable) {
      final start = engine.initializeLevel(level);
      if (engine.checkWin(level, start)) {
        errors.add('level is already solved at start');
      } else {
        solution = engine.solve(level, start, nodeLimit: nodeLimit);
        if (solution == null) {
          errors.add('no solution within ${level.moveLimit} moves');
        } else if (t3 != null && solution.length > t3) {
          errors.add('3-star threshold $t3 below optimal ${solution.length}');
        }
      }
    }
    return LevelValidationResult(level, errors, solution);
  }
}
