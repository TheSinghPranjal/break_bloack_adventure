import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/feedback_service.dart';
import '../../../core/services/player_store.dart';
import '../../rewards/engine/reward_engine.dart';
import '../../rewards/reward_service.dart';
import '../../shop/booster_catalog.dart';
import '../../wallet/wallet_ledger.dart';
import '../engine/block_placement_engine.dart';
import '../models/block_shape.dart';
import '../models/classic_state.dart';

/// Boosters that need the player to pick cells on the board.
enum CellTool { hammer, remove, rainbow }

class ClassicSession {
  const ClassicSession({
    required this.game,
    required this.sessionId,
    required this.boardSize,
    this.lastPlacement,
    this.clearedColors = const {},
    this.fxTick = 0,
    this.tool,
    this.selection = const [],
    this.result,
    this.paused = false,
  });

  final ClassicGameState game;
  final String sessionId;
  final int boardSize;
  final PlacementResult? lastPlacement;

  /// Colours of the cells cleared by the last placement (for animation).
  final Map<GridPoint, int> clearedColors;

  /// Increments whenever a clear animation should play.
  final int fxTick;
  final CellTool? tool;
  final List<GridPoint> selection;

  /// Set once the game has been finalized and rewarded.
  final EconomyResult? result;
  final bool paused;

  bool get finished => result != null;

  ClassicSession copyWith({
    ClassicGameState? game,
    PlacementResult? lastPlacement,
    Map<GridPoint, int>? clearedColors,
    int? fxTick,
    CellTool? tool,
    bool clearTool = false,
    List<GridPoint>? selection,
    EconomyResult? result,
    bool? paused,
  }) => ClassicSession(
    game: game ?? this.game,
    sessionId: sessionId,
    boardSize: boardSize,
    lastPlacement: lastPlacement ?? this.lastPlacement,
    clearedColors: clearedColors ?? this.clearedColors,
    fxTick: fxTick ?? this.fxTick,
    tool: clearTool ? null : (tool ?? this.tool),
    selection: selection ?? (clearTool ? const [] : this.selection),
    result: result ?? this.result,
    paused: paused ?? this.paused,
  );
}

enum BoosterOutcome { applied, noEffect, notEnoughCoins, unavailable }

/// Bridges the pure [BlockPlacementEngine] with rewards, persistence and UI.
class ClassicController extends Notifier<ClassicSession?> {
  final engine = BlockPlacementEngine();

  @override
  ClassicSession? build() => null;

  RewardService get _rewards => ref.read(rewardServiceProvider);
  FeedbackService get _fx => ref.read(feedbackProvider);

  void startNew(int size) {
    state = ClassicSession(
      game: engine.initializeBoard(size: size),
      sessionId: newTxId('cls'),
      boardSize: size,
    );
    _persist();
  }

  /// Restores an interrupted game from the save, if any.
  bool resume() {
    final saved = ref.read(playerStoreProvider).classicSession;
    if (saved == null) return false;
    try {
      final game = ClassicGameState.fromJson((saved['game'] as Map).cast<String, dynamic>());
      state = ClassicSession(game: game, sessionId: saved['id'] as String, boardSize: game.board.size);
      return true;
    } catch (_) {
      _rewards.saveClassicSession(null);
      return false;
    }
  }

  void _persist() {
    final s = state;
    if (s == null || s.finished) return;
    _rewards.saveClassicSession({'id': s.sessionId, 'game': s.game.toJson()});
  }

  bool canPlace(BlockShape shape, GridPoint origin) =>
      state != null && engine.validatePlacement(state!.game.board, shape, origin);

  /// Returns true if the shape was placed.
  bool place(int trayIndex, GridPoint origin) {
    final s = state;
    if (s == null || s.finished || s.tool != null) return false;
    final r = engine.placeBlock(s.game, trayIndex, origin);
    if (r == null) {
      _fx.play(Sfx.invalid);
      return false;
    }
    final shape = s.game.tray[trayIndex]!;
    _applyResult(
      s,
      r,
      colorFor: (p) => r.placedCells.contains(p) ? shape.colorIndex : CellValue.toColor(s.game.board.at(p.row, p.col)),
    );
    _rewards.recordClassicProgress(lines: r.linesCleared, shapes: 1, combo: r.state.combo, score: r.state.score);
    _persist();
    return true;
  }

  void _applyResult(ClassicSession s, PlacementResult r, {required int Function(GridPoint) colorFor}) {
    final cleared = {for (final p in r.clearedCells) p: colorFor(p)};
    state = s.copyWith(game: r.state, lastPlacement: r, clearedColors: cleared, fxTick: s.fxTick + 1, clearTool: true);
    _fx.play(r.linesCleared >= 2 ? Sfx.combo : (r.linesCleared > 0 ? Sfx.clear : Sfx.place));
  }

  void setPaused(bool p) {
    if (state != null) state = state!.copyWith(paused: p);
  }

  /// Ends the game and pays rewards exactly once.
  EconomyResult? finish() {
    final s = state;
    if (s == null) return null;
    if (s.finished) return s.result;
    final g = s.game;
    final res = _rewards.finishClassicGame(
      ClassicSummary(
        sessionId: s.sessionId,
        boardSize: s.boardSize,
        score: g.score,
        linesCleared: g.linesCleared,
        maxCombo: g.maxCombo,
        shapesPlaced: g.shapesPlaced,
      ),
    );
    state = s.copyWith(result: res);
    return res;
  }

  // -------------------------------------------------------------- boosters

  BoosterOutcome _charge(BoosterDef b) {
    final c = _rewards.chargeBooster(b, useId: newTxId('use_${b.id}'));
    if (c.ok) return BoosterOutcome.applied;
    return c.status == TxStatus.insufficientFunds ? BoosterOutcome.notEnoughCoins : BoosterOutcome.unavailable;
  }

  /// Engine first (to verify a real effect), then charge, then commit.
  BoosterOutcome _useInstant(BoosterDef b, ClassicGameState? Function(ClassicGameState) op) {
    final s = state;
    if (s == null || s.finished) return BoosterOutcome.unavailable;
    final next = op(s.game);
    if (next == null) return BoosterOutcome.noEffect;
    final paid = _charge(b);
    if (paid != BoosterOutcome.applied) return paid;
    state = s.copyWith(game: next, clearTool: true);
    _fx.play(Sfx.place);
    _persist();
    return BoosterOutcome.applied;
  }

  BoosterOutcome undo() => _useInstant(Boosters.undo, engine.undoPlacement);
  BoosterOutcome shuffle() => _useInstant(Boosters.shuffle, engine.shuffle);
  BoosterOutcome extraSpace() => _useInstant(Boosters.extraSpace, engine.extraSpace);

  void selectTool(CellTool? tool) {
    if (state == null) return;
    state = tool == null ? state!.copyWith(clearTool: true) : state!.copyWith(tool: tool, selection: const []);
  }

  /// Handles a board tap while a cell tool is active.
  BoosterOutcome tapCell(GridPoint p) {
    final s = state;
    if (s == null || s.tool == null) return BoosterOutcome.unavailable;
    switch (s.tool!) {
      case CellTool.hammer:
        return _useInstant(Boosters.hammer, (g) => engine.hammer(g, p));
      case CellTool.rainbow:
        final r = engine.rainbow(s.game, p);
        if (r == null) return BoosterOutcome.noEffect;
        final paid = _charge(Boosters.rainbow);
        if (paid != BoosterOutcome.applied) return paid;
        _applyResult(s, r, colorFor: (q) => q == p ? -1 : CellValue.toColor(s.game.board.at(q.row, q.col)));
        _rewards.recordClassicProgress(lines: r.linesCleared, shapes: 0, combo: r.state.combo, score: r.state.score);
        _persist();
        return BoosterOutcome.applied;
      case CellTool.remove:
        if (s.game.board.isEmpty(p.row, p.col)) return BoosterOutcome.noEffect;
        final sel = s.selection.contains(p) ? [...s.selection.where((q) => q != p)] : [...s.selection, p];
        if (sel.length > 3) return BoosterOutcome.noEffect;
        state = s.copyWith(selection: sel);
        return BoosterOutcome.applied;
    }
  }

  BoosterOutcome confirmRemove() {
    final s = state;
    if (s == null || s.selection.isEmpty) return BoosterOutcome.noEffect;
    return _useInstant(Boosters.remove, (g) => engine.removeCells(g, s.selection));
  }
}

final classicControllerProvider = NotifierProvider<ClassicController, ClassicSession?>(ClassicController.new);
