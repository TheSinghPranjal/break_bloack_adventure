/// The game has a single currency. The enum is kept so ledger entries stay
/// self-describing in saves.
enum Currency { coins }

class PlayerWallet {
  const PlayerWallet({this.coins = 0});

  final int coins;

  int balance(Currency c) => coins;

  PlayerWallet withDelta(Currency c, int delta) => PlayerWallet(coins: coins + delta);

  Map<String, dynamic> toJson() => {'coins': coins};
  factory PlayerWallet.fromJson(Map<String, dynamic> j) => PlayerWallet(coins: (j['coins'] as int?) ?? 0);
}

/// A coin reward.
class Reward {
  const Reward({this.coins = 0});

  final int coins;

  static const none = Reward();

  bool get isEmpty => coins == 0;

  Map<Currency, int> get amounts => {if (coins != 0) Currency.coins: coins};

  Reward operator +(Reward o) => Reward(coins: coins + o.coins);

  Map<String, dynamic> toJson() => {if (coins != 0) 'coins': coins};
  factory Reward.fromJson(Map<String, dynamic> j) => Reward(coins: (j['coins'] as int?) ?? 0);

  @override
  String toString() => toJson().toString();
}

class RewardTransaction {
  const RewardTransaction({
    required this.id,
    required this.currency,
    required this.amount,
    required this.reason,
    required this.timestamp,
    required this.balanceAfter,
  });

  final String id;
  final Currency currency;

  /// Positive for credits, negative for debits.
  final int amount;
  final String reason;
  final DateTime timestamp;
  final int balanceAfter;

  Map<String, dynamic> toJson() => {
    'id': id,
    'c': currency.name,
    'a': amount,
    'r': reason,
    't': timestamp.millisecondsSinceEpoch,
    'b': balanceAfter,
  };
  factory RewardTransaction.fromJson(Map<String, dynamic> j) => RewardTransaction(
    id: j['id'] as String,
    currency: Currency.values.byName(j['c'] as String),
    amount: j['a'] as int,
    reason: j['r'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    balanceAfter: j['b'] as int,
  );
}
