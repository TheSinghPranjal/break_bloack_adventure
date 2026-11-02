import 'dart:convert';
import 'dart:io';

import 'package:break_block_adventure/app/app.dart';
import 'package:break_block_adventure/core/services/player_store.dart';
import 'package:break_block_adventure/core/storage/save_data.dart';
import 'package:break_block_adventure/core/storage/save_repository.dart';
import 'package:break_block_adventure/features/adventure/controllers/adventure_controller.dart';
import 'package:break_block_adventure/features/adventure/engine/level_validator.dart';
import 'package:break_block_adventure/features/adventure/levels/level_repository.dart';
import 'package:break_block_adventure/features/adventure/models/puzzle_models.dart';
import 'package:break_block_adventure/features/classic/controllers/classic_controller.dart';
import 'package:break_block_adventure/features/classic/models/block_shape.dart';
import 'package:break_block_adventure/features/classic/widgets/classic_board_view.dart';
import 'package:break_block_adventure/features/rewards/reward_service.dart';
import 'package:break_block_adventure/features/shop/booster_catalog.dart';
import 'package:break_block_adventure/features/wallet/wallet_ledger.dart';
import 'package:break_block_adventure/features/wallet/models/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PuzzleLevel loadLevel(int world, int level) {
  final list = jsonDecode(File('assets/levels/world_$world.json').readAsStringSync()) as List;
  return PuzzleLevel.fromJson((list[level - 1] as Map).cast<String, dynamic>());
}

Future<ProviderContainer> pumpApp(WidgetTester tester, InMemorySaveRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final save = await loadSaveData(repo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repo),
        initialSaveProvider.overrideWithValue(save),
        // rootBundle decodes big assets on a background isolate, which can't
        // finish under the test's fake clock; read the same JSON from disk.
        worldLevelsProvider.overrideWith(
          (ref, w) async => [
            for (final j in jsonDecode(File('assets/levels/world_$w.json').readAsStringSync()) as List)
              PuzzleLevel.fromJson((j as Map).cast<String, dynamic>()),
          ],
        ),
      ],
      child: const BlockAdventureApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(BlockAdventureApp)));
}

void main() {
  testWidgets('Level packs are bundled as assets', (tester) async {
    final raw = await tester.runAsync(() => rootBundle.loadString('assets/levels/world_1.json'));
    expect((jsonDecode(raw!) as List).length, 100);
  });

  testWidgets('Home shows the three activities and the shared wallet', (tester) async {
    await pumpApp(tester, InMemorySaveRepository());
    expect(find.text('BLOCK ADVENTURE'), findsOneWidget);
    expect(find.text('Adventure'), findsWidgets);
    expect(find.text('Classic'), findsWidgets);
    expect(find.text('1,200'), findsOneWidget); // starting coins
    expect(find.text('My Park'), findsNothing);
    expect(find.text('Park'), findsNothing);
  });

  testWidgets('Complete an Adventure level with real drag gestures and collect rewards', (tester) async {
    final repo = InMemorySaveRepository();
    final c = await pumpApp(tester, repo);
    final coinsBefore = c.read(playerStoreProvider).wallet.coins;

    await tester.tap(find.text('Play').first);
    await tester.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);

    final level = loadLevel(1, 1);
    final solution = const LevelValidator().validate(level).solution!;
    for (final m in solution) {
      final session = c.read(adventureControllerProvider)!;
      final block = session.state.blockById(m.blockId)!;
      final blockFinder = find.byKey(ValueKey(m.blockId));
      final cell = tester.getSize(blockFinder).width / block.width;
      // Drag past the touch slop so the gesture is recognised.
      final slop = 20.0;
      final offset = Offset(m.direction.dc * (m.distance * cell + slop), m.direction.dr * (m.distance * cell + slop));
      final before = c.read(adventureControllerProvider)!.state.movesUsed;
      await tester.timedDrag(blockFinder, offset, const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(c.read(adventureControllerProvider)!.state.movesUsed, before + 1, reason: 'drag for $m was not applied');
    }

    final s = c.read(adventureControllerProvider)!;
    expect(s.state.status, PuzzleStatus.won);
    expect(find.text('Level Complete!'), findsOneWidget);
    final d = c.read(playerStoreProvider);
    expect(d.adventure.isCompleted(1, 1), isTrue);
    expect(d.wallet.coins, greaterThanOrEqualTo(coinsBefore + 50));
    expect(d.adventure.starsFor(1, 1), s.stars);
    // Leave the level so the confetti animation can finish.
    await tester.tap(find.text('Next Level'));
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('Play a Classic game to the end and receive coins once', (tester) async {
    final repo = InMemorySaveRepository();
    final c = await pumpApp(tester, repo);
    await tester.tap(find.text('Classic').last); // bottom nav
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();
    expect(find.byType(DragTarget<int>), findsOneWidget);

    final ctrl = c.read(classicControllerProvider.notifier);
    // Place shapes greedily until the game ends (or a cap).
    for (var turn = 0; turn < 400; turn++) {
      final s = c.read(classicControllerProvider)!;
      if (s.game.isGameOver) break;
      var placed = false;
      for (var i = 0; i < 3 && !placed; i++) {
        final shape = s.game.tray[i];
        if (shape == null) continue;
        for (var r = 0; r < s.boardSize && !placed; r++) {
          for (var col = 0; col < s.boardSize && !placed; col++) {
            placed = ctrl.place(i, GridPoint(r, col));
          }
        }
      }
      expect(placed, isTrue);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    final game = c.read(classicControllerProvider)!.game;
    if (game.isGameOver) {
      expect(find.text('No room left!'), findsOneWidget);
      await tester.tap(find.text('See results'));
    } else {
      ctrl.finish();
    }
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final d = c.read(playerStoreProvider);
    expect(d.classic.gamesPlayed, 1);
    expect(d.classic.best(10), game.score);
    expect(d.classicSession, isNull);
    final coins = d.wallet.coins;
    expect(coins, greaterThan(200));
    // Finishing again must not pay twice.
    ctrl.finish();
    expect(c.read(playerStoreProvider).wallet.coins, coins);
  });

  testWidgets('Classic drag & drop places a shape exactly where dropped; invalid drops return to tray', (tester) async {
    final c = await pumpApp(tester, InMemorySaveRepository());
    await tester.tap(find.text('Classic').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New game'));
    await tester.pumpAndSettle();

    final board = find.byType(ClassicBoardView);
    final boardTopLeft = tester.getTopLeft(board);
    final s0 = c.read(classicControllerProvider)!;
    final cell = tester.getSize(board).width / s0.boardSize;
    final shape = s0.game.tray[0]!;

    Future<void> dragShapeTo(int row, int col) async {
      // Pointer sits below the feedback (see dragAnchorStrategy).
      final fw = shape.width * cell, fh = shape.height * cell;
      final target = boardTopLeft + Offset(col * cell + fw / 2, row * cell + fh + cell * 1.4);
      final g = await tester.startGesture(tester.getCenter(find.byType(Draggable<int>).first));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(tester.getCenter(find.byType(Draggable<int>).first), target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    // Invalid: off the bottom-right edge -> nothing placed, shape still in tray.
    await dragShapeTo(s0.boardSize - 1, s0.boardSize - 1 + (shape.width > 1 || shape.height > 1 ? 0 : 1));
    var s = c.read(classicControllerProvider)!;
    if (shape.width > 1 || shape.height > 1) {
      expect(s.game.board.filledCount, 0);
      expect(s.game.tray[0], isNotNull);
    }

    await dragShapeTo(2, 3);
    s = c.read(classicControllerProvider)!;
    expect(s.game.tray[0], isNull);
    for (final p in shape.cells) {
      expect(s.game.board.isEmpty(2 + p.row, 3 + p.col), isFalse, reason: 'cell ${2 + p.row},${3 + p.col}');
    }
    expect(s.game.board.filledCount, shape.size);
  });

  testWidgets('Buy a booster with coins and survive an app restart', (tester) async {
    final repo = InMemorySaveRepository(const SaveData(wallet: PlayerWallet(coins: 1000)).toJson());
    var c = await pumpApp(tester, repo);
    final rewards = c.read(rewardServiceProvider);
    expect(rewards.buyBooster(Boosters.hammer, purchaseId: 'p1'), TxStatus.applied);
    expect(rewards.buyBooster(Boosters.hammer, purchaseId: 'p1'), TxStatus.duplicate);
    expect(c.read(playerStoreProvider).wallet.coins, 1000 - Boosters.hammer.price);
    await c.read(playerStoreProvider.notifier).flush();

    // Restart: new widget tree from the persisted save.
    await tester.pumpWidget(const SizedBox());
    c = await pumpApp(tester, repo);
    final d = c.read(playerStoreProvider);
    expect(d.wallet.coins, 1000 - Boosters.hammer.price);
    expect(d.inventory['hammer'], 1);
  });
}
