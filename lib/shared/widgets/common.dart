import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../features/wallet/models/wallet_models.dart';
import '../../features/wallet/wallet_service.dart';

IconData currencyIcon(Currency c) => switch (c) {
  Currency.coins => Icons.monetization_on_rounded,
};

Color currencyColor(Currency c) => switch (c) {
  Currency.coins => AppColors.coin,
};

/// Number that smoothly counts to its new value.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value, {super.key, this.style});
  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(_fmt(v.round()), style: style),
    );
  }

  static String _fmt(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class CurrencyChip extends StatelessWidget {
  CurrencyChip(Currency currency, this.amount, {super.key, this.onTap, this.dark = false})
    : icon = currencyIcon(currency),
      color = currencyColor(currency);

  const CurrencyChip._(this.icon, this.color, this.amount, {super.key, this.onTap, this.dark = false});

  final IconData icon;
  final Color color;
  final int amount;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: dark ? Colors.black.withValues(alpha: 0.22) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: dark
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 6),
            AnimatedCount(
              amount,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: dark ? Colors.white : AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Same pill as [CurrencyChip] for a non-currency count (e.g. stars).
class StatChip extends CurrencyChip {
  const StatChip({super.key, required IconData icon, required Color color, required int amount})
    : super._(icon, color, amount);
}

/// Coin balance bound to the shared wallet. Tapping opens the shop.
class WalletBar extends ConsumerWidget {
  const WalletBar({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider);
    return CurrencyChip(Currency.coins, w.coins, onTap: () => context.push('/shop'), dark: dark);
  }
}

/// Small press-to-squash wrapper for tappable cards.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? 0.96 : 1, duration: const Duration(milliseconds: 110), child: widget.child),
    );
  }
}

/// Round icon button used in game HUDs, with an optional badge.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
    this.label,
    this.color = Colors.white,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final String? label;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Pressable(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 26),
                ),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirmation for any spend. Returns true if the player confirmed.
Future<bool> confirmPurchase(
  BuildContext context, {
  required String title,
  required String message,
  required Currency currency,
  required int price,
  String confirmLabel = 'Buy',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          CurrencyChip(currency, price),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(milliseconds: 1800),
      ),
    );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

/// Rounded white card with soft shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.gradient,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
      ],
    ),
    child: child,
  );
}

/// Progress bar with rounded ends.
class PillProgress extends StatelessWidget {
  const PillProgress(this.value, {super.key, this.color = AppColors.primary, this.height = 10, this.background});
  final double value;
  final Color color;
  final double height;
  final Color? background;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: background ?? color.withValues(alpha: 0.15))),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ],
      ),
    ),
  );
}
