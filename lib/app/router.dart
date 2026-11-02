import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/adventure/screens/adventure_play_screen.dart';
import '../features/adventure/screens/level_select_screen.dart';
import '../features/adventure/screens/world_select_screen.dart';
import '../features/classic/screens/classic_home_screen.dart';
import '../features/classic/screens/classic_play_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rewards/reward_service.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/shop/shop_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/adventure',
                builder: (_, _) => const WorldSelectScreen(),
                routes: [
                  GoRoute(
                    path: 'world/:w',
                    builder: (_, s) => LevelSelectScreen(worldId: int.parse(s.pathParameters['w']!)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/classic', builder: (_, _) => const ClassicHomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/rewards', builder: (_, _) => const RewardsScreen())],
          ),
        ],
      ),
      // Immersive gameplay: outside the shell, so no bottom navigation.
      GoRoute(
        path: '/play/adventure/:w/:l',
        builder: (_, s) => AdventurePlayScreen(
          key: ValueKey('${s.pathParameters['w']}-${s.pathParameters['l']}'),
          worldId: int.parse(s.pathParameters['w']!),
          levelId: int.parse(s.pathParameters['l']!),
        ),
      ),
      GoRoute(
        path: '/play/classic',
        builder: (_, s) => ClassicPlayScreen(resume: s.uri.queryParameters['resume'] == '1'),
      ),
      GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    ],
  );
});

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(rewardsBadgeProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Adventure',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_on_outlined),
            selectedIcon: Icon(Icons.grid_on_rounded),
            label: 'Classic',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: const Icon(Icons.card_giftcard_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: const Icon(Icons.card_giftcard_rounded),
            ),
            label: 'Rewards',
          ),
        ],
      ),
    );
  }
}
