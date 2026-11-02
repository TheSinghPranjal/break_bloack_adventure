import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/player_store.dart';
import '../../core/storage/save_data.dart';
import '../shop/booster_catalog.dart';
import '../wallet/models/wallet_models.dart';
import '../wallet/wallet_ledger.dart';
import 'engine/reward_config.dart';
import 'engine/reward_engine.dart';

final rewardEngineProvider = Provider<RewardEngine>((ref) => const RewardEngine());

/// Recently granted rewards, consumed by the global reward overlay for
/// coin fly-in animations.
class RewardFeed extends Notifier<List<RewardGrant>> {
  @override
  List<RewardGrant> build() => const [];
  void push(List<RewardGrant> grants) {
    if (grants.isEmpty) return;
    state = [...state, ...grants];
  }

  void consume(RewardGrant g) => state = [
    for (final x in state)
      if (!identical(x, g)) x,
  ];
}

final rewardFeedProvider = NotifierProvider<RewardFeed, List<RewardGrant>>(RewardFeed.new);

enum BoosterPayment { inventory, coins }

class BoosterCharge {
  const BoosterCharge(this.status, this.payment);
  final TxStatus status;
  final BoosterPayment? payment;
  bool get ok => status == TxStatus.applied;
}

/// Centralized reward API. Gameplay screens report *events*; this service
/// decides rewards via [RewardEngine] and persists atomically.
class RewardService {
  RewardService(this._ref);
  final Ref _ref;

  PlayerStore get _store => _ref.read(playerStoreProvider.notifier);
  RewardEngine get _engine => _ref.read(rewardEngineProvider);
  DateTime get _now => _ref.read(clockProvider)();

  EconomyResult _commit(EconomyResult r, {bool announce = true}) {
    if (!identical(r.data, _store.data)) _store.commit(r.data);
    if (announce) _ref.read(rewardFeedProvider.notifier).push(r.grants);
    return r;
  }

  /// Makes sure today's missions exist (call on app start / resume).
  void refreshDaily() => _store.commit(_engine.ensureDailyMissions(_store.data, _now));

  EconomyResult completeAdventureLevel(AdventureCompletion c) =>
      _commit(_engine.applyAdventureCompletion(_store.data, c, _now), announce: false);

  EconomyResult finishClassicGame(ClassicSummary s) =>
      _commit(_engine.applyClassicGameFinished(_store.data, s, _now), announce: false);

  void recordClassicProgress({required int lines, required int shapes, required int combo, required int score}) {
    _store.commit(
      _engine.recordClassicProgress(_store.data, lines: lines, shapes: shapes, combo: combo, score: score, now: _now),
    );
  }

  void saveClassicSession(Map<String, dynamic>? session) {
    _store.commit(
      session == null ? _store.data.copyWith(clearClassicSession: true) : _store.data.copyWith(classicSession: session),
    );
  }

  EconomyResult claimDailyLogin() => _commit(_engine.claimDailyReward(_store.data, _now));
  EconomyResult claimMission(String id) => _commit(_engine.claimMission(_store.data, id, _now));
  EconomyResult claimAchievement(String id) => _commit(_engine.claimAchievement(_store.data, id, _now));
  EconomyResult openDailyChest() => _commit(_engine.claimChestReward(_store.data, _now, _ref.read(randomProvider)));

  /// Uses one booster: consumes an owned one first, otherwise charges coins.
  /// [useId] must be unique per use so a double tap can't charge twice.
  BoosterCharge chargeBooster(BoosterDef b, {required String useId}) {
    final d = _store.data;
    final owned = d.inventory[b.id] ?? 0;
    final LedgerResult r;
    final BoosterPayment payment;
    if (owned > 0) {
      payment = BoosterPayment.inventory;
      r = WalletLedger.apply(d, txId: 'booster:$useId', reason: 'Used ${b.name}', now: _now, boosterDeltas: {b.id: -1});
    } else {
      payment = BoosterPayment.coins;
      r = WalletLedger.spend(d, Currency.coins, b.price, txId: 'booster:$useId', reason: 'Used ${b.name}', now: _now);
    }
    if (!r.ok) return BoosterCharge(r.status, null);
    var data = r.data.copyWith(lifetime: r.data.lifetime.copyWith(boostersUsed: r.data.lifetime.boostersUsed + 1));
    data = _engine.updateMissions(data, const MissionEvent(MissionEventKind.boosterUsed), _now);
    _store.commit(data);
    return BoosterCharge(TxStatus.applied, payment);
  }

  /// Shop: buy one booster into the inventory with coins.
  TxStatus buyBooster(BoosterDef b, {required String purchaseId}) {
    final r = WalletLedger.apply(
      _store.data,
      txId: 'shop:$purchaseId',
      reason: 'Bought ${b.name}',
      now: _now,
      deltas: {Currency.coins: -b.price},
      boosterDeltas: {b.id: 1},
    );
    if (r.ok) _store.commit(r.data);
    return r.status;
  }
}

final rewardServiceProvider = Provider<RewardService>(RewardService.new);

/// Achievement ids ready to claim (for badges).
final claimableAchievementsProvider = Provider<List<String>>((ref) {
  final d = ref.watch(playerStoreProvider);
  return ref.read(rewardEngineProvider).updateAchievements(d);
});

/// Whether there's anything to collect on the Rewards tab.
final rewardsBadgeProvider = Provider<int>((ref) {
  final d = ref.watch(playerStoreProvider);
  final engine = ref.read(rewardEngineProvider);
  final now = ref.read(clockProvider)();
  var n = ref.watch(claimableAchievementsProvider).length;
  if (engine.nextLoginDay(d, now) != null) n++;
  if (engine.isChestAvailable(d, now)) n++;
  final today = dayKey(now);
  if (d.daily.missionsDate == today) {
    n += d.daily.missions.where((m) => !m.claimed && m.progress >= MissionCatalog.byId(m.id).target).length;
  }
  return n;
});
