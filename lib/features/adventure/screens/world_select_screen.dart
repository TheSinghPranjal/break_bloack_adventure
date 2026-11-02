import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/player_store.dart';
import '../../../shared/widgets/common.dart';
import '../../rewards/reward_service.dart';
import '../levels/world_catalog.dart';

class WorldSelectScreen extends ConsumerWidget {
  const WorldSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(playerStoreProvider);
    final rewards = ref.read(rewardEngineProvider);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: Text('Adventure', style: Theme.of(context).textTheme.headlineSmall)),
                    StatChip(icon: Icons.star_rounded, color: AppColors.star, amount: data.adventure.totalStars),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: WorldCatalog.worlds.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final w = WorldCatalog.worlds[i];
                  final unlocked = rewards.isWorldUnlocked(data, w.id);
                  final done = data.adventure.completedInWorld(w.id);
                  final stars = data.adventure.starsInWorld(w.id);
                  final theme = WorldTheme.of(w.themeKey);
                  return Pressable(
                    onTap: unlocked
                        ? () => context.go('/adventure/world/${w.id}')
                        : () => showToast(
                            context,
                            'Complete all ${WorldCatalog.levelsPerWorld} levels of ${WorldCatalog.byId(w.id - 1).name} and collect ${(w.id - 1) * rewards.config.starsPerWorldGate} stars to unlock.',
                          ),
                    child: Container(
                      height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: [theme.top, theme.bottom],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.top.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -18,
                            child: Icon(theme.icon, size: 130, color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WORLD ${w.id}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  w.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                  ),
                                ),
                                Text(
                                  w.tagline,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (unlocked)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PillProgress(
                                          done / WorldCatalog.levelsPerWorld,
                                          color: Colors.white,
                                          background: Colors.white24,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '$done/${WorldCatalog.levelsPerWorld}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                                      Text(
                                        '$stars',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  )
                                else
                                  const Row(
                                    children: [
                                      Icon(Icons.lock_rounded, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Locked',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
