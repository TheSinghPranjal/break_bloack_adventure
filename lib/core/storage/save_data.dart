import '../../features/wallet/models/wallet_models.dart';

/// Local calendar day key, e.g. 2026-11-02.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Monday-based week key, e.g. 2026-W45 style (uses Monday's date).
String weekKey(DateTime d) {
  final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  return 'W${dayKey(monday)}';
}

Map<String, int> _intMap(dynamic m) => ((m as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as int));

class ClassicStats {
  const ClassicStats({
    this.bestScores = const {},
    this.gamesPlayed = 0,
    this.totalLines = 0,
    this.highestCombo = 0,
    this.totalBlocksPlaced = 0,
    this.dailyBestDate,
    this.dailyBest = 0,
    this.weeklyBestKey,
    this.weeklyBest = 0,
  });

  /// Board size ('8' / '10') -> best score.
  final Map<String, int> bestScores;
  final int gamesPlayed;
  final int totalLines;
  final int highestCombo;
  final int totalBlocksPlaced;
  final String? dailyBestDate;
  final int dailyBest;
  final String? weeklyBestKey;
  final int weeklyBest;

  int best(int size) => bestScores['$size'] ?? 0;
  int get overallBest => bestScores.values.fold(0, (a, b) => a > b ? a : b);

  ClassicStats copyWith({
    Map<String, int>? bestScores,
    int? gamesPlayed,
    int? totalLines,
    int? highestCombo,
    int? totalBlocksPlaced,
    String? dailyBestDate,
    int? dailyBest,
    String? weeklyBestKey,
    int? weeklyBest,
  }) => ClassicStats(
    bestScores: bestScores ?? this.bestScores,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    totalLines: totalLines ?? this.totalLines,
    highestCombo: highestCombo ?? this.highestCombo,
    totalBlocksPlaced: totalBlocksPlaced ?? this.totalBlocksPlaced,
    dailyBestDate: dailyBestDate ?? this.dailyBestDate,
    dailyBest: dailyBest ?? this.dailyBest,
    weeklyBestKey: weeklyBestKey ?? this.weeklyBestKey,
    weeklyBest: weeklyBest ?? this.weeklyBest,
  );

  Map<String, dynamic> toJson() => {
    'best': bestScores,
    'games': gamesPlayed,
    'lines': totalLines,
    'combo': highestCombo,
    'blocks': totalBlocksPlaced,
    'dDate': dailyBestDate,
    'dBest': dailyBest,
    'wKey': weeklyBestKey,
    'wBest': weeklyBest,
  };
  factory ClassicStats.fromJson(Map<String, dynamic> j) => ClassicStats(
    bestScores: _intMap(j['best']),
    gamesPlayed: (j['games'] as int?) ?? 0,
    totalLines: (j['lines'] as int?) ?? 0,
    highestCombo: (j['combo'] as int?) ?? 0,
    totalBlocksPlaced: (j['blocks'] as int?) ?? 0,
    dailyBestDate: j['dDate'] as String?,
    dailyBest: (j['dBest'] as int?) ?? 0,
    weeklyBestKey: j['wKey'] as String?,
    weeklyBest: (j['wBest'] as int?) ?? 0,
  );
}

class AdventureProgress {
  const AdventureProgress({this.stars = const {}, this.replays = 0});

  /// Level key ('world-level') -> best stars (1..3). Presence = completed.
  final Map<String, int> stars;
  final int replays;

  bool isCompleted(int world, int level) => stars.containsKey('$world-$level');
  int starsFor(int world, int level) => stars['$world-$level'] ?? 0;
  int get totalStars => stars.values.fold(0, (a, b) => a + b);
  int get levelsCompleted => stars.length;
  int get threeStarLevels => stars.values.where((s) => s >= 3).length;

  int completedInWorld(int world) => stars.keys.where((k) => k.startsWith('$world-')).length;
  int starsInWorld(int world) => stars.entries.where((e) => e.key.startsWith('$world-')).fold(0, (a, e) => a + e.value);

  /// Highest playable level in a world (levels unlock sequentially).
  int highestUnlocked(int world) {
    var n = 1;
    while (isCompleted(world, n)) {
      n++;
    }
    return n;
  }

  AdventureProgress copyWith({Map<String, int>? stars, int? replays}) =>
      AdventureProgress(stars: stars ?? this.stars, replays: replays ?? this.replays);

  Map<String, dynamic> toJson() => {'stars': stars, 'replays': replays};
  factory AdventureProgress.fromJson(Map<String, dynamic> j) =>
      AdventureProgress(stars: _intMap(j['stars']), replays: (j['replays'] as int?) ?? 0);
}

class MissionState {
  const MissionState({required this.id, this.progress = 0, this.claimed = false});
  final String id;
  final int progress;
  final bool claimed;

  MissionState copyWith({int? progress, bool? claimed}) =>
      MissionState(id: id, progress: progress ?? this.progress, claimed: claimed ?? this.claimed);

  Map<String, dynamic> toJson() => {'id': id, 'p': progress, 'c': claimed};
  factory MissionState.fromJson(Map<String, dynamic> j) =>
      MissionState(id: j['id'] as String, progress: j['p'] as int, claimed: j['c'] as bool);
}

class ChestRecord {
  const ChestRecord({required this.date, required this.outcomeId, required this.reward});
  final String date;
  final String outcomeId;
  final Reward reward;

  Map<String, dynamic> toJson() => {'d': date, 'o': outcomeId, 'r': reward.toJson()};
  factory ChestRecord.fromJson(Map<String, dynamic> j) => ChestRecord(
    date: j['d'] as String,
    outcomeId: j['o'] as String,
    reward: Reward.fromJson((j['r'] as Map).cast<String, dynamic>()),
  );
}

class DailyState {
  const DailyState({
    this.loginDay = 0,
    this.lastLoginDate,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.missionsDate,
    this.missions = const [],
    this.missionsClaimedTotal = 0,
    this.lastChestDate,
    this.chestHistory = const [],
  });

  /// Day (1..7) of the most recent login claim in the 7-day cycle.
  final int loginDay;
  final String? lastLoginDate;
  final int bestStreak;
  final int currentStreak;
  final String? missionsDate;
  final List<MissionState> missions;
  final int missionsClaimedTotal;
  final String? lastChestDate;
  final List<ChestRecord> chestHistory;

  DailyState copyWith({
    int? loginDay,
    String? lastLoginDate,
    int? bestStreak,
    int? currentStreak,
    String? missionsDate,
    List<MissionState>? missions,
    int? missionsClaimedTotal,
    String? lastChestDate,
    List<ChestRecord>? chestHistory,
  }) => DailyState(
    loginDay: loginDay ?? this.loginDay,
    lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    bestStreak: bestStreak ?? this.bestStreak,
    currentStreak: currentStreak ?? this.currentStreak,
    missionsDate: missionsDate ?? this.missionsDate,
    missions: missions ?? this.missions,
    missionsClaimedTotal: missionsClaimedTotal ?? this.missionsClaimedTotal,
    lastChestDate: lastChestDate ?? this.lastChestDate,
    chestHistory: chestHistory ?? this.chestHistory,
  );

  Map<String, dynamic> toJson() => {
    'loginDay': loginDay,
    'lastLogin': lastLoginDate,
    'bestStreak': bestStreak,
    'streak': currentStreak,
    'mDate': missionsDate,
    'missions': [for (final m in missions) m.toJson()],
    'mTotal': missionsClaimedTotal,
    'chestDate': lastChestDate,
    'chestHistory': [for (final c in chestHistory) c.toJson()],
  };
  factory DailyState.fromJson(Map<String, dynamic> j) => DailyState(
    loginDay: (j['loginDay'] as int?) ?? 0,
    lastLoginDate: j['lastLogin'] as String?,
    bestStreak: (j['bestStreak'] as int?) ?? 0,
    currentStreak: (j['streak'] as int?) ?? 0,
    missionsDate: j['mDate'] as String?,
    missions: [
      for (final m in (j['missions'] as List?) ?? const []) MissionState.fromJson((m as Map).cast<String, dynamic>()),
    ],
    missionsClaimedTotal: (j['mTotal'] as int?) ?? 0,
    lastChestDate: j['chestDate'] as String?,
    chestHistory: [
      for (final c in (j['chestHistory'] as List?) ?? const [])
        ChestRecord.fromJson((c as Map).cast<String, dynamic>()),
    ],
  );
}

class GameSettings {
  const GameSettings({
    this.soundOn = true,
    this.musicOn = true,
    this.hapticsOn = true,
    this.soundVolume = 0.8,
    this.musicVolume = 0.5,
    this.classicBoardSize = 10,
  });

  final bool soundOn;
  final bool musicOn;
  final bool hapticsOn;
  final double soundVolume;
  final double musicVolume;
  final int classicBoardSize;

  GameSettings copyWith({
    bool? soundOn,
    bool? musicOn,
    bool? hapticsOn,
    double? soundVolume,
    double? musicVolume,
    int? classicBoardSize,
  }) => GameSettings(
    soundOn: soundOn ?? this.soundOn,
    musicOn: musicOn ?? this.musicOn,
    hapticsOn: hapticsOn ?? this.hapticsOn,
    soundVolume: soundVolume ?? this.soundVolume,
    musicVolume: musicVolume ?? this.musicVolume,
    classicBoardSize: classicBoardSize ?? this.classicBoardSize,
  );

  Map<String, dynamic> toJson() => {
    'sound': soundOn,
    'music': musicOn,
    'haptics': hapticsOn,
    'sv': soundVolume,
    'mv': musicVolume,
    'board': classicBoardSize,
  };
  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
    soundOn: (j['sound'] as bool?) ?? true,
    musicOn: (j['music'] as bool?) ?? true,
    hapticsOn: (j['haptics'] as bool?) ?? true,
    soundVolume: ((j['sv'] as num?) ?? 0.8).toDouble(),
    musicVolume: ((j['mv'] as num?) ?? 0.5).toDouble(),
    classicBoardSize: (j['board'] as int?) ?? 10,
  );
}

/// Lifetime counters used by achievements and the profile screen.
class LifetimeStats {
  const LifetimeStats({this.coinsEarned = 0, this.boostersUsed = 0, this.worldsCompleted = 0});
  final int coinsEarned;
  final int boostersUsed;
  final int worldsCompleted;

  LifetimeStats copyWith({int? coinsEarned, int? boostersUsed, int? worldsCompleted}) => LifetimeStats(
    coinsEarned: coinsEarned ?? this.coinsEarned,
    boostersUsed: boostersUsed ?? this.boostersUsed,
    worldsCompleted: worldsCompleted ?? this.worldsCompleted,
  );

  Map<String, dynamic> toJson() => {'coins': coinsEarned, 'boosters': boostersUsed, 'worlds': worldsCompleted};
  factory LifetimeStats.fromJson(Map<String, dynamic> j) => LifetimeStats(
    coinsEarned: (j['coins'] as int?) ?? 0,
    boostersUsed: (j['boosters'] as int?) ?? 0,
    worldsCompleted: (j['worlds'] as int?) ?? 0,
  );
}

/// Root, versioned save document. Persisted atomically as one JSON blob.
class SaveData {
  const SaveData({
    this.version = currentVersion,
    this.playerName = 'Player',
    this.wallet = const PlayerWallet(coins: 1200),
    this.history = const [],
    this.processedTxIds = const [],
    this.classic = const ClassicStats(),
    this.adventure = const AdventureProgress(),
    this.daily = const DailyState(),
    this.inventory = const {},
    this.claimedAchievements = const {},
    this.lifetime = const LifetimeStats(),
    this.settings = const GameSettings(),
    this.classicSession,
  });

  static const currentVersion = 2;
  static const maxHistory = 150;
  static const maxProcessedIds = 4000;

  final int version;
  final String playerName;
  final PlayerWallet wallet;
  final List<RewardTransaction> history;

  /// Ids of applied transactions (most recent last). Guards idempotency.
  final List<String> processedTxIds;
  final ClassicStats classic;
  final AdventureProgress adventure;
  final DailyState daily;

  /// Booster id -> owned quantity.
  final Map<String, int> inventory;
  final Set<String> claimedAchievements;
  final LifetimeStats lifetime;
  final GameSettings settings;

  /// Serialized in-progress Classic game for crash/exit recovery.
  final Map<String, dynamic>? classicSession;

  bool hasProcessed(String txId) => processedTxIds.contains(txId);

  SaveData copyWith({
    String? playerName,
    PlayerWallet? wallet,
    List<RewardTransaction>? history,
    List<String>? processedTxIds,
    ClassicStats? classic,
    AdventureProgress? adventure,
    DailyState? daily,
    Map<String, int>? inventory,
    Set<String>? claimedAchievements,
    LifetimeStats? lifetime,
    GameSettings? settings,
    Map<String, dynamic>? classicSession,
    bool clearClassicSession = false,
  }) => SaveData(
    version: version,
    playerName: playerName ?? this.playerName,
    wallet: wallet ?? this.wallet,
    history: history ?? this.history,
    processedTxIds: processedTxIds ?? this.processedTxIds,
    classic: classic ?? this.classic,
    adventure: adventure ?? this.adventure,
    daily: daily ?? this.daily,
    inventory: inventory ?? this.inventory,
    claimedAchievements: claimedAchievements ?? this.claimedAchievements,
    lifetime: lifetime ?? this.lifetime,
    settings: settings ?? this.settings,
    classicSession: clearClassicSession ? null : (classicSession ?? this.classicSession),
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'name': playerName,
    'wallet': wallet.toJson(),
    'history': [for (final t in history) t.toJson()],
    'tx': processedTxIds,
    'classic': classic.toJson(),
    'adventure': adventure.toJson(),
    'daily': daily.toJson(),
    'inventory': inventory,
    'achievements': claimedAchievements.toList(),
    'lifetime': lifetime.toJson(),
    'settings': settings.toJson(),
    'classicSession': classicSession,
  };

  /// Parses and migrates older versions. Throws [FormatException] on garbage.
  factory SaveData.fromJson(Map<String, dynamic> raw) {
    final j = migrate(raw);
    Map<String, dynamic> m(String k) => ((j[k] as Map?) ?? const {}).cast<String, dynamic>();
    return SaveData(
      version: currentVersion,
      playerName: (j['name'] as String?) ?? 'Player',
      wallet: PlayerWallet.fromJson(m('wallet')),
      history: [
        for (final t in (j['history'] as List?) ?? const [])
          RewardTransaction.fromJson((t as Map).cast<String, dynamic>()),
      ],
      processedTxIds: ((j['tx'] as List?) ?? const []).cast<String>(),
      classic: ClassicStats.fromJson(m('classic')),
      adventure: AdventureProgress.fromJson(m('adventure')),
      daily: DailyState.fromJson(m('daily')),
      inventory: _intMap(j['inventory']),
      claimedAchievements: {...((j['achievements'] as List?) ?? const []).cast<String>()},
      lifetime: LifetimeStats.fromJson(m('lifetime')),
      settings: GameSettings.fromJson(m('settings')),
      classicSession: (j['classicSession'] as Map?)?.cast<String, dynamic>(),
    );
  }

  /// Version migration hook. Add steps here as the schema evolves.
  static Map<String, dynamic> migrate(Map<String, dynamic> j) {
    final v = (j['version'] as int?) ?? 0;
    if (v > currentVersion) {
      throw FormatException('Save version $v is newer than supported $currentVersion');
    }
    // v0/v1 share the same shape; defaults fill missing fields.
    if (v < 2) j = _migrateToCoinsOnly(j);
    return j;
  }

  /// v2 dropped gems, tickets, the stars wallet balance and the park.
  /// Leftover gems and tickets are converted to coins so nothing is lost.
  static const coinsPerGem = 100;
  static const coinsPerTicket = 50;

  static Map<String, dynamic> _migrateToCoinsOnly(Map<String, dynamic> raw) {
    final j = Map<String, dynamic>.of(raw)..remove('park');
    final w = ((j['wallet'] as Map?) ?? const {}).cast<String, dynamic>();
    final coins =
        ((w['coins'] as int?) ?? 0) +
        ((w['gems'] as int?) ?? 0) * coinsPerGem +
        ((w['tickets'] as int?) ?? 0) * coinsPerTicket;
    j['wallet'] = {'coins': coins};
    // Ledger entries in removed currencies can no longer be parsed.
    j['history'] = [
      for (final t in (j['history'] as List?) ?? const [])
        if ((t as Map)['c'] == 'coins') t,
    ];
    // Old chest outcomes no longer exist; the removed park mission must not
    // linger in today's mission list.
    final daily = ((j['daily'] as Map?) ?? const {}).cast<String, dynamic>();
    j['daily'] = {
      ...daily,
      'chestHistory': const [],
      'missions': [
        for (final m in (daily['missions'] as List?) ?? const [])
          if ((m as Map)['id'] != 'park1') m,
      ],
    };
    return j;
  }
}
