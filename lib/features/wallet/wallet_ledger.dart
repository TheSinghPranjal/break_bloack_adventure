import '../../core/storage/save_data.dart';
import 'models/wallet_models.dart';

enum TxStatus { applied, duplicate, insufficientFunds, invalid }

class LedgerResult {
  const LedgerResult(this.data, this.status);
  final SaveData data;
  final TxStatus status;
  bool get ok => status == TxStatus.applied;
}

/// Pure, validated, idempotent wallet transactions over [SaveData].
///
/// Every transaction carries an id. Applying the same id twice is a no-op
/// (`duplicate`), which protects against double taps, duplicate events and
/// replays after an app restart. Balances can never go negative: a debit
/// that cannot be fully covered is rejected without partial application.
abstract final class WalletLedger {
  static LedgerResult apply(
    SaveData d, {
    required String txId,
    required String reason,
    required DateTime now,
    Map<Currency, int> deltas = const {},
    Map<String, int> boosterDeltas = const {},
  }) {
    if (txId.isEmpty) return LedgerResult(d, TxStatus.invalid);
    final nonZero = {
      for (final e in deltas.entries)
        if (e.value != 0) e.key: e.value,
    };
    final boosters = {
      for (final e in boosterDeltas.entries)
        if (e.value != 0) e.key: e.value,
    };
    if (nonZero.isEmpty && boosters.isEmpty) return LedgerResult(d, TxStatus.invalid);
    if (d.hasProcessed(txId)) return LedgerResult(d, TxStatus.duplicate);

    var wallet = d.wallet;
    for (final e in nonZero.entries) {
      if (wallet.balance(e.key) + e.value < 0) {
        return LedgerResult(d, TxStatus.insufficientFunds);
      }
    }
    final inventory = Map.of(d.inventory);
    for (final e in boosters.entries) {
      final next = (inventory[e.key] ?? 0) + e.value;
      if (next < 0) return LedgerResult(d, TxStatus.insufficientFunds);
      inventory[e.key] = next;
    }

    final history = List.of(d.history);
    for (final e in nonZero.entries) {
      wallet = wallet.withDelta(e.key, e.value);
      history.add(
        RewardTransaction(
          id: nonZero.length == 1 ? txId : '$txId#${e.key.name}',
          currency: e.key,
          amount: e.value,
          reason: reason,
          timestamp: now,
          balanceAfter: wallet.balance(e.key),
        ),
      );
    }
    if (history.length > SaveData.maxHistory) {
      history.removeRange(0, history.length - SaveData.maxHistory);
    }
    final ids = [...d.processedTxIds, txId];
    if (ids.length > SaveData.maxProcessedIds) {
      ids.removeRange(0, ids.length - SaveData.maxProcessedIds);
    }
    final earnedCoins = (nonZero[Currency.coins] ?? 0) > 0 ? nonZero[Currency.coins]! : 0;

    return LedgerResult(
      d.copyWith(
        wallet: wallet,
        history: history,
        processedTxIds: ids,
        inventory: inventory,
        lifetime: d.lifetime.copyWith(coinsEarned: d.lifetime.coinsEarned + earnedCoins),
      ),
      TxStatus.applied,
    );
  }

  static LedgerResult grant(
    SaveData d,
    Reward r, {
    required String txId,
    required String reason,
    required DateTime now,
  }) => apply(d, txId: txId, reason: reason, now: now, deltas: r.amounts);

  static LedgerResult spend(
    SaveData d,
    Currency c,
    int amount, {
    required String txId,
    required String reason,
    required DateTime now,
  }) {
    if (amount <= 0) return LedgerResult(d, TxStatus.invalid);
    return apply(d, txId: txId, reason: reason, now: now, deltas: {c: -amount});
  }
}
