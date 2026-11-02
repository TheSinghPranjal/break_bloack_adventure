import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/audio/feedback_service.dart';
import '../../../core/services/player_store.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/reward_fx.dart';
import '../../shop/booster_catalog.dart';
import '../../wallet/models/wallet_models.dart';
import '../controllers/classic_controller.dart';
import '../models/block_shape.dart';
import '../widgets/classic_board_view.dart';

class ClassicPlayScreen extends ConsumerStatefulWidget {
  const ClassicPlayScreen({super.key, this.resume = false});
  final bool resume;

  @override
  ConsumerState<ClassicPlayScreen> createState() => _ClassicPlayScreenState();
}

class _ClassicPlayScreenState extends ConsumerState<ClassicPlayScreen> {
  final _ghost = ValueNotifier<GhostPreview?>(null);
  final _boardKey = GlobalKey();
  double _cell = 30;

  ClassicController get _ctrl => ref.read(classicControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.resume && _ctrl.resume()) return;
      // Starting fresh while a saved game exists: finish it first so its
      // score and rewards are kept, never silently discarded.
      if (ref.read(playerStoreProvider).classicSession != null && _ctrl.resume()) _ctrl.finish();
      _ctrl.startNew(ref.read(playerStoreProvider).settings.classicBoardSize);
    });
  }

  @override
  void dispose() {
    _ghost.dispose();
    super.dispose();
  }

  GridPoint? _originFor(Offset globalTopLeft) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalTopLeft);
    return GridPoint((local.dy / _cell).round(), (local.dx / _cell).round());
  }

  /// Whether any cell of [shape] at [origin] lands on the board.
  bool _overlapsBoard(BlockShape shape, GridPoint origin) {
    final n = ref.read(classicControllerProvider)?.game.board.size ?? 0;
    return shape.cells.any((c) {
      final r = origin.row + c.row, col = origin.col + c.col;
      return r >= 0 && r < n && col >= 0 && col < n;
    });
  }

  void _onMove(int trayIndex, Offset topLeft) {
    final s = ref.read(classicControllerProvider);
    final shape = s?.game.tray[trayIndex];
    final origin = _originFor(topLeft);
    if (s == null || shape == null || origin == null) return;
    if (!_overlapsBoard(shape, origin)) {
      _ghost.value = null;
      return;
    }
    final cur = _ghost.value;
    if (cur != null && cur.origin == origin && cur.shape == shape) return;
    _ghost.value = GhostPreview(shape, origin, _ctrl.canPlace(shape, origin));
  }

  void _onDrop(int trayIndex, Offset topLeft) {
    final origin = _originFor(topLeft);
    _ghost.value = null;
    final shape = ref.read(classicControllerProvider)?.game.tray[trayIndex];
    // Dropped away from the board (e.g. back on the tray): snap back quietly.
    if (origin == null || shape == null || !_overlapsBoard(shape, origin)) return;
    _ctrl.place(trayIndex, origin);
  }

  Future<void> _useBooster(BoosterDef b) async {
    final s = ref.read(classicControllerProvider);
    if (s == null || s.finished) return;
    final owned = ref.read(playerStoreProvider).inventory[b.id] ?? 0;
    if (owned == 0) {
      final ok = await confirmPurchase(
        context,
        title: b.name,
        message: '${b.description}\nUse for ${b.price} coins?',
        currency: Currency.coins,
        price: b.price,
        confirmLabel: 'Use',
      );
      if (!ok || !mounted) return;
    }
    final BoosterOutcome out;
    switch (b.id) {
      case 'undo':
        out = _ctrl.undo();
      case 'shuffle':
        out = _ctrl.shuffle();
      case 'extra_space':
        out = _ctrl.extraSpace();
      case 'hammer':
        _ctrl.selectTool(CellTool.hammer);
        return;
      case 'remove':
        _ctrl.selectTool(CellTool.remove);
        return;
      case 'rainbow':
        _ctrl.selectTool(CellTool.rainbow);
        return;
      default:
        return;
    }
    _report(out);
  }

  void _report(BoosterOutcome out) {
    if (!mounted) return;
    switch (out) {
      case BoosterOutcome.applied:
        break;
      case BoosterOutcome.noEffect:
        showToast(context, 'That booster would have no effect right now — nothing was charged.');
      case BoosterOutcome.notEnoughCoins:
        showToast(context, 'Not enough coins. Earn more from games, missions and daily rewards.', error: true);
      case BoosterOutcome.unavailable:
        showToast(context, 'Booster unavailable.', error: true);
    }
  }

  void _finish() {
    _ctrl.finish();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(classicControllerProvider);
    final best = ref.watch(playerStoreProvider.select((d) => d.classic.best(s?.boardSize ?? 10)));
    if (s == null) {
      return const Scaffold(
        backgroundColor: AppColors.boardBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final g = s.game;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !s.finished) _ctrl.setPaused(true);
        if (!didPop && s.finished) context.go('/classic');
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5B45C9), Color(0xFF2E2470)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final n = g.board.size;
                final w = math.min(c.maxWidth - 24, 560.0);
                final side = math.min(w, (c.maxHeight - 230) / (1 + 2.6 / n));
                _cell = side / n;
                final trayCell = math.min(_cell * 0.55, (c.maxWidth - 48) / 15);
                return Stack(
                  children: [
                    // The whole play area is the drop target: the dragged
                    // shape floats above the finger, so placing in the bottom
                    // rows puts the finger below the board.
                    DragTarget<int>(
                      onWillAcceptWithDetails: (_) => true,
                      onMove: (d) => _onMove(d.data, d.offset),
                      onLeave: (_) => _ghost.value = null,
                      onAcceptWithDetails: (d) => _onDrop(d.data, d.offset),
                      builder: (context, _, _) => Column(
                        children: [
                          _Hud(score: g.score, best: best, combo: g.combo, onPause: () => _ctrl.setPaused(true)),
                          const Spacer(),
                          _ScorePop(
                            tick: s.fxTick,
                            points: s.lastPlacement?.pointsGained ?? 0,
                            combo: g.combo,
                            lines: s.lastPlacement?.linesCleared ?? 0,
                          ),
                          SizedBox(
                            key: _boardKey,
                            width: side,
                            height: side,
                            child: ClassicBoardView(
                              board: g.board,
                              ghost: _ghost,
                              clearedColors: s.clearedColors,
                              fxTick: s.fxTick,
                              selection: s.selection,
                              onTapCell: s.tool == null ? null : (p) => _report(_ctrl.tapCell(p)),
                            ),
                          ),
                          const Spacer(),
                          if (s.tool != null)
                            _ToolBanner(
                              session: s,
                              onCancel: () => _ctrl.selectTool(null),
                              onConfirm: () => _report(_ctrl.confirmRemove()),
                            )
                          else
                            _Tray(
                              tray: g.tray,
                              trayCell: trayCell,
                              boardCell: _cell,
                              onDragStarted: () => ref.read(feedbackProvider).play(Sfx.pickup),
                              onDragEnd: () => _ghost.value = null,
                            ),
                          const SizedBox(height: 8),
                          _BoosterBar(onUse: _useBooster),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    if (g.isGameOver && !s.finished) _GameOverPanel(onRescue: _useBooster, onFinish: _finish),
                    if (s.finished) _ResultsPanel(session: s, best: best),
                    if (s.paused && !s.finished)
                      _PausePanel(
                        onResume: () => _ctrl.setPaused(false),
                        onRestart: () {
                          _ctrl.finish();
                          _ctrl.startNew(s.boardSize);
                        },
                        onHome: () {
                          _ctrl.setPaused(false);
                          context.go('/classic');
                        },
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

class _Hud extends StatelessWidget {
  const _Hud({required this.score, required this.best, required this.combo, required this.onPause});
  final int score, best, combo;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          HudButton(icon: Icons.pause_rounded, onTap: onPause),
          Expanded(
            child: Column(
              children: [
                AnimatedCount(
                  score,
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: AppColors.coin, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Best ${math.max(best, score)}',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Container(
              key: ValueKey(combo),
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: combo >= 2 ? AppColors.accent : Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'COMBO',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'x$combo',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePop extends StatelessWidget {
  const _ScorePop({required this.tick, required this.points, required this.combo, required this.lines});
  final int tick, points, combo, lines;

  @override
  Widget build(BuildContext context) {
    final label = lines >= 2
        ? '$lines LINES! +$points'
        : lines == 1
        ? (combo >= 2 ? 'Combo x$combo! +$points' : 'Nice! +$points')
        : '';
    return SizedBox(
      height: 34,
      child: label.isEmpty
          ? null
          : TweenAnimationBuilder<double>(
              key: ValueKey(tick),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              builder: (_, t, _) => Opacity(
                opacity: t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3),
                child: Transform.scale(
                  scale: Curves.elasticOut.transform((t / 0.4).clamp(0, 1)),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.coin,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.tray,
    required this.trayCell,
    required this.boardCell,
    required this.onDragStarted,
    required this.onDragEnd,
  });
  final List<BlockShape?> tray;
  final double trayCell, boardCell;
  final VoidCallback onDragStarted, onDragEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: trayCell * 5 + 8,
      child: Row(
        children: [
          for (var i = 0; i < tray.length; i++)
            Expanded(
              child: Center(
                child: tray[i] == null
                    ? const SizedBox.shrink()
                    : TweenAnimationBuilder<double>(
                        key: ValueKey('${tray[i]!.id}-$i-${tray.hashCode}'),
                        tween: Tween(begin: 0.4, end: 1),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.elasticOut,
                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                        child: _draggable(i, tray[i]!),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _draggable(int i, BlockShape shape) {
    final fw = shape.width * boardCell, fh = shape.height * boardCell;
    return Draggable<int>(
      data: i,
      dragAnchorStrategy: (d, ctx, pos) => Offset(fw / 2, fh + boardCell * 1.4),
      feedback: ShapeView(shape: shape, cell: boardCell, opacity: 0.95),
      childWhenDragging: ShapeView(shape: shape, cell: trayCell, opacity: 0.25),
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd(),
      // Generous hit area around small shapes.
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(10),
        child: ShapeView(shape: shape, cell: trayCell),
      ),
    );
  }
}

class _BoosterBar extends ConsumerWidget {
  const _BoosterBar({required this.onUse});
  final void Function(BoosterDef) onUse;

  static const icons = {
    'undo': Icons.undo_rounded,
    'hammer': Icons.gavel_rounded,
    'remove': Icons.cleaning_services_rounded,
    'shuffle': Icons.shuffle_rounded,
    'rainbow': Icons.auto_awesome_rounded,
    'extra_space': Icons.unfold_more_double_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(playerStoreProvider.select((d) => d.inventory));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final b in Boosters.classic)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: HudButton(
                icon: icons[b.id]!,
                label: b.name,
                badge: (inv[b.id] ?? 0) > 0 ? 'x${inv[b.id]}' : '🪙${b.price}',
                onTap: () => onUse(b),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolBanner extends StatelessWidget {
  const _ToolBanner({required this.session, required this.onCancel, required this.onConfirm});
  final ClassicSession session;
  final VoidCallback onCancel, onConfirm;

  @override
  Widget build(BuildContext context) {
    final text = switch (session.tool!) {
      CellTool.hammer => 'Tap a block to smash it',
      CellTool.rainbow => 'Tap an empty cell to fill it with a wild block',
      CellTool.remove => 'Select up to 3 blocks (${session.selection.length}/3)',
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (session.tool == CellTool.remove)
            FilledButton(onPressed: session.selection.isEmpty ? null : onConfirm, child: const Text('Remove')),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 350),
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
    ),
  );
}

class _PausePanel extends StatelessWidget {
  const _PausePanel({required this.onResume, required this.onRestart, required this.onHome});
  final VoidCallback onResume, onRestart, onHome;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Paused', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Your game is saved automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onResume, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Resume')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('End & restart'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onHome,
          icon: const Icon(Icons.home_rounded),
          label: const Text('Leave (keep game)'),
        ),
      ],
    ),
  );
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.onRescue, required this.onFinish});
  final void Function(BoosterDef) onRescue;
  final VoidCallback onFinish;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.grid_off_rounded, size: 48, color: AppColors.danger),
        Text('No room left!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'None of your shapes fit. Use a rescue booster or see your results.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in [Boosters.extraSpace, Boosters.shuffle, Boosters.hammer, Boosters.undo])
              ActionChip(
                avatar: const Icon(Icons.monetization_on_rounded, color: AppColors.coin, size: 18),
                label: Text('${b.name} · ${b.price}'),
                onPressed: () => onRescue(b),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onFinish, child: const Text('See results')),
      ],
    ),
  );
}

class _ResultsPanel extends ConsumerWidget {
  const _ResultsPanel({required this.session, required this.best});
  final ClassicSession session;
  final int best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = session.game;
    final coins = session.result?.total.coins ?? 0;
    final newBest = g.score >= best && g.score > 0;
    Widget stat(String label, String value, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
    return Stack(
      children: [
        _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                newBest ? 'New Best!' : 'Game Over',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Center(
                child: AnimatedCount(
                  g.score,
                  style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              stat('Best score', '${math.max(best, g.score)}', Icons.emoji_events_rounded),
              stat('Highest combo', 'x${g.maxCombo}', Icons.local_fire_department_rounded),
              stat('Lines cleared', '${g.linesCleared}', Icons.horizontal_rule_rounded),
              stat('Blocks placed', '${g.shapesPlaced}', Icons.widgets_rounded),
              const Divider(height: 20),
              Center(child: CurrencyChip(Currency.coins, coins)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => context.go('/classic'), child: const Text('Home')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => ref.read(classicControllerProvider.notifier).startNew(session.boardSize),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (newBest) const Positioned.fill(child: Confetti()),
      ],
    );
  }
}
