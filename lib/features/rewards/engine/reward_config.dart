import '../../../core/storage/save_data.dart';
import '../../wallet/models/wallet_models.dart';

/// Every economy number lives here so it can be tuned in one place.
class RewardConfig {
  const RewardConfig({
    this.replayCoins = 10,
    this.firstThreeStarBonus = 25,
    this.everyNLevels = 5,
    this.everyNLevelsReward = const Reward(coins: 150),
    this.worldCompleteReward = const Reward(coins: 1500),
    this.firstWorldExtraCoins = 2500,
    this.coinsPer100Score = 5,
    this.coinsPer5Lines = 10,
    this.coinsPer10Lines = 25,
    this.comboCoinsPerStep = 5,
    this.comboCoinsCap = 50,
    this.dailyScoreMilestones = const {500: 50, 1500: 100, 3000: 200},
    this.weeklyScoreTarget = 5000,
    this.weeklyReward = const Reward(coins: 350),
    this.loginRewards = const [
      Reward(coins: 50),
      Reward(coins: 75),
      Reward(coins: 100),
      Reward(coins: 125),
      Reward(coins: 150),
      Reward(coins: 200),
      Reward(coins: 750),
    ],
    this.starsPerWorldGate = 120,
  });

  final int replayCoins;
  final int firstThreeStarBonus;
  final int everyNLevels;
  final Reward everyNLevelsReward;
  final Reward worldCompleteReward;
  final int firstWorldExtraCoins;
  final int coinsPer100Score;
  final int coinsPer5Lines;
  final int coinsPer10Lines;
  final int comboCoinsPerStep;
  final int comboCoinsCap;

  /// Daily best score threshold -> coins (each claimable once per day).
  final Map<int, int> dailyScoreMilestones;
  final int weeklyScoreTarget;
  final Reward weeklyReward;

  /// 7-day login calendar.
  final List<Reward> loginRewards;

  /// Stars needed (cumulative per previous world) to enter the next world.
  final int starsPerWorldGate;
}

// ---------------------------------------------------------------- missions

enum MissionEventKind {
  adventureLevel,
  adventureThreeStar,
  linesCleared,
  multiLineClear,
  classicScore,
  boosterUsed,
  gameFinished,
}

class MissionDef {
  const MissionDef(this.id, this.title, this.kind, this.target, this.reward, {this.isMax = false});
  final String id;
  final String title;
  final MissionEventKind kind;
  final int target;
  final Reward reward;

  /// Progress is the max reported value rather than a running total.
  final bool isMax;
}

abstract final class MissionCatalog {
  static const all = [
    MissionDef('adv3', 'Complete 3 Adventure levels', MissionEventKind.adventureLevel, 3, Reward(coins: 60)),
    MissionDef('lines5', 'Clear 5 lines in Classic', MissionEventKind.linesCleared, 5, Reward(coins: 50)),
    MissionDef(
      'score500',
      'Score 500 points in one Classic game',
      MissionEventKind.classicScore,
      500,
      Reward(coins: 50),
      isMax: true,
    ),
    MissionDef('booster1', 'Use 1 booster', MissionEventKind.boosterUsed, 1, Reward(coins: 100)),
    MissionDef('multi1', 'Clear 2+ lines at once', MissionEventKind.multiLineClear, 1, Reward(coins: 40)),
    MissionDef('games2', 'Finish 2 games in any mode', MissionEventKind.gameFinished, 2, Reward(coins: 40)),
    MissionDef('three1', 'Earn 3 stars on a level', MissionEventKind.adventureThreeStar, 1, Reward(coins: 100)),
    MissionDef('lines20', 'Clear 20 lines in Classic', MissionEventKind.linesCleared, 20, Reward(coins: 100)),
  ];
  static MissionDef byId(String id) => all.firstWhere((m) => m.id == id);
}

// ------------------------------------------------------------ achievements

class AchievementDef {
  const AchievementDef(this.id, this.title, this.description, this.target, this.reward, this.progress);
  final String id;
  final String title;
  final String description;
  final int target;
  final Reward reward;
  final int Function(SaveData) progress;
}

abstract final class AchievementCatalog {
  static final all = <AchievementDef>[
    AchievementDef(
      'first_victory',
      'First Victory',
      'Complete your first Adventure level.',
      1,
      const Reward(coins: 50),
      (d) => d.adventure.levelsCompleted,
    ),
    AchievementDef(
      'puzzle_master',
      'Puzzle Master',
      'Complete 100 Adventure levels.',
      100,
      const Reward(coins: 2500),
      (d) => d.adventure.levelsCompleted,
    ),
    AchievementDef(
      'perfect_planner',
      'Perfect Planner',
      'Earn 3 stars on 10 levels.',
      10,
      const Reward(coins: 500),
      (d) => d.adventure.threeStarLevels,
    ),
    AchievementDef(
      'block_collector',
      'Block Collector',
      'Place 500 shapes in Classic.',
      500,
      const Reward(coins: 150),
      (d) => d.classic.totalBlocksPlaced,
    ),
    AchievementDef(
      'combo_king',
      'Combo King',
      'Reach a 5x combo in Classic.',
      5,
      const Reward(coins: 300),
      (d) => d.classic.highestCombo,
    ),
    AchievementDef(
      'line_crusher',
      'Line Crusher',
      'Clear 200 lines in Classic.',
      200,
      const Reward(coins: 200),
      (d) => d.classic.totalLines,
    ),
    AchievementDef(
      'high_scorer',
      'High Scorer',
      'Reach 10,000 points in one Classic game.',
      10000,
      const Reward(coins: 300),
      (d) => d.classic.overallBest,
    ),
    AchievementDef(
      'daily_champion',
      'Daily Champion',
      'Complete 10 daily missions.',
      10,
      const Reward(coins: 500),
      (d) => d.daily.missionsClaimedTotal,
    ),
    AchievementDef(
      'loyal_visitor',
      'Loyal Visitor',
      'Reach a 7-day login streak.',
      7,
      const Reward(coins: 1000),
      (d) => d.daily.bestStreak,
    ),
    AchievementDef(
      'world_explorer',
      'World Explorer',
      'Complete a whole world.',
      1,
      const Reward(coins: 300),
      (d) => d.lifetime.worldsCompleted,
    ),
    AchievementDef(
      'coin_collector',
      'Coin Collector',
      'Earn 5,000 coins in total.',
      5000,
      const Reward(coins: 300),
      (d) => d.lifetime.coinsEarned,
    ),
  ];
  static AchievementDef byId(String id) => all.firstWhere((a) => a.id == id);
}

// ------------------------------------------------------------------- chest

enum Rarity { common, uncommon, rare, epic }

class ChestOutcome {
  const ChestOutcome(this.id, this.rarity, this.weight, this.reward, this.label);
  final String id;
  final Rarity rarity;
  final int weight;
  final Reward reward;
  final String label;
}

/// Published, fixed odds. The UI shows these exact percentages.
abstract final class ChestTable {
  static const outcomes = [
    ChestOutcome('coins_s', Rarity.common, 40, Reward(coins: 80), '80 coins'),
    ChestOutcome('coins_m', Rarity.common, 20, Reward(coins: 150), '150 coins'),
    ChestOutcome('coins_l', Rarity.uncommon, 15, Reward(coins: 250), '250 coins'),
    ChestOutcome('coins_xl', Rarity.uncommon, 12, Reward(coins: 400), '400 coins'),
    ChestOutcome('coins_xxl', Rarity.rare, 10, Reward(coins: 600), '600 coins'),
    ChestOutcome('jackpot', Rarity.epic, 3, Reward(coins: 1500), '1,500 coins'),
  ];
  static int get totalWeight => outcomes.fold(0, (a, o) => a + o.weight);
  static double chance(ChestOutcome o) => o.weight / totalWeight;
}
