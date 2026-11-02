import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/player_store.dart';
import '../../shared/widgets/common.dart';
import '../wallet/models/wallet_models.dart';
import 'engine/reward_config.dart';
import 'reward_service.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});
  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(rewardServiceProvider).refreshDaily());
  }

  @override
  Widget build(BuildContext context) {
    final claimable = ref.watch(claimableAchievementsProvider).length;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Rewards', style: Theme.of(context).textTheme.headlineSmall)),
                    const WalletBar(),
                  ],
                ),
              ),
              TabBar(
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Daily'),
                  const Tab(text: 'Missions'),
                  Tab(
                    child: Badge(
                      isLabelVisible: claimable > 0,
                      label: Text('$claimable'),
                      child: const Text('Achievements'),
                    ),
                  ),
                ],
              ),
              const Expanded(child: TabBarView(children: [_DailyTab(), _MissionsTab(), _AchievementsTab()])),
            ],
          ),
        ),
      ),
    );
  }
}

String rewardLabel(Reward r) => '${r.coins} coins';

class _RewardIcons extends StatelessWidget {
  const _RewardIcons(this.r);
  final Reward r;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final e in r.amounts.entries) ...[
        Icon(currencyIcon(e.key), size: 16, color: currencyColor(e.key)),
        Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ],
  );
}

class _DailyTab extends ConsumerWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    final engine = ref.read(rewardEngineProvider);
    final now = ref.read(clockProvider)();
    final nextDay = engine.nextLoginDay(d, now);
    final displayDay = nextDay ?? d.daily.loginDay; // day highlighted
    final chestReady = engine.isChestAvailable(d, now);
    final rewards = engine.config.loginRewards;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Daily login', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  Text(
                    'Streak ${d.daily.currentStreak} 🔥',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 6 * 6) / 7;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 1; i <= 7; i++)
                        _DayTile(
                          day: i,
                          width: w,
                          reward: rewards[i - 1],
                          // Claimed in this cycle: days before the highlighted one (or including it, once claimed today).
                          claimed: nextDay == null ? i <= displayDay : i < displayDay,
                          current: nextDay != null && i == nextDay,
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: nextDay == null ? null : () => ref.read(rewardServiceProvider).claimDailyLogin(),
                child: Text(nextDay == null ? 'Come back tomorrow' : 'Claim day $nextDay'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Missing a day restarts the calendar at day 1.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Daily chest', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  TextButton(onPressed: () => _showOdds(context), child: const Text('Odds')),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: _ChestIcon(ready: chestReady, size: 92)),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: chestReady ? () => _openChest(context, ref) : null,
                child: Text(chestReady ? 'Open chest' : 'Opened today'),
              ),
              if (d.daily.chestHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Recent chests',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft),
                ),
                for (final h in d.daily.chestHistory.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Text(
                          h.date,
                          style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        _RewardIcons(h.reward),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showOdds(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Chest odds', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            const Text(
              'Fixed published probabilities. Every chest roll uses these exact odds.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            for (final o in ChestTable.outcomes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: rarityColor(o.rarity), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        o.rarity.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(o.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      '${(ChestTable.chance(o) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChest(BuildContext context, WidgetRef ref) async {
    final res = ref.read(rewardServiceProvider).openDailyChest();
    if (!res.ok || res.extra is! ChestOutcome) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ChestDialog(outcome: res.extra! as ChestOutcome),
    );
  }
}

Color rarityColor(Rarity r) => switch (r) {
  Rarity.common => const Color(0xFF8A8FA8),
  Rarity.uncommon => AppColors.success,
  Rarity.rare => AppColors.gem,
  Rarity.epic => const Color(0xFF9B5CFF),
};

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.width,
    required this.reward,
    required this.claimed,
    required this.current,
  });
  final int day;
  final double width;
  final Reward reward;
  final bool claimed, current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: claimed
            ? AppColors.success.withValues(alpha: 0.15)
            : (current ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bg),
        borderRadius: BorderRadius.circular(14),
        border: current ? Border.all(color: AppColors.accent, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(
            'D$day',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 2),
          Icon(
            claimed ? Icons.check_circle_rounded : currencyIcon(Currency.coins),
            color: claimed ? AppColors.success : currencyColor(Currency.coins),
            size: 22,
          ),
          FittedBox(
            child: Text('${reward.coins}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ChestIcon extends StatelessWidget {
  const _ChestIcon({required this.ready, this.size = 80, this.open = false});
  final bool ready, open;
  final double size;
  @override
  Widget build(BuildContext context) => Icon(
    open ? Icons.redeem_rounded : Icons.inventory_2_rounded,
    size: size,
    color: ready || open ? const Color(0xFFE09A3E) : Colors.black12,
  );
}

/// Shake -> burst -> reveal.
class _ChestDialog extends StatefulWidget {
  const _ChestDialog({required this.outcome});
  final ChestOutcome outcome;
  @override
  State<_ChestDialog> createState() => _ChestDialogState();
}

class _ChestDialogState extends State<_ChestDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.outcome;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final shaking = t < 0.5;
            final revealed = t >= 0.55;
            final shake = shaking ? math.sin(t * 60) * 0.12 * (t / 0.5) : 0.0;
            final pop = Curves.elasticOut.transform(((t - 0.55) / 0.45).clamp(0, 1));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (revealed)
                        Transform.scale(
                          scale: 0.6 + pop,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [rarityColor(o.rarity).withValues(alpha: 0.5), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      Transform.rotate(
                        angle: shake,
                        child: Transform.scale(
                          scale: revealed ? 0.7 + 0.3 * pop : 1,
                          child: _ChestIcon(ready: true, open: revealed, size: 96),
                        ),
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: revealed ? pop.clamp(0, 1) : 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: rarityColor(o.rarity),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          o.rarity.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        o.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Collect')),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MissionsTab extends ConsumerWidget {
  const _MissionsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Resets every day · ${d.daily.missionsClaimedTotal} completed in total',
          style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (final m in d.daily.missions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Builder(
              builder: (context) {
                final def = MissionCatalog.byId(m.id);
                final done = m.progress >= def.target;
                return SoftCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: (m.claimed ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                        child: Icon(
                          m.claimed ? Icons.check_rounded : Icons.flag_rounded,
                          color: m.claimed ? AppColors.success : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(def.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            PillProgress(m.progress / def.target, color: done ? AppColors.success : AppColors.primary),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '${m.progress}/${def.target}',
                                  style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                _RewardIcons(def.reward),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: done && !m.claimed ? () => ref.read(rewardServiceProvider).claimMission(m.id) : null,
                        child: Text(m.claimed ? 'Done' : 'Claim'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SectionTitle('Recent transactions'),
        for (final t in d.history.reversed.take(15))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(currencyIcon(t.currency), color: currencyColor(t.currency)),
            title: Text(
              t.reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: Text(
              t.amount > 0 ? '+${t.amount}' : '${t.amount}',
              style: TextStyle(fontWeight: FontWeight.w900, color: t.amount > 0 ? AppColors.success : AppColors.danger),
            ),
          ),
      ],
    );
  }
}

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: AchievementCatalog.all.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final a = AchievementCatalog.all[i];
        final p = a.progress(d);
        final claimed = d.claimedAchievements.contains(a.id);
        final done = p >= a.target;
        return SoftCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: claimed ? AppColors.coin : (done ? AppColors.accent : AppColors.bg),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.emoji_events_rounded, color: claimed || done ? Colors.white : AppColors.inkSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      a.description,
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    PillProgress(p / a.target, height: 7, color: done ? AppColors.success : AppColors.primary),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${math.min(p, a.target)}/${a.target}',
                          style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        const Spacer(),
                        _RewardIcons(a.reward),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: done && !claimed ? () => ref.read(rewardServiceProvider).claimAchievement(a.id) : null,
                child: Text(claimed ? '✓' : 'Claim'),
              ),
            ],
          ),
        );
      },
    );
  }
}
