import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/audio/feedback_service.dart';
import '../../features/rewards/engine/reward_engine.dart';
import '../../features/rewards/reward_service.dart';
import '../../features/wallet/models/wallet_models.dart';
import 'common.dart';

/// Global overlay: plays a "reward collected" animation for each grant the
/// RewardService announces. It never blocks input (IgnorePointer).
class RewardOverlay extends ConsumerWidget {
  const RewardOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(rewardFeedProvider);
    return Stack(
      children: [
        child,
        if (feed.isNotEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: _RewardToast(
                key: ObjectKey(feed.first),
                grant: feed.first,
                onDone: () => ref.read(rewardFeedProvider.notifier).consume(feed.first),
              ),
            ),
          ),
      ],
    );
  }
}

class _RewardToast extends ConsumerStatefulWidget {
  const _RewardToast({super.key, required this.grant, required this.onDone});
  final RewardGrant grant;
  final VoidCallback onDone;
  @override
  ConsumerState<_RewardToast> createState() => _RewardToastState();
}

class _RewardToastState extends ConsumerState<_RewardToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
    ..forward().whenComplete(widget.onDone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(feedbackProvider).play(Sfx.reward));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.grant.reward;
    final items = <(Currency?, String, IconData, Color)>[
      for (final e in r.amounts.entries) (e.key, '+${e.value}', currencyIcon(e.key), currencyColor(e.key)),
    ];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final enter = Curves.elasticOut.transform((t / 0.35).clamp(0, 1));
        final exit = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - exit,
          child: Transform.translate(
            offset: Offset(0, -60 * (1 - enter) - 30 * exit),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Burst of currency icons.
                if (items.isNotEmpty)
                  for (var i = 0; i < 10; i++) _particle(i, t, items[i % items.length].$3, items[i % items.length].$4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.grant.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft),
                        ),
                      ),
                      const SizedBox(width: 10),
                      for (final it in items) ...[
                        Icon(it.$3, color: it.$4, size: 22),
                        const SizedBox(width: 2),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _particle(int i, double t, IconData icon, Color color) {
    final p = ((t - 0.1) / 0.7).clamp(0.0, 1.0);
    final angle = (i / 10) * math.pi * 2 + 0.3;
    final dist = 90 * Curves.easeOutCubic.transform(p);
    return Opacity(
      opacity: p == 0 ? 0 : (1 - p),
      child: Transform.translate(
        offset: Offset(math.cos(angle) * dist * 1.6, math.sin(angle) * dist * 0.7),
        child: Transform.rotate(
          angle: p * 4,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

/// Lightweight confetti using a single controller and painter.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 60});
  final int count;
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(painter: _ConfettiPainter(_c, widget.count), size: Size.infinite),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.anim, this.count) : super(repaint: anim);
  final Animation<double> anim;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final rnd = math.Random(3);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final speed = 0.6 + rnd.nextDouble() * 0.6;
      final sway = rnd.nextDouble() * 40;
      final y = -20 + t * speed * (size.height + 60);
      final x = x0 + math.sin(t * 8 + i) * sway;
      paint.color = AppColors.blocks[i % AppColors.blocks.length].withValues(alpha: (1 - t * 0.7).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 10 + i);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

/// Star that pops in after [delay].
class PopStar extends StatelessWidget {
  const PopStar({super.key, required this.filled, required this.delay, this.size = 54});
  final bool filled;
  final Duration delay;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: delay + const Duration(milliseconds: 500),
      builder: (_, v, _) {
        final total = delay.inMilliseconds + 500;
        final local = ((v * total - delay.inMilliseconds) / 500).clamp(0.0, 1.0);
        final s = filled ? Curves.elasticOut.transform(local) : 1.0;
        return Transform.scale(
          scale: filled ? s : 1,
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: filled && local > 0 ? AppColors.star : Colors.black.withValues(alpha: 0.12),
          ),
        );
      },
    );
  }
}
