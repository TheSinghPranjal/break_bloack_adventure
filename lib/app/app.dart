import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/rewards/reward_service.dart';
import '../shared/widgets/reward_fx.dart';
import 'router.dart';
import 'theme.dart';

class BlockAdventureApp extends ConsumerStatefulWidget {
  const BlockAdventureApp({super.key});
  @override
  ConsumerState<BlockAdventureApp> createState() => _BlockAdventureAppState();
}

class _BlockAdventureAppState extends ConsumerState<BlockAdventureApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(rewardServiceProvider).refreshDaily());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // New day while backgrounded -> refresh missions.
    if (state == AppLifecycleState.resumed) ref.read(rewardServiceProvider).refreshDaily();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Block Adventure',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => RewardOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
