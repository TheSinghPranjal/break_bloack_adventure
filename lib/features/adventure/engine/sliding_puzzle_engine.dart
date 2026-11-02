import 'dart:collection';
import 'dart:math';

import '../models/puzzle_models.dart';

/// Deterministic rules engine for Adventure mode. Pure Dart, no UI.
///
/// Rules summary:
/// * Movable blocks slide along their axis; they cannot pass through other
///   blocks or stones, or leave the board. Each accepted move costs one move.
/// * Any block sliding over a star cell collects it.
/// * A block that stops directly against an ice block hits it (hp - 1).
/// * Target rule: a coloured block whose every cell rests on pads of its
///   colour is cleared and consumes those pads.
/// * Group rule: when the moved block forms an orthogonally connected group
///   of at least `minGroup` cells of one colour, the whole group clears.
/// * A cleared bomb explodes, destroying destructible blocks within radius.
///   Bombs caught in a blast only explode if the level enables chains.
/// * Key blocks that stop on an exit cell leave the board.
/// * Locked blocks cannot move or match until enough blocks are cleared.
class SlidingPuzzleEngine {
  const SlidingPuzzleEngine();

  PuzzleState initializeLevel(PuzzleLevel level) => PuzzleState(
    blocks: List.unmodifiable(level.blocks),
    targets: Map.unmodifiable(level.targets),
    stars: Set.unmodifiable(level.stars),
  );

  // --------------------------------------------------------------- movement

  bool _inBounds(PuzzleLevel level, Cell c) => c.row >= 0 && c.col >= 0 && c.row < level.rows && c.col < level.columns;

  bool canMoveBlock(PuzzleState state, PuzzleBlock b) => b.isMovableKind && !b.isLocked(state.totalCleared);

  /// Maximum number of cells [blockId] can travel in [dir] (0 = blocked).
  int maxDistance(PuzzleLevel level, PuzzleState state, String blockId, Direction dir) {
    final b = state.blockById(blockId);
    if (b == null || !canMoveBlock(state, b) || !b.allows(dir)) return 0;
    final occupied = <Cell>{
      for (final o in state.blocks)
        if (o.id != b.id) ...o.cells,
    };
    var n = 0;
    while (true) {
      final next = [for (final c in b.cells) c.move(dir, n + 1)];
      if (next.any((c) => !_inBounds(level, c) || occupied.contains(c))) break;
      n++;
    }
    return n;
  }

  bool validateMove(PuzzleLevel level, PuzzleState state, PuzzleMove move) {
    if (state.status != PuzzleStatus.playing) return false;
    if (move.distance < 1) return false;
    return move.distance <= maxDistance(level, state, move.blockId, move.direction);
  }

  /// All valid moves (every block, direction and distance).
  List<PuzzleMove> legalMoves(PuzzleLevel level, PuzzleState state) {
    final moves = <PuzzleMove>[];
    for (final b in state.blocks) {
      if (!canMoveBlock(state, b)) continue;
      for (final d in Direction.values) {
        final m = maxDistance(level, state, b.id, d);
        for (var i = 1; i <= m; i++) {
          moves.add(PuzzleMove(b.id, d, i));
        }
      }
    }
    return moves;
  }

  /// Applies [move]. Returns null when the move is invalid.
  ///
  /// [detectStuck] also marks the game lost when no legal move remains; the
  /// solver turns it off because it explores successors anyway.
  MoveOutcome? moveBlock(PuzzleLevel level, PuzzleState state, PuzzleMove move, {bool detectStuck = true}) {
    if (!validateMove(level, state, move)) return null;
    final original = state.blockById(move.blockId)!;
    final moved = original.copyWith(
      row: original.row + move.direction.dr * move.distance,
      col: original.col + move.direction.dc * move.distance,
    );

    var blocks = [for (final b in state.blocks) b.id == moved.id ? moved : b];

    // Stars along the path (including the final resting cells).
    final collected = <Cell>[];
    for (var step = 1; step <= move.distance; step++) {
      for (final c in original.cells) {
        final p = c.move(move.direction, step);
        if (state.stars.contains(p) && !collected.contains(p)) collected.add(p);
      }
    }
    var next = state.copyWith(
      blocks: blocks,
      stars: collected.isEmpty ? state.stars : (Set.of(state.stars)..removeAll(collected)),
    );

    // Key block reaching an exit.
    PuzzleBlock? exited;
    if (moved.kind == BlockKind.key && moved.cells.any(level.exits.contains)) {
      exited = moved;
      blocks = [
        for (final b in next.blocks)
          if (b.id != moved.id) b,
      ];
      next = next.copyWith(blocks: blocks, exitsReached: next.exitsReached + 1);
    }

    // Ice hit: stopping directly against an ice block.
    final cleared = <PuzzleBlock>[];
    final iceHits = <String>[];
    if (exited == null) {
      final front = {for (final c in moved.cells) c.move(move.direction)}..removeAll(moved.cells);
      final hitIds = <String>{};
      for (final c in front) {
        final o = next.blockAt(c);
        if (o != null && o.kind == BlockKind.ice) hitIds.add(o.id);
      }
      for (final id in hitIds) {
        final ice = next.blockById(id)!;
        iceHits.add(id);
        if (ice.hp <= 1) {
          cleared.add(ice);
          next = next.copyWith(
            blocks: [
              for (final b in next.blocks)
                if (b.id != id) b,
            ],
            iceDestroyed: next.iceDestroyed + 1,
            totalCleared: next.totalCleared + 1,
          );
        } else {
          next = next.copyWith(blocks: [for (final b in next.blocks) b.id == id ? b.copyWith(hp: b.hp - 1) : b]);
        }
      }
    }

    // Matching.
    final explosions = <Cell>[];
    if (exited == null) {
      final matched = detectMatch(level, next, moved.id);
      if (matched.isNotEmpty) {
        final r = resolveMatch(level, next, matched);
        next = r.state;
        cleared.addAll(r.cleared);
        explosions.addAll(r.explosions);
      }
    }

    final clearedAny = cleared.isNotEmpty || exited != null;
    final combo = clearedAny ? next.combo + 1 : 0;
    next = next.copyWith(movesUsed: state.movesUsed + 1, combo: combo, maxCombo: max(next.maxCombo, combo));
    next = next.copyWith(status: _status(level, next, detectStuck));

    return MoveOutcome(
      state: next,
      move: move,
      cleared: cleared,
      explosions: explosions,
      iceHits: iceHits,
      starsCollected: collected,
      exited: exited,
    );
  }

  // --------------------------------------------------------------- matching

  /// Returns ids of blocks that match as a result of [movedId] moving.
  List<String> detectMatch(PuzzleLevel level, PuzzleState state, String movedId) {
    final b = state.blockById(movedId);
    if (b == null || !b.isMatchable || b.isLocked(state.totalCleared)) return const [];
    switch (level.matchRule.type) {
      case MatchRuleType.target:
        final ok = b.cells.every((c) => state.targets[c] == b.color);
        return ok ? [b.id] : const [];
      case MatchRuleType.group:
        final group = <String>{b.id};
        final queue = Queue<PuzzleBlock>()..add(b);
        var cellCount = 0;
        while (queue.isNotEmpty) {
          final cur = queue.removeFirst();
          cellCount += cur.width * cur.height;
          for (final c in cur.cells) {
            for (final d in Direction.values) {
              final o = state.blockAt(c.move(d));
              if (o != null &&
                  !group.contains(o.id) &&
                  o.isMatchable &&
                  !o.isLocked(state.totalCleared) &&
                  o.color == b.color) {
                group.add(o.id);
                queue.add(o);
              }
            }
          }
        }
        return cellCount >= level.matchRule.minGroup ? group.toList() : const [];
    }
  }

  /// Removes matched blocks, consumes pads, and triggers bomb explosions.
  ({PuzzleState state, List<PuzzleBlock> cleared, List<Cell> explosions}) resolveMatch(
    PuzzleLevel level,
    PuzzleState state,
    List<String> matchedIds,
  ) {
    var next = state;
    final cleared = <PuzzleBlock>[];
    final bombs = Queue<PuzzleBlock>();
    final targets = Map.of(state.targets);
    for (final id in matchedIds) {
      final b = next.blockById(id);
      if (b == null) continue;
      if (level.matchRule.type == MatchRuleType.target) {
        for (final c in b.cells) {
          targets.remove(c);
        }
      }
      next = _remove(next, b);
      cleared.add(b);
      if (b.kind == BlockKind.bomb) bombs.add(b);
    }
    next = next.copyWith(targets: targets);

    final explosions = <Cell>[];
    while (bombs.isNotEmpty) {
      final bomb = bombs.removeFirst();
      final r = applyExplosion(level, next, bomb);
      next = r.state;
      explosions.add(bomb.cells.first);
      cleared.addAll(r.destroyed);
      if (level.chainReactions) {
        bombs.addAll(r.destroyed.where((d) => d.kind == BlockKind.bomb));
      }
    }
    return (state: next, cleared: cleared, explosions: explosions);
  }

  PuzzleState _remove(PuzzleState s, PuzzleBlock b) {
    final byColor = Map.of(s.clearedByColor);
    if (b.color != null && b.kind != BlockKind.ice) {
      byColor[b.color!] = (byColor[b.color!] ?? 0) + 1;
    }
    return s.copyWith(
      blocks: [
        for (final o in s.blocks)
          if (o.id != b.id) o,
      ],
      clearedByColor: byColor,
      totalCleared: s.totalCleared + 1,
      iceDestroyed: s.iceDestroyed + (b.kind == BlockKind.ice ? 1 : 0),
    );
  }

  /// Destroys destructible blocks within the bomb's radius.
  ({PuzzleState state, List<PuzzleBlock> destroyed}) applyExplosion(
    PuzzleLevel level,
    PuzzleState state,
    PuzzleBlock bomb,
  ) {
    bool inBlast(PuzzleBlock o) =>
        o.cells.any((c) => bomb.cells.any((bc) => max((bc.row - c.row).abs(), (bc.col - c.col).abs()) <= bomb.radius));
    final hit = [
      for (final o in state.blocks)
        if (o.id != bomb.id && o.isDestructible && inBlast(o)) o,
    ];
    var next = state;
    for (final o in hit) {
      next = _remove(next, o);
    }
    return (state: next, destroyed: hit);
  }

  // ------------------------------------------------------------- objectives

  List<ObjectiveProgress> checkObjectives(PuzzleLevel level, PuzzleState state) {
    final initialColored = level.blocks.where((b) => b.isMatchable).length;
    final initialIce = level.blocks.where((b) => b.kind == BlockKind.ice).length;
    final initialLocked = level.blocks.where((b) => b.lockClears > 0).length;
    return [
      for (final o in level.objectives)
        switch (o.type) {
          ObjectiveType.clearColor => ObjectiveProgress(o, state.clearedByColor[o.color] ?? 0, o.target),
          ObjectiveType.clearAll => ObjectiveProgress(
            o,
            initialColored - state.blocks.where((b) => b.isMatchable).length,
            initialColored,
          ),
          ObjectiveType.clearCount => ObjectiveProgress(o, state.totalCleared, o.target),
          ObjectiveType.reachExit => ObjectiveProgress(o, state.exitsReached, o.target == 0 ? 1 : o.target),
          ObjectiveType.collectStars => ObjectiveProgress(
            o,
            level.stars.length - state.stars.length,
            level.stars.length,
          ),
          ObjectiveType.destroyIce => ObjectiveProgress(o, state.iceDestroyed, initialIce),
          ObjectiveType.freeLocked => ObjectiveProgress(
            o,
            initialLocked - state.blocks.where((b) => b.isLocked(state.totalCleared)).length,
            initialLocked,
          ),
          ObjectiveType.clearTargets => ObjectiveProgress(
            o,
            level.targets.length - state.targets.length,
            level.targets.length,
          ),
        },
    ];
  }

  bool checkWin(PuzzleLevel level, PuzzleState state) => checkObjectives(level, state).every((p) => p.done);

  /// Lost when out of moves, or when no legal move remains.
  bool checkLoss(PuzzleLevel level, PuzzleState state) {
    if (checkWin(level, state)) return false;
    if (state.movesUsed >= level.moveLimit) return true;
    return legalMoves(level, state).isEmpty;
  }

  PuzzleStatus _status(PuzzleLevel level, PuzzleState s, bool detectStuck) {
    if (checkWin(level, s)) return PuzzleStatus.won;
    if (s.movesUsed >= level.moveLimit) return PuzzleStatus.lost;
    if (detectStuck && legalMoves(level, s).isEmpty) return PuzzleStatus.lost;
    return PuzzleStatus.playing;
  }

  // ------------------------------------------------------------------- undo

  /// Pops the most recent state from [history]. Returns null if empty.
  ({PuzzleState state, List<PuzzleState> history})? undoMove(List<PuzzleState> history) {
    if (history.isEmpty) return null;
    final h = List.of(history);
    final prev = h.removeLast();
    return (state: prev, history: h);
  }

  // ------------------------------------------------------------ solver/hint

  /// Breadth-first search for the shortest winning sequence within the
  /// remaining moves. Returns null if none is found within [nodeLimit].
  List<PuzzleMove>? solve(PuzzleLevel level, PuzzleState start, {int? maxDepth, int nodeLimit = 250000}) {
    if (checkWin(level, start)) return const [];
    final depthLimit = maxDepth ?? (level.moveLimit - start.movesUsed);
    final seen = <String>{start.solverKey};
    final queue = Queue<(PuzzleState, List<PuzzleMove>)>()..add((start, const []));
    var expanded = 0;
    while (queue.isNotEmpty) {
      final (s, path) = queue.removeFirst();
      if (path.length >= depthLimit) continue;
      if (++expanded > nodeLimit) return null;
      for (final m in legalMoves(level, s)) {
        final out = moveBlock(level, s, m, detectStuck: false);
        if (out == null) continue;
        final p = [...path, m];
        if (out.state.status == PuzzleStatus.won) return p;
        if (out.state.status == PuzzleStatus.lost) continue;
        if (seen.add(out.state.solverKey)) queue.add((out.state, p));
      }
    }
    return null;
  }

  /// Recommends (but never performs) the next move of an optimal solution.
  PuzzleMove? getHint(PuzzleLevel level, PuzzleState state, {int nodeLimit = 150000}) {
    if (state.status != PuzzleStatus.playing) return null;
    final path = solve(level, state, nodeLimit: nodeLimit);
    if (path == null || path.isEmpty) return null;
    return path.first;
  }
}
