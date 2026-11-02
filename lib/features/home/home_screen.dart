import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services/player_store.dart';
import '../../core/storage/save_data.dart';
import '../../shared/components/block_paint.dart';
import '../../shared/widgets/common.dart';
import '../adventure/levels/world_catalog.dart';
import '../rewards/engine/reward_config.dart';
import '../rewards/reward_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    final engine = ref.read(rewardEngineProvider);
    final now = ref.read(clockProvider)();
    final loginReady = engine.nextLoginDay(d, now) != null;

    // Current world = highest unlocked world.
    final currentWorld = WorldCatalog.worlds.lastWhere((w) => engine.isWorldUnlocked(d, w.id));
    final nextLevel = d.adventure.highestUnlocked(currentWorld.id);
    final today = dayKey(now);
    final missions = d.daily.missionsDate == today ? d.daily.missions : const <MissionState>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Row(
              children: [
                Pressable(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFB06BFF)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        d.playerName.isEmpty ? '?' : d.playerName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const WalletBar(),
              ],
            ),
            const SizedBox(height: 18),
            const _Logo(),
            const SizedBox(height: 18),
            if (loginReady)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Pressable(
                  onTap: () => context.go('/rewards'),
                  child: SoftCard(
                    gradient: const LinearGradient(colors: [Color(0xFFFFB84D), Color(0xFFFF7A59)]),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 34),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Your daily reward is ready!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.accent,
                          ),
                          onPressed: () => context.go('/rewards'),
                          child: const Text('Claim'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _ModeCard(
              title: 'Adventure',
              subtitle: '${currentWorld.name} · Level $nextLevel',
              icon: Icons.map_rounded,
              colors: const [Color(0xFFFF7EB3), Color(0xFFFF9A62)],
              progress: d.adventure.completedInWorld(currentWorld.id) / WorldCatalog.levelsPerWorld,
              cta: 'Play',
              onTap: () =>
                  context.push('/play/adventure/${currentWorld.id}/${nextLevel.clamp(1, WorldCatalog.levelsPerWorld)}'),
              onSecondary: () => context.go('/adventure'),
            ),
            const SizedBox(height: 14),
            _ModeCard(
              title: 'Classic',
              subtitle: 'Best score ${d.classic.overallBest}',
              icon: Icons.grid_on_rounded,
              colors: const [Color(0xFF6B4EFF), Color(0xFF4DA3FF)],
              cta: d.classicSession != null ? 'Resume' : 'Play',
              onTap: () => context.push(d.classicSession != null ? '/play/classic?resume=1' : '/play/classic'),
              onSecondary: () => context.go('/classic'),
            ),
            if (missions.isNotEmpty) ...[
              SectionTitle(
                'Daily missions',
                trailing: TextButton(onPressed: () => context.go('/rewards'), child: const Text('All')),
              ),
              SoftCard(
                child: Column(
                  children: [
                    for (final m in missions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              m.claimed ? Icons.check_circle_rounded : Icons.flag_circle_rounded,
                              color: m.claimed ? AppColors.success : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    MissionCatalog.byId(m.id).title,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  PillProgress(m.progress / MissionCatalog.byId(m.id).target, height: 7),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${m.progress}/${MissionCatalog.byId(m.id).target}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: CustomPaint(size: const Size(150, 44), painter: _LogoBlocks()),
        ),
        const SizedBox(height: 6),
        ShaderMask(
          shaderCallback: (r) =>
              const LinearGradient(colors: [AppColors.primary, Color(0xFFFF6FB5), AppColors.accent]).createShader(r),
          child: const Text(
            'BLOCK ADVENTURE',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
          ),
        ),
        const Text(
          'Puzzle · Build · Play',
          style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LogoBlocks extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const s = 26.0;
    final cells = [(0, 1, 0), (1, 1, 2), (1, 0, 5), (2, 1, 3), (3, 0, 6), (3, 1, 7), (4, 1, 1)];
    for (final (x, y, c) in cells) {
      paintCandyBlock(canvas, Rect.fromLTWH(x * (s + 4) + 2, y * (s - 8), s, s), AppColors.blocks[c]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.cta,
    required this.onTap,
    this.onSecondary,
    this.progress,
  });

  final String title, subtitle, cta;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final VoidCallback? onSecondary;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onSecondary ?? onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(right: -12, top: -12, child: Icon(icon, size: 120, color: Colors.white.withValues(alpha: 0.18))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontWeight: FontWeight.w700),
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 10),
                          PillProgress(progress!, color: Colors.white, background: Colors.white24, height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: colors.first),
                    onPressed: onTap,
                    child: Text(cta),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
