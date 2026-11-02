import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/player_store.dart';
import 'models/wallet_models.dart';
import 'wallet_ledger.dart';

/// Centralized wallet API. All currency changes in the game go through here
/// (or through [WalletLedger] inside RewardService).
class WalletService {
  WalletService(this._ref);
  final Ref _ref;

  PlayerStore get _store => _ref.read(playerStoreProvider.notifier);
  DateTime get _now => _ref.read(clockProvider)();

  TxStatus _apply(Currency c, int amount, String txId, String reason) {
    final r = WalletLedger.apply(_store.data, txId: txId, reason: reason, now: _now, deltas: {c: amount});
    if (r.ok) _store.commit(r.data);
    return r.status;
  }

  TxStatus _credit(Currency c, int amount, String txId, String reason) =>
      amount <= 0 ? TxStatus.invalid : _apply(c, amount, txId, reason);
  TxStatus _debit(Currency c, int amount, String txId, String reason) =>
      amount <= 0 ? TxStatus.invalid : _apply(c, -amount, txId, reason);

  TxStatus addCoins(int amount, {required String txId, required String reason}) =>
      _credit(Currency.coins, amount, txId, reason);
  TxStatus spendCoins(int amount, {required String txId, required String reason}) =>
      _debit(Currency.coins, amount, txId, reason);

  PlayerWallet getBalance() => _store.data.wallet;
  bool canAfford(Currency c, int amount) => getBalance().balance(c) >= amount;
  List<RewardTransaction> getTransactionHistory() => List.unmodifiable(_store.data.history.reversed);
}

final walletServiceProvider = Provider<WalletService>(WalletService.new);
final walletProvider = Provider<PlayerWallet>((ref) => ref.watch(playerStoreProvider.select((d) => d.wallet)));
