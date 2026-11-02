import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/player_store.dart';
import '../../../core/storage/save_data.dart';
import '../../../shared/widgets/common.dart';
import '../../rewards/reward_service.dart';

class ClassicHomeScreen extends ConsumerWidget {
  const ClassicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    final cfg = ref.read(rewardEngineProvider).config;
    final now = ref.read(clockProvider)();
    final st = d.classic;
    final dailyBest = st.dailyBestDate == dayKey(now) ? st.dailyBest : 0;
    final weeklyBest = st.weeklyBestKey == weekKey(now) ? st.weeklyBest : 0;
    final size = d.settings.classicBoardSize;

    Widget stat(String label, String value, IconData icon) => Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(
              label,
              style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(child: Text('Classic', style: Theme.of(context).textTheme.headlineSmall)),
                const WalletBar(),
              ],
            ),
            const SizedBox(height: 16),
            SoftCard(
              gradient: const LinearGradient(colors: [Color(0xFF6B4EFF), Color(0xFF4DA3FF)]),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal best',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                  ),
                  AnimatedCount(
                    st.best(size),
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      selectedBackgroundColor: Colors.white,
                      selectedForegroundColor: AppColors.primary,
                    ),
                    segments: const [
                      ButtonSegment(value: 8, label: Text('8 × 8')),
                      ButtonSegment(value: 10, label: Text('10 × 10')),
                    ],
                    selected: {size},
                    onSelectionChanged: (v) {
                      final store = ref.read(playerStoreProvider.notifier);
                      store.commit(
                        store.data.copyWith(settings: store.data.settings.copyWith(classicBoardSize: v.first)),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (d.classicSession != null) ...[
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                            ),
                            onPressed: () => context.push('/play/classic?resume=1'),
                            child: const Text('Resume game'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                          onPressed: () => context.push('/play/classic'),
                          child: const Text('New game'),
                        ),
                      ),
                    ],
                  ),
                  if (d.classicSession != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Starting a new game finishes the saved one and pays its rewards.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SectionTitle('Challenges'),
            SoftCard(
              child: Column(
                children: [
                  for (final m in cfg.dailyScoreMilestones.entries)
                    _ChallengeRow(
                      title: 'Daily: score ${m.key} in one game',
                      progress: dailyBest,
                      target: m.key,
                      reward: '${m.value} coins',
                      claimed: d.hasProcessed('classic_daily:${dayKey(now)}:${m.key}'),
                    ),
                  _ChallengeRow(
                    title: 'Weekly: score ${cfg.weeklyScoreTarget} in one game',
                    progress: weeklyBest,
                    target: cfg.weeklyScoreTarget,
                    reward: '${cfg.weeklyReward.coins} coins',
                    claimed: d.hasProcessed('classic_weekly:${weekKey(now)}'),
                  ),
                ],
              ),
            ),
            const SectionTitle('Lifetime'),
            Row(
              children: [
                stat('Games', '${st.gamesPlayed}', Icons.sports_esports_rounded),
                const SizedBox(width: 10),
                stat('Lines', '${st.totalLines}', Icons.horizontal_rule_rounded),
                const SizedBox(width: 10),
                stat('Top combo', 'x${st.highestCombo}', Icons.local_fire_department_rounded),
              ],
            ),
            const SizedBox(height: 14),
            const SoftCard(
              child: Text(
                'How to play: drag shapes onto the board. Fill a full row or column to clear it. '
                'Clearing several lines at once and on consecutive turns builds combos. '
                'The game ends when none of your three shapes fit.',
                style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.title,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });
  final String title, reward;
  final int progress, target;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            claimed ? Icons.check_circle_rounded : Icons.emoji_events_outlined,
            color: claimed ? AppColors.success : AppColors.coin,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                PillProgress(progress / target, height: 7, color: claimed ? AppColors.success : AppColors.primary),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            claimed ? 'Paid' : reward,
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
