import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/services/player_store.dart';
import '../../../shared/widgets/common.dart';
import '../levels/level_repository.dart';
import '../levels/world_catalog.dart';

class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key, required this.worldId});
  final int worldId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = WorldCatalog.byId(worldId);
    final theme = WorldTheme.of(world.themeKey);
    final progress = ref.watch(playerStoreProvider.select((d) => d.adventure));
    final levels = ref.watch(worldLevelsProvider(worldId));
    final next = progress.highestUnlocked(worldId);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.top, theme.bottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/adventure'),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        world.name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: Colors.white),
                    Text(
                      ' ${progress.starsInWorld(worldId)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: levels.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  error: (e, _) => Center(
                    child: Text('Could not load levels: $e', style: const TextStyle(color: Colors.white)),
                  ),
                  data: (list) => GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 84,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i].levelId;
                      final stars = progress.starsFor(worldId, n);
                      final unlocked = n <= next;
                      final current = n == next;
                      return Pressable(
                        onTap: unlocked ? () => context.push('/play/adventure/$worldId/$n') : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: current ? Border.all(color: AppColors.accent, width: 3) : null,
                            boxShadow: unlocked
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (unlocked)
                                Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: current ? AppColors.accent : AppColors.ink,
                                  ),
                                )
                              else
                                const Icon(Icons.lock_rounded, color: Colors.white),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var s = 1; s <= 3; s++)
                                    Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: s <= stars ? AppColors.star : Colors.black.withValues(alpha: 0.1),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
