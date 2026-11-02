import 'dart:math';

import '../../../core/storage/save_data.dart';
import '../../wallet/models/wallet_models.dart';
import '../../wallet/wallet_ledger.dart';
import 'reward_config.dart';

/// A reward that was actually credited (used by the UI for animations).
class RewardGrant {
  const RewardGrant(this.txId, this.reason, this.reward);
  final String txId;
  final String reason;
  final Reward reward;
}

class EconomyResult {
  const EconomyResult(this.data, {this.grants = const [], this.status = TxStatus.applied, this.extra});
  final SaveData data;
  final List<RewardGrant> grants;
  final TxStatus status;

  /// Optional payload (e.g. chest outcome, login day).
  final Object? extra;

  bool get ok => status == TxStatus.applied;
  Reward get total => grants.fold(Reward.none, (a, g) => a + g.reward);
}

class MissionEvent {
  const MissionEvent(this.kind, [this.value = 1]);
  final MissionEventKind kind;
  final int value;
}

class AdventureCompletion {
  const AdventureCompletion({
    required this.worldId,
    required this.levelId,
    required this.stars,
    required this.attemptId,
    this.baseCoins = 50,
    this.levelsPerWorld = 100,
  });
  final int worldId;
  final int levelId;
  final int stars;

  /// Unique per play-through; makes replay rewards idempotent too.
  final String attemptId;
  final int baseCoins;
  final int levelsPerWorld;
  String get key => '$worldId-$levelId';
}

class ClassicSummary {
  const ClassicSummary({
    required this.sessionId,
    required this.boardSize,
    required this.score,
    required this.linesCleared,
    required this.maxCombo,
    required this.shapesPlaced,
  });
  final String sessionId;
  final int boardSize;
  final int score;
  final int linesCleared;
  final int maxCombo;
  final int shapesPlaced;
}

/// Pure reward rules. All methods take a [SaveData] and return a new one;
/// grants go through [WalletLedger] so they are validated and idempotent.
class RewardEngine {
  const RewardEngine([this.config = const RewardConfig()]);
  final RewardConfig config;

  // --------------------------------------------------------------- helpers

  EconomyResult _grantAll(SaveData d, List<RewardGrant> wanted, DateTime now) {
    var data = d;
    final applied = <RewardGrant>[];
    for (final g in wanted) {
      if (g.reward.isEmpty) continue;
      final r = WalletLedger.grant(data, g.reward, txId: g.txId, reason: g.reason, now: now);
      if (r.ok) {
        data = r.data;
        applied.add(g);
      }
    }
    return EconomyResult(data, grants: applied);
  }

  // ------------------------------------------------------------- adventure

  int calculateComboBonus(int maxCombo) =>
      maxCombo >= 3 ? min(config.comboCoinsCap, (maxCombo - 2) * config.comboCoinsPerStep) : 0;

  /// Rewards for completing a level. Milestones are keyed by level, so they
  /// can only ever be paid once.
  List<RewardGrant> calculateAdventureReward(SaveData d, AdventureCompletion c) {
    final prevStars = d.adventure.starsFor(c.worldId, c.levelId);
    final first = prevStars == 0;
    final grants = <RewardGrant>[];
    if (first) {
      grants.add(RewardGrant('adv:${c.key}', 'Level ${c.key} complete', Reward(coins: c.baseCoins)));
    } else {
      grants.add(
        RewardGrant('adv_replay:${c.key}:${c.attemptId}', 'Level ${c.key} replay', Reward(coins: config.replayCoins)),
      );
    }
    if (c.stars >= 3 && prevStars < 3) {
      grants.add(RewardGrant('adv3:${c.key}', 'First 3-star on ${c.key}', Reward(coins: config.firstThreeStarBonus)));
    }
    if (first && c.levelId % config.everyNLevels == 0) {
      grants.add(RewardGrant('adv5:${c.key}', 'Milestone: level ${c.levelId}', config.everyNLevelsReward));
    }
    final completedAfter = d.adventure.completedInWorld(c.worldId) + (first ? 1 : 0);
    if (first && completedAfter >= c.levelsPerWorld) {
      final extraCoins = c.worldId == 1 ? config.firstWorldExtraCoins : 0;
      grants.add(
        RewardGrant(
          'world:${c.worldId}',
          'World ${c.worldId} complete!',
          config.worldCompleteReward + Reward(coins: extraCoins),
        ),
      );
    }
    return grants;
  }

  EconomyResult applyAdventureCompletion(SaveData d, AdventureCompletion c, DateTime now) {
    if (c.stars < 1 || c.stars > 3) return EconomyResult(d, status: TxStatus.invalid);
    final grants = calculateAdventureReward(d, c);
    final prev = d.adventure.starsFor(c.worldId, c.levelId);
    final first = prev == 0;
    final worldDone = grants.any((g) => g.txId.startsWith('world:'));
    var data = d.copyWith(
      adventure: d.adventure.copyWith(
        stars: {...d.adventure.stars, c.key: max(prev, c.stars)},
        replays: d.adventure.replays + (first ? 0 : 1),
      ),
      lifetime: worldDone ? d.lifetime.copyWith(worldsCompleted: d.lifetime.worldsCompleted + 1) : null,
    );
    final res = _grantAll(data, grants, now);
    data = res.data;
    // Mission progress.
    data = updateMissions(data, const MissionEvent(MissionEventKind.adventureLevel), now);
    data = updateMissions(data, const MissionEvent(MissionEventKind.gameFinished), now);
    if (c.stars >= 3) {
      data = updateMissions(data, const MissionEvent(MissionEventKind.adventureThreeStar), now);
    }
    return EconomyResult(data, grants: res.grants);
  }

  /// World N (>1) is open once world N-1 is fully completed and enough
  /// total stars have been collected.
  bool isWorldUnlocked(SaveData d, int worldId, {int levelsPerWorld = 100}) {
    if (worldId <= 1) return true;
    final prevDone = d.adventure.completedInWorld(worldId - 1) >= levelsPerWorld;
    return prevDone && d.adventure.totalStars >= (worldId - 1) * config.starsPerWorldGate;
  }

  // --------------------------------------------------------------- classic

  Reward calculateClassicReward(ClassicSummary s) {
    final coins =
        (s.score ~/ 100) * config.coinsPer100Score +
        (s.linesCleared ~/ 5) * config.coinsPer5Lines +
        (s.linesCleared ~/ 10) * config.coinsPer10Lines +
        calculateComboBonus(s.maxCombo);
    return Reward(coins: coins);
  }

  EconomyResult applyClassicGameFinished(SaveData d, ClassicSummary s, DateTime now) {
    final gameTx = 'classic:${s.sessionId}';
    if (d.hasProcessed(gameTx) || d.hasProcessed('$gameTx:stats')) {
      return EconomyResult(d, status: TxStatus.duplicate);
    }
    final today = dayKey(now);
    final week = weekKey(now);
    final st = d.classic;
    final dailyBest = st.dailyBestDate == today ? max(st.dailyBest, s.score) : s.score;
    final weeklyBest = st.weeklyBestKey == week ? max(st.weeklyBest, s.score) : s.score;
    var data = d.copyWith(
      classic: st.copyWith(
        bestScores: {...st.bestScores, '${s.boardSize}': max(st.best(s.boardSize), s.score)},
        gamesPlayed: st.gamesPlayed + 1,
        // Lines/blocks are counted live via [recordClassicProgress].
        highestCombo: max(st.highestCombo, s.maxCombo),
        dailyBestDate: today,
        dailyBest: dailyBest,
        weeklyBestKey: week,
        weeklyBest: weeklyBest,
      ),
      processedTxIds: [...d.processedTxIds, '$gameTx:stats'],
      clearClassicSession: true,
    );
    final grants = <RewardGrant>[
      RewardGrant(gameTx, 'Classic game: ${s.score} pts', calculateClassicReward(s)),
      for (final m in config.dailyScoreMilestones.entries)
        if (dailyBest >= m.key)
          RewardGrant('classic_daily:$today:${m.key}', 'Daily challenge: ${m.key} pts', Reward(coins: m.value)),
      if (weeklyBest >= config.weeklyScoreTarget)
        RewardGrant('classic_weekly:$week', 'Weekly challenge: ${config.weeklyScoreTarget} pts', config.weeklyReward),
    ];
    final res = _grantAll(data, grants, now);
    data = updateMissions(res.data, MissionEvent(MissionEventKind.classicScore, s.score), now);
    data = updateMissions(data, const MissionEvent(MissionEventKind.gameFinished), now);
    return EconomyResult(data, grants: res.grants);
  }

  /// Live per-placement stats so missions update immediately.
  SaveData recordClassicProgress(
    SaveData d, {
    required int lines,
    required int shapes,
    required int combo,
    required int score,
    required DateTime now,
  }) {
    var data = d.copyWith(
      classic: d.classic.copyWith(
        totalLines: d.classic.totalLines + lines,
        totalBlocksPlaced: d.classic.totalBlocksPlaced + shapes,
        highestCombo: max(d.classic.highestCombo, combo),
      ),
    );
    if (lines > 0) data = updateMissions(data, MissionEvent(MissionEventKind.linesCleared, lines), now);
    if (lines >= 2) data = updateMissions(data, const MissionEvent(MissionEventKind.multiLineClear), now);
    data = updateMissions(data, MissionEvent(MissionEventKind.classicScore, score), now);
    return data;
  }

  // --------------------------------------------------------------- missions

  /// Picks today's three missions deterministically from the date.
  SaveData ensureDailyMissions(SaveData d, DateTime now) {
    final today = dayKey(now);
    if (d.daily.missionsDate == today && d.daily.missions.isNotEmpty) return d;
    final rng = Random(today.hashCode);
    final pool = List.of(MissionCatalog.all)..shuffle(rng);
    return d.copyWith(
      daily: d.daily.copyWith(
        missionsDate: today,
        missions: [for (final m in pool.take(3)) MissionState(id: m.id)],
      ),
    );
  }

  SaveData updateMissions(SaveData d, MissionEvent e, DateTime now) {
    final data = ensureDailyMissions(d, now);
    var changed = false;
    final missions = [
      for (final m in data.daily.missions)
        () {
          final def = MissionCatalog.byId(m.id);
          if (def.kind != e.kind || m.claimed) return m;
          final p = def.isMax ? max(m.progress, e.value) : m.progress + e.value;
          final capped = min(p, def.target);
          if (capped == m.progress) return m;
          changed = true;
          return m.copyWith(progress: capped);
        }(),
    ];
    return changed ? data.copyWith(daily: data.daily.copyWith(missions: missions)) : data;
  }

  EconomyResult claimMission(SaveData d, String missionId, DateTime now) {
    final data = ensureDailyMissions(d, now);
    final idx = data.daily.missions.indexWhere((m) => m.id == missionId);
    if (idx < 0) return EconomyResult(d, status: TxStatus.invalid);
    final m = data.daily.missions[idx];
    final def = MissionCatalog.byId(missionId);
    if (m.claimed) return EconomyResult(d, status: TxStatus.duplicate);
    if (m.progress < def.target) return EconomyResult(d, status: TxStatus.invalid);
    final tx = 'mission:${data.daily.missionsDate}:$missionId';
    final r = WalletLedger.grant(data, def.reward, txId: tx, reason: 'Mission: ${def.title}', now: now);
    if (!r.ok) return EconomyResult(d, status: r.status);
    final missions = List.of(r.data.daily.missions)..[idx] = m.copyWith(claimed: true);
    return EconomyResult(
      r.data.copyWith(
        daily: r.data.daily.copyWith(missions: missions, missionsClaimedTotal: r.data.daily.missionsClaimedTotal + 1),
      ),
      grants: [RewardGrant(tx, def.title, def.reward)],
    );
  }

  // ----------------------------------------------------------- achievements

  /// Returns ids of achievements that are complete but not yet claimed.
  List<String> updateAchievements(SaveData d) => [
    for (final a in AchievementCatalog.all)
      if (!d.claimedAchievements.contains(a.id) && a.progress(d) >= a.target) a.id,
  ];

  EconomyResult claimAchievement(SaveData d, String id, DateTime now) {
    final a = AchievementCatalog.byId(id);
    if (d.claimedAchievements.contains(id)) return EconomyResult(d, status: TxStatus.duplicate);
    if (a.progress(d) < a.target) return EconomyResult(d, status: TxStatus.invalid);
    final r = WalletLedger.grant(d, a.reward, txId: 'ach:$id', reason: 'Achievement: ${a.title}', now: now);
    if (!r.ok) return EconomyResult(d, status: r.status);
    return EconomyResult(
      r.data.copyWith(claimedAchievements: {...r.data.claimedAchievements, id}),
      grants: [RewardGrant('ach:$id', a.title, a.reward)],
    );
  }

  // ------------------------------------------------------------ daily login

  /// Which calendar day (1..7) would be claimed today, or null if already
  /// claimed today. A missed day resets the cycle to day 1.
  int? nextLoginDay(SaveData d, DateTime now) {
    final today = dayKey(now);
    final last = d.daily.lastLoginDate;
    if (last == today) return null;
    final yesterday = dayKey(DateTime(now.year, now.month, now.day - 1));
    if (last == yesterday) return d.daily.loginDay % 7 + 1;
    return 1;
  }

  EconomyResult claimDailyReward(SaveData d, DateTime now) {
    final day = nextLoginDay(d, now);
    if (day == null) return EconomyResult(d, status: TxStatus.duplicate);
    final today = dayKey(now);
    final yesterday = dayKey(DateTime(now.year, now.month, now.day - 1));
    final reward = config.loginRewards[day - 1];
    final r = WalletLedger.grant(d, reward, txId: 'login:$today', reason: 'Daily login day $day', now: now);
    if (!r.ok) return EconomyResult(d, status: r.status);
    final streak = d.daily.lastLoginDate == yesterday ? d.daily.currentStreak + 1 : 1;
    return EconomyResult(
      r.data.copyWith(
        daily: r.data.daily.copyWith(
          loginDay: day,
          lastLoginDate: today,
          currentStreak: streak,
          bestStreak: max(streak, d.daily.bestStreak),
        ),
      ),
      grants: [RewardGrant('login:$today', 'Day $day reward', reward)],
      extra: day,
    );
  }

  // ------------------------------------------------------------------ chest

  bool isChestAvailable(SaveData d, DateTime now) => d.daily.lastChestDate != dayKey(now);

  ChestOutcome rollChest(Random rng) {
    var roll = rng.nextInt(ChestTable.totalWeight);
    for (final o in ChestTable.outcomes) {
      roll -= o.weight;
      if (roll < 0) return o;
    }
    return ChestTable.outcomes.first;
  }

  EconomyResult claimChestReward(SaveData d, DateTime now, Random rng) {
    if (!isChestAvailable(d, now)) return EconomyResult(d, status: TxStatus.duplicate);
    final today = dayKey(now);
    final outcome = rollChest(rng);
    final tx = 'chest:$today';
    final r = WalletLedger.grant(d, outcome.reward, txId: tx, reason: 'Daily chest: ${outcome.label}', now: now);
    if (!r.ok) return EconomyResult(d, status: r.status);
    final history = [ChestRecord(date: today, outcomeId: outcome.id, reward: outcome.reward), ...d.daily.chestHistory];
    return EconomyResult(
      r.data.copyWith(
        daily: r.data.daily.copyWith(lastChestDate: today, chestHistory: history.take(20).toList()),
      ),
      grants: [RewardGrant(tx, outcome.label, outcome.reward)],
      extra: outcome,
    );
  }
}
