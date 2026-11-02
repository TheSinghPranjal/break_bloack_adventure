import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/feedback_service.dart';
import '../../../core/services/player_store.dart';
import '../../rewards/engine/reward_engine.dart';
import '../../rewards/reward_service.dart';
import '../../shop/booster_catalog.dart';
import '../../wallet/wallet_ledger.dart';
import '../engine/sliding_puzzle_engine.dart';
import '../models/puzzle_models.dart';

class AdventureSession {
  const AdventureSession({
    required this.level,
    required this.state,
    required this.attemptId,
    this.history = const [],
    this.undosUsed = 0,
    this.hintsUsed = 0,
    this.hint,
    this.hintLoading = false,
    this.lastOutcome,
    this.tick = 0,
    this.result,
    this.stars = 0,
  });

  final PuzzleLevel level;
  final PuzzleState state;
  final String attemptId;
  final List<PuzzleState> history;
  final int undosUsed;
  final int hintsUsed;
  final PuzzleMove? hint;
  final bool hintLoading;
  final MoveOutcome? lastOutcome;
  final int tick;
  final EconomyResult? result;
  final int stars;

  static const freeUndos = 3;
  static const freeHints = 1;

  int get freeUndosLeft => (freeUndos - undosUsed).clamp(0, freeUndos);
  int get freeHintsLeft => (freeHints - hintsUsed).clamp(0, freeHints);
  int get movesLeft => level.moveLimit - state.movesUsed;

  AdventureSession copyWith({
    PuzzleState? state,
    List<PuzzleState>? history,
    int? undosUsed,
    int? hintsUsed,
    PuzzleMove? hint,
    bool clearHint = false,
    bool? hintLoading,
    MoveOutcome? lastOutcome,
    bool clearOutcome = false,
    int? tick,
    EconomyResult? result,
    int? stars,
  }) => AdventureSession(
    level: level,
    state: state ?? this.state,
    attemptId: attemptId,
    history: history ?? this.history,
    undosUsed: undosUsed ?? this.undosUsed,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    hint: clearHint ? null : (hint ?? this.hint),
    hintLoading: hintLoading ?? this.hintLoading,
    lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
    tick: tick ?? this.tick,
    result: result ?? this.result,
    stars: stars ?? this.stars,
  );
}

enum AssistResult { ok, needsPayment, notEnoughCoins, nothingToDo, noSolution }

class AdventureController extends Notifier<AdventureSession?> {
  final engine = const SlidingPuzzleEngine();

  @override
  AdventureSession? build() => null;

  FeedbackService get _fx => ref.read(feedbackProvider);

  void start(PuzzleLevel level) {
    state = AdventureSession(level: level, state: engine.initializeLevel(level), attemptId: newTxId('att'));
  }

  void restart() {
    final s = state;
    if (s != null) start(s.level);
  }

  int maxDistance(String blockId, Direction d) {
    final s = state;
    if (s == null) return 0;
    return engine.maxDistance(s.level, s.state, blockId, d);
  }

  /// Returns true if the move was accepted.
  bool move(PuzzleMove m) {
    final s = state;
    if (s == null || s.state.status != PuzzleStatus.playing) return false;
    final out = engine.moveBlock(s.level, s.state, m);
    if (out == null) {
      _fx.play(Sfx.invalid);
      return false;
    }
    var next = s.copyWith(
      state: out.state,
      history: [...s.history, s.state],
      lastOutcome: out,
      tick: s.tick + 1,
      clearHint: true,
    );
    _fx.play(out.clearedAnything ? Sfx.clear : Sfx.place);
    if (out.state.status == PuzzleStatus.won) {
      final stars = s.level.starsFor(out.state.movesUsed);
      final res = ref
          .read(rewardServiceProvider)
          .completeAdventureLevel(
            AdventureCompletion(
              worldId: s.level.worldId,
              levelId: s.level.levelId,
              stars: stars,
              attemptId: s.attemptId,
              baseCoins: s.level.rewardCoins,
            ),
          );
      next = next.copyWith(result: res, stars: stars);
      _fx.play(Sfx.win);
    }
    state = next;
    return true;
  }

  /// Whether the next undo is free; if not, the UI must confirm payment.
  bool get nextUndoFree => (state?.freeUndosLeft ?? 0) > 0;
  bool get nextHintFree => (state?.freeHintsLeft ?? 0) > 0;

  AssistResult undo({bool paid = false}) {
    final s = state;
    if (s == null || s.history.isEmpty || s.state.status == PuzzleStatus.won) return AssistResult.nothingToDo;
    if (s.freeUndosLeft == 0) {
      if (!paid) return AssistResult.needsPayment;
      final c = ref.read(rewardServiceProvider).chargeBooster(Boosters.advUndo, useId: newTxId('adv_undo'));
      if (!c.ok) return c.status == TxStatus.insufficientFunds ? AssistResult.notEnoughCoins : AssistResult.nothingToDo;
    }
    final u = engine.undoMove(s.history)!;
    state = s.copyWith(
      state: u.state,
      history: u.history,
      undosUsed: s.undosUsed + 1,
      clearOutcome: true,
      clearHint: true,
      tick: s.tick + 1,
    );
    _fx.play(Sfx.tap);
    return AssistResult.ok;
  }

  /// Computes a hint off the UI thread. Free hint first, then paid.
  Future<AssistResult> hint({bool paid = false}) async {
    final s = state;
    if (s == null || s.state.status != PuzzleStatus.playing || s.hintLoading) return AssistResult.nothingToDo;
    if (s.freeHintsLeft == 0 && !paid) return AssistResult.needsPayment;
    state = s.copyWith(hintLoading: true);
    final level = s.level, ps = s.state;
    final move = await Isolate.run(() => const SlidingPuzzleEngine().getHint(level, ps));
    final cur = state;
    if (cur == null || !identical(cur.state, ps)) return AssistResult.nothingToDo; // board changed meanwhile
    if (move == null) {
      state = cur.copyWith(hintLoading: false);
      return AssistResult.noSolution; // nothing charged
    }
    if (cur.freeHintsLeft == 0) {
      final c = ref.read(rewardServiceProvider).chargeBooster(Boosters.advHint, useId: newTxId('adv_hint'));
      if (!c.ok) {
        state = cur.copyWith(hintLoading: false);
        return c.status == TxStatus.insufficientFunds ? AssistResult.notEnoughCoins : AssistResult.nothingToDo;
      }
    }
    state = cur.copyWith(hint: move, hintsUsed: cur.hintsUsed + 1, hintLoading: false);
    return AssistResult.ok;
  }
}

final adventureControllerProvider = NotifierProvider<AdventureController, AdventureSession?>(AdventureController.new);
