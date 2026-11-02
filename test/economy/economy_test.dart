import 'dart:math';

import 'package:break_block_adventure/core/services/player_store.dart';
import 'package:break_block_adventure/core/storage/save_data.dart';
import 'package:break_block_adventure/core/storage/save_repository.dart';
import 'package:break_block_adventure/features/rewards/engine/reward_config.dart';
import 'package:break_block_adventure/features/rewards/engine/reward_engine.dart';
import 'package:break_block_adventure/features/rewards/reward_service.dart';
import 'package:break_block_adventure/features/shop/booster_catalog.dart';
import 'package:break_block_adventure/features/wallet/models/wallet_models.dart';
import 'package:break_block_adventure/features/wallet/wallet_ledger.dart';
import 'package:break_block_adventure/features/wallet/wallet_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 11, 2, 10);
const engine = RewardEngine();
const empty = SaveData(wallet: PlayerWallet());

void main() {
  group('WalletLedger', () {
    test('adds currency and records history', () {
      final r = WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0, deltas: {Currency.coins: 100});
      expect(r.ok, isTrue);
      expect(r.data.wallet.coins, 100);
      expect(r.data.history.single.balanceAfter, 100);
      expect(r.data.lifetime.coinsEarned, 100);
    });
    test('spends currency', () {
      final d = WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0, deltas: {Currency.coins: 10}).data;
      final r = WalletLedger.spend(d, Currency.coins, 4, txId: 'b', reason: 'y', now: t0);
      expect(r.data.wallet.coins, 6);
    });
    test('insufficient balance is rejected and nothing changes', () {
      final r = WalletLedger.spend(empty, Currency.coins, 1, txId: 'b', reason: 'y', now: t0);
      expect(r.status, TxStatus.insufficientFunds);
      expect(identical(r.data, empty), isTrue);
    });
    test('coin + booster debit is all-or-nothing', () {
      final d = WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0, deltas: {Currency.coins: 100}).data;
      final r = WalletLedger.apply(
        d,
        txId: 'b',
        reason: 'y',
        now: t0,
        deltas: {Currency.coins: -50},
        boosterDeltas: {'hammer': -1},
      );
      expect(r.status, TxStatus.insufficientFunds);
      expect(r.data.wallet.coins, 100);
    });
    test('duplicate transaction id is ignored', () {
      final d = WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0, deltas: {Currency.coins: 100}).data;
      final r = WalletLedger.apply(d, txId: 'a', reason: 'x', now: t0, deltas: {Currency.coins: 100});
      expect(r.status, TxStatus.duplicate);
      expect(r.data.wallet.coins, 100);
    });
    test('zero/empty and negative-spend amounts are invalid', () {
      expect(WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0).status, TxStatus.invalid);
      expect(WalletLedger.spend(empty, Currency.coins, -5, txId: 'a', reason: 'x', now: t0).status, TxStatus.invalid);
    });
    test('booster inventory can never go negative', () {
      final r = WalletLedger.apply(empty, txId: 'a', reason: 'x', now: t0, boosterDeltas: {'hammer': -1});
      expect(r.status, TxStatus.insufficientFunds);
    });
  });

  group('Adventure rewards', () {
    AdventureCompletion c(int level, int stars, [String attempt = 'a1']) =>
        AdventureCompletion(worldId: 1, levelId: level, stars: stars, attemptId: attempt, levelsPerWorld: 10);

    test('first completion: coins + level stars; replay gives only replay coins', () {
      var r = engine.applyAdventureCompletion(empty, c(1, 2), t0);
      expect(r.data.wallet.coins, 50);
      expect(r.data.adventure.starsFor(1, 1), 2);
      r = engine.applyAdventureCompletion(r.data, c(1, 2, 'a2'), t0);
      expect(r.data.wallet.coins, 60);
      expect(r.data.adventure.totalStars, 2);
    });
    test('first 3-star bonus once, and best stars kept', () {
      var r = engine.applyAdventureCompletion(empty, c(1, 1), t0);
      r = engine.applyAdventureCompletion(r.data, c(1, 3, 'a2'), t0);
      expect(r.data.adventure.starsFor(1, 1), 3);
      expect(r.data.wallet.coins, 50 + 10 + 25);
      r = engine.applyAdventureCompletion(r.data, c(1, 3, 'a3'), t0);
      expect(r.data.wallet.coins, 50 + 10 + 25 + 10);
    });
    test('every 5 levels milestone and world completion paid once', () {
      var d = empty;
      for (var i = 1; i <= 10; i++) {
        d = engine.applyAdventureCompletion(d, c(i, 1), t0).data;
      }
      // 10 levels x 50 + 2 milestones x 150 + world 1500 + first-world 2500
      expect(d.wallet.coins, 500 + 300 + 1500 + 2500);
      expect(d.lifetime.worldsCompleted, 1);
      final again = engine.applyAdventureCompletion(d, c(10, 1, 'z'), t0).data;
      expect(again.wallet.coins, d.wallet.coins + 10);
      expect(again.lifetime.worldsCompleted, 1);
    });
    test('the same attempt reported twice pays once', () {
      final once = engine.applyAdventureCompletion(empty, c(1, 1), t0).data;
      final twice = engine.applyAdventureCompletion(once, c(1, 1), t0).data;
      expect(twice.wallet.coins, once.wallet.coins + 10); // replay with same attempt
      final thrice = engine.applyAdventureCompletion(twice, c(1, 1), t0).data;
      expect(thrice.wallet.coins, twice.wallet.coins);
    });
    test('world gate requires completion and stars', () {
      expect(engine.isWorldUnlocked(empty, 1), isTrue);
      expect(engine.isWorldUnlocked(empty, 2), isFalse);
    });
  });

  group('Classic rewards', () {
    ClassicSummary s(String id, int score, {int lines = 0, int combo = 0}) => ClassicSummary(
      sessionId: id,
      boardSize: 10,
      score: score,
      linesCleared: lines,
      maxCombo: combo,
      shapesPlaced: 10,
    );
    test('score, line and combo coin formula', () {
      expect(engine.calculateClassicReward(s('x', 250, lines: 12, combo: 4)).coins, 2 * 5 + 2 * 10 + 1 * 25 + 10);
      expect(engine.calculateComboBonus(2), 0);
      expect(engine.calculateComboBonus(100), 50);
    });
    test('game rewards and stats applied once per session', () {
      var r = engine.applyClassicGameFinished(empty, s('g1', 600, lines: 5), t0);
      // 30 (score) + 10 (lines) + 50 (daily 500 milestone)
      expect(r.data.wallet.coins, 90);
      expect(r.data.classic.gamesPlayed, 1);
      expect(r.data.classic.best(10), 600);
      final dup = engine.applyClassicGameFinished(r.data, s('g1', 600, lines: 5), t0);
      expect(dup.status, TxStatus.duplicate);
      expect(dup.data.classic.gamesPlayed, 1);
      // Another game the same day doesn't repay the daily milestone.
      r = engine.applyClassicGameFinished(r.data, s('g2', 600), t0);
      expect(r.data.wallet.coins, 90 + 30);
    });
    test('weekly challenge paid once per week', () {
      bool paid(SaveData d) => d.history.any((t) => t.reason.startsWith('Weekly challenge'));
      int weekly(SaveData d) => d.history.where((t) => t.reason.startsWith('Weekly challenge')).length;
      var r = engine.applyClassicGameFinished(empty, s('g1', 5000), t0);
      expect(paid(r.data), isTrue);
      r = engine.applyClassicGameFinished(r.data, s('g2', 6000), t0.add(const Duration(days: 1)));
      expect(weekly(r.data), 1);
    });
  });

  group('Daily login', () {
    test('claims day 1, cannot claim twice the same day', () {
      final r = engine.claimDailyReward(empty, t0);
      expect(r.extra, 1);
      expect(r.data.wallet.coins, 50);
      final again = engine.claimDailyReward(r.data, t0.add(const Duration(hours: 5)));
      expect(again.status, TxStatus.duplicate);
      expect(again.data.wallet.coins, 50);
    });
    test('consecutive days advance and cycle after day 7', () {
      var d = empty;
      for (var i = 0; i < 8; i++) {
        d = engine.claimDailyReward(d, t0.add(Duration(days: i))).data;
      }
      expect(d.daily.loginDay, 1);
      expect(d.daily.currentStreak, 8);
      expect(d.wallet.coins, 50 + 75 + 100 + 125 + 150 + 200 + 750 + 50);
    });
    test('missing a day resets to day 1', () {
      var d = engine.claimDailyReward(empty, t0).data;
      d = engine.claimDailyReward(d, t0.add(const Duration(days: 1))).data;
      final r = engine.claimDailyReward(d, t0.add(const Duration(days: 3)));
      expect(r.extra, 1);
      expect(r.data.daily.currentStreak, 1);
      expect(r.data.daily.bestStreak, 2);
    });
  });

  group('Missions', () {
    test('three daily missions, progress updates, claim once', () {
      var d = engine.ensureDailyMissions(empty, t0);
      expect(d.daily.missions.length, 3);
      final m = d.daily.missions.first;
      final def = MissionCatalog.byId(m.id);
      expect(engine.claimMission(d, m.id, t0).status, TxStatus.invalid); // not done
      for (var i = 0; i < def.target; i++) {
        d = engine.updateMissions(d, MissionEvent(def.kind, def.isMax ? def.target : 1), t0);
      }
      expect(d.daily.missions.first.progress, def.target);
      final r = engine.claimMission(d, m.id, t0);
      expect(r.ok, isTrue);
      expect(r.data.daily.missionsClaimedTotal, 1);
      expect(engine.claimMission(r.data, m.id, t0).status, TxStatus.duplicate);
    });
    test('missions reset on a new day', () {
      final d = engine.ensureDailyMissions(empty, t0);
      final next = engine.ensureDailyMissions(d, t0.add(const Duration(days: 1)));
      expect(next.daily.missionsDate, isNot(d.daily.missionsDate));
    });
  });

  group('Achievements & chest', () {
    test('achievement claim requires progress and pays once', () {
      expect(engine.claimAchievement(empty, 'first_victory', t0).status, TxStatus.invalid);
      final d = engine
          .applyAdventureCompletion(
            empty,
            const AdventureCompletion(worldId: 1, levelId: 1, stars: 1, attemptId: 'a'),
            t0,
          )
          .data;
      expect(engine.updateAchievements(d), contains('first_victory'));
      final r = engine.claimAchievement(d, 'first_victory', t0);
      expect(r.data.wallet.coins, d.wallet.coins + 50);
      expect(engine.claimAchievement(r.data, 'first_victory', t0).status, TxStatus.duplicate);
      expect(engine.updateAchievements(r.data), isNot(contains('first_victory')));
    });
    test('chest once per day with published odds and history', () {
      expect(ChestTable.outcomes.fold<double>(0, (a, o) => a + ChestTable.chance(o)), closeTo(1, 1e-9));
      final r = engine.claimChestReward(empty, t0, Random(1));
      expect(r.ok, isTrue);
      expect(r.data.daily.chestHistory.length, 1);
      expect(engine.claimChestReward(r.data, t0, Random(2)).status, TxStatus.duplicate);
      expect(engine.claimChestReward(r.data, t0.add(const Duration(days: 1)), Random(2)).ok, isTrue);
    });
  });

  group('Services + persistence', () {
    ProviderContainer make(InMemorySaveRepository repo, SaveData initial, DateTime now) => ProviderContainer(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repo),
        initialSaveProvider.overrideWithValue(initial),
        clockProvider.overrideWithValue(() => now),
      ],
    );

    test('progress survives an app restart and claims are not repeated', () async {
      final repo = InMemorySaveRepository();
      var c = make(repo, await loadSaveData(repo), t0);
      final rewards = c.read(rewardServiceProvider);
      expect(rewards.claimDailyLogin().ok, isTrue);
      rewards.completeAdventureLevel(const AdventureCompletion(worldId: 1, levelId: 1, stars: 3, attemptId: 'x'));
      final coins = c.read(walletProvider).coins;
      await c.read(playerStoreProvider.notifier).flush();
      c.dispose();

      // "Restart" the app.
      c = make(repo, await loadSaveData(repo), t0.add(const Duration(hours: 2)));
      expect(c.read(walletProvider).coins, coins);
      expect(c.read(playerStoreProvider).adventure.starsFor(1, 1), 3);
      expect(c.read(rewardServiceProvider).claimDailyLogin().status, TxStatus.duplicate);
      c
          .read(rewardServiceProvider)
          .completeAdventureLevel(const AdventureCompletion(worldId: 1, levelId: 1, stars: 3, attemptId: 'x'));
      // Already-completed level with same attempt -> only one replay payout possible.
      final afterReplay = c.read(walletProvider).coins;
      c
          .read(rewardServiceProvider)
          .completeAdventureLevel(const AdventureCompletion(worldId: 1, levelId: 1, stars: 3, attemptId: 'x'));
      expect(c.read(walletProvider).coins, afterReplay);
      c.dispose();
    });

    test('wallet service API: add, spend, insufficient, history', () {
      final c = make(InMemorySaveRepository(), empty, t0);
      final w = c.read(walletServiceProvider);
      expect(w.addCoins(100, txId: '1', reason: 'r'), TxStatus.applied);
      expect(w.addCoins(100, txId: '1', reason: 'r'), TxStatus.duplicate);
      expect(w.spendCoins(150, txId: '2', reason: 'r'), TxStatus.insufficientFunds);
      expect(w.spendCoins(40, txId: '3', reason: 'r'), TxStatus.applied);
      expect(w.getBalance().coins, 60);
      expect(w.canAfford(Currency.coins, 61), isFalse);
      expect(w.getTransactionHistory().first.id, '3');
      c.dispose();
    });

    test('boosters use inventory first, then coins; insufficient blocks use', () {
      final c = make(
        InMemorySaveRepository(),
        SaveData(
          wallet: PlayerWallet(coins: Boosters.hammer.price),
          inventory: const {'hammer': 1},
        ),
        t0,
      );
      final rs = c.read(rewardServiceProvider);
      expect(rs.chargeBooster(Boosters.hammer, useId: 'u1').payment, BoosterPayment.inventory);
      expect(rs.chargeBooster(Boosters.hammer, useId: 'u1').status, TxStatus.duplicate);
      expect(rs.chargeBooster(Boosters.hammer, useId: 'u2').payment, BoosterPayment.coins);
      expect(c.read(walletProvider).coins, 0);
      expect(rs.chargeBooster(Boosters.hammer, useId: 'u3').status, TxStatus.insufficientFunds);
      expect(c.read(playerStoreProvider).lifetime.boostersUsed, 2);
      c.dispose();
    });

    test('v1 saves migrate: park dropped, gems and tickets become coins', () async {
      final repo = InMemorySaveRepository({
        'version': 1,
        'wallet': {'coins': 300, 'gems': 4, 'stars': 9, 'tickets': 2},
        'park': {
          'areas': ['entrance'],
        },
        'history': [
          {'id': 'a', 'c': 'coins', 'a': 300, 'r': 'x', 't': 0, 'b': 300},
          {'id': 'b', 'c': 'gems', 'a': 4, 'r': 'y', 't': 0, 'b': 4},
        ],
      });
      final d = await loadSaveData(repo);
      expect(d.version, SaveData.currentVersion);
      expect(d.wallet.coins, 300 + 4 * SaveData.coinsPerGem + 2 * SaveData.coinsPerTicket);
      expect(d.history.map((t) => t.id), ['a']);
      expect(d.toJson().containsKey('park'), isFalse);
    });

    test('corrupt save falls back to a fresh profile', () async {
      final repo = InMemorySaveRepository({'version': 99});
      final d = await loadSaveData(repo);
      expect(d.wallet.coins, const SaveData().wallet.coins);
      expect(repo.backedUp, {'version': 99});
    });
  });
}
