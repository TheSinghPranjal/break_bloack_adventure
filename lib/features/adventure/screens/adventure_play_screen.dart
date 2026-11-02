import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/player_store.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/reward_fx.dart';
import '../../shop/booster_catalog.dart';
import '../../wallet/models/wallet_models.dart';
import '../controllers/adventure_controller.dart';
import '../levels/level_repository.dart';
import '../levels/world_catalog.dart';
import '../models/puzzle_models.dart';
import '../widgets/puzzle_board_view.dart';

class AdventurePlayScreen extends ConsumerStatefulWidget {
  const AdventurePlayScreen({super.key, required this.worldId, required this.levelId});
  final int worldId;
  final int levelId;

  @override
  ConsumerState<AdventurePlayScreen> createState() => _AdventurePlayScreenState();
}

class _AdventurePlayScreenState extends ConsumerState<AdventurePlayScreen> {
  bool _paused = false;
  bool _tipVisible = true;
  int? _startedFor;

  AdventureController get _ctrl => ref.read(adventureControllerProvider.notifier);

  void _ensureStarted(List<PuzzleLevel> levels) {
    final key = widget.worldId * 1000 + widget.levelId;
    if (_startedFor == key) return;
    _startedFor = key;
    final level = levels.firstWhere((l) => l.levelId == widget.levelId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.start(level);
      setState(() => _tipVisible = level.tip != null);
    });
  }

  Future<void> _undo() async {
    var r = _ctrl.undo();
    if (r == AssistResult.needsPayment) {
      final inv = ref.read(playerStoreProvider).inventory[Boosters.advUndo.id] ?? 0;
      if (inv == 0) {
        final ok = await confirmPurchase(
          context,
          title: 'Extra undo',
          message: 'Your 3 free undos are used.\nUndo once more?',
          currency: Currency.coins,
          price: Boosters.advUndo.price,
          confirmLabel: 'Undo',
        );
        if (!ok) return;
      }
      r = _ctrl.undo(paid: true);
    }
    _report(r);
  }

  Future<void> _hint() async {
    var r = await _ctrl.hint();
    if (r == AssistResult.needsPayment) {
      if (!mounted) return;
      final inv = ref.read(playerStoreProvider).inventory[Boosters.advHint.id] ?? 0;
      if (inv == 0) {
        final ok = await confirmPurchase(
          context,
          title: 'Extra hint',
          message: 'Your free hint is used.\nShow the next best move?',
          currency: Currency.coins,
          price: Boosters.advHint.price,
          confirmLabel: 'Show',
        );
        if (!ok) return;
      }
      r = await _ctrl.hint(paid: true);
    }
    _report(r);
  }

  void _report(AssistResult r) {
    if (!mounted) return;
    switch (r) {
      case AssistResult.notEnoughCoins:
        showToast(context, 'Not enough coins.', error: true);
      case AssistResult.noSolution:
        showToast(context, 'No solution from here within your moves. Try Undo or Restart (no coins charged).');
      case AssistResult.nothingToDo:
        showToast(context, 'Nothing to undo.');
      case AssistResult.ok || AssistResult.needsPayment:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final world = WorldCatalog.byId(widget.worldId);
    final theme = WorldTheme.of(world.themeKey);
    final levels = ref.watch(worldLevelsProvider(widget.worldId));
    final s = ref.watch(adventureControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paused = true);
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.top, theme.bottom],
            ),
          ),
          child: SafeArea(
            child: levels.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                _ensureStarted(list);
                if (s == null || s.level.levelId != widget.levelId || s.level.worldId != widget.worldId) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final objectives = _ctrl.engine.checkObjectives(s.level, s.state);
                return Stack(
                  children: [
                    Column(
                      children: [
                        _TopBar(session: s, worldName: world.name, onPause: () => setState(() => _paused = true)),
                        _ObjectiveRow(progress: objectives),
                        if (_tipVisible && s.level.tip != null)
                          _TipBanner(text: s.level.tip!, onClose: () => setState(() => _tipVisible = false)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: PuzzleBoardView(
                              session: s,
                              boardColor: theme.board,
                              maxDistance: _ctrl.maxDistance,
                              onMove: (m) {
                                if (_tipVisible) setState(() => _tipVisible = false);
                                return _ctrl.move(m);
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              HudButton(
                                icon: Icons.undo_rounded,
                                label: 'Undo',
                                badge: s.freeUndosLeft > 0 ? '${s.freeUndosLeft}' : '🪙${Boosters.advUndo.price}',
                                enabled: s.history.isNotEmpty && s.state.status == PuzzleStatus.playing,
                                onTap: _undo,
                              ),
                              HudButton(
                                icon: s.hintLoading ? Icons.hourglass_top_rounded : Icons.lightbulb_rounded,
                                label: 'Hint',
                                badge: s.freeHintsLeft > 0 ? '${s.freeHintsLeft}' : '🪙${Boosters.advHint.price}',
                                enabled: s.state.status == PuzzleStatus.playing && !s.hintLoading,
                                onTap: _hint,
                              ),
                              HudButton(icon: Icons.refresh_rounded, label: 'Restart', onTap: _ctrl.restart),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (s.state.status == PuzzleStatus.won) _WinPanel(session: s, levelCount: list.length),
                    if (s.state.status == PuzzleStatus.lost)
                      _LosePanel(session: s, onRetry: _ctrl.restart, onUndo: s.history.isEmpty ? null : _undo),
                    if (_paused && s.state.status == PuzzleStatus.playing)
                      _PausePanel(
                        onResume: () => setState(() => _paused = false),
                        onRestart: () {
                          _ctrl.restart();
                          setState(() => _paused = false);
                        },
                        onQuit: () => context.go('/adventure/world/${widget.worldId}'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.worldName, required this.onPause});
  final AdventureSession session;
  final String worldName;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final left = session.movesLeft;
    final low = left <= 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          HudButton(icon: Icons.pause_rounded, onTap: onPause),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worldName.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Level ${session.level.levelId}',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: low ? AppColors.danger : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  'MOVES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: low ? Colors.white : AppColors.inkSoft,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text(
                    '$left',
                    key: ValueKey(left),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: low ? Colors.white : AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.progress});
  final List<ObjectiveProgress> progress;

  static (IconData, Color, String) describe(PuzzleObjective o) => switch (o.type) {
    ObjectiveType.clearTargets => (Icons.adjust_rounded, AppColors.primary, 'Fill pads'),
    ObjectiveType.clearColor => (Icons.circle, AppColors.named_(o.color), 'Clear ${o.color}'),
    ObjectiveType.clearAll => (Icons.layers_clear_rounded, AppColors.primary, 'Clear blocks'),
    ObjectiveType.clearCount => (Icons.grid_view_rounded, AppColors.primary, 'Clear'),
    ObjectiveType.reachExit => (Icons.flag_rounded, AppColors.star, 'Reach exit'),
    ObjectiveType.collectStars => (Icons.star_rounded, AppColors.star, 'Stars'),
    ObjectiveType.destroyIce => (Icons.ac_unit_rounded, AppColors.gem, 'Break ice'),
    ObjectiveType.freeLocked => (Icons.lock_open_rounded, AppColors.accent, 'Unlock'),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final p in progress)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: p.done ? AppColors.success : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.done ? Icons.check_circle_rounded : describe(p.objective).$1,
                    size: 18,
                    color: p.done ? Colors.white : describe(p.objective).$2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${describe(p.objective).$3}  ${p.current.clamp(0, p.target)}/${p.target}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: p.done ? Colors.white : AppColors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  const _TipBanner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        const Icon(Icons.tips_and_updates_rounded, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18)),
      ],
    ),
  );
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.child, this.confetti = false});
  final Widget child;
  final bool confetti;
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.5))),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, s, c) => Transform.scale(scale: s, child: c),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: child,
            ),
          ),
        ),
        if (confetti) const Positioned.fill(child: Confetti()),
      ],
    ),
  );
}

class _WinPanel extends StatelessWidget {
  const _WinPanel({required this.session, required this.levelCount});
  final AdventureSession session;
  final int levelCount;

  @override
  Widget build(BuildContext context) {
    final total = session.result?.total;
    final grants = session.result?.grants ?? const [];
    final l = session.level;
    final hasNext = l.levelId < levelCount;
    return _Overlay(
      confetti: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Level Complete!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == 2 ? 14 : 0),
                  child: PopStar(
                    filled: i <= session.stars,
                    delay: Duration(milliseconds: 250 * i),
                    size: i == 2 ? 64 : 52,
                  ),
                ),
            ],
          ),
          Text(
            'Solved in ${session.state.movesUsed} moves',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (total != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final e in total.amounts.entries) CurrencyChip(e.key, e.value)],
            ),
          for (final g in grants.where((g) => !g.txId.startsWith('adv:') && !g.txId.startsWith('adv_replay')))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🎁 ${g.reason}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.go('/adventure/world/${l.worldId}'),
                icon: const Icon(Icons.home_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () =>
                    ProviderScope.containerOf(context).read(adventureControllerProvider.notifier).restart(),
                icon: const Icon(Icons.replay_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: hasNext
                      ? () => context.pushReplacement('/play/adventure/${l.worldId}/${l.levelId + 1}')
                      : () => context.go('/adventure'),
                  child: Text(hasNext ? 'Next Level' : 'World Map'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LosePanel extends StatelessWidget {
  const _LosePanel({required this.session, required this.onRetry, this.onUndo});
  final AdventureSession session;
  final VoidCallback onRetry;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final outOfMoves = session.state.movesUsed >= session.level.moveLimit;
    return _Overlay(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.sentiment_dissatisfied_rounded, size: 52, color: AppColors.danger),
          Text(
            outOfMoves ? 'Out of moves' : 'No moves left',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Every level has a solution. Try a different order!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
          if (onUndo != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo_rounded),
              label: Text(session.freeUndosLeft > 0 ? 'Undo last move (free)' : 'Undo last move'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/adventure/world/${session.level.worldId}'),
            child: const Text('Back to levels'),
          ),
        ],
      ),
    );
  }
}

class _PausePanel extends StatelessWidget {
  const _PausePanel({required this.onResume, required this.onRestart, required this.onQuit});
  final VoidCallback onResume, onRestart, onQuit;
  @override
  Widget build(BuildContext context) => _Overlay(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Paused', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: onResume, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Resume')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Restart level'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: onQuit, icon: const Icon(Icons.map_rounded), label: const Text('Quit to level map')),
      ],
    ),
  );
}
