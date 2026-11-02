import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/player_store.dart';
import '../../shared/widgets/common.dart';
import '../rewards/reward_service.dart';
import '../wallet/models/wallet_models.dart';
import '../wallet/wallet_ledger.dart';
import 'booster_catalog.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  static const boosterIcons = {
    'undo': Icons.undo_rounded,
    'hammer': Icons.gavel_rounded,
    'remove': Icons.cleaning_services_rounded,
    'shuffle': Icons.shuffle_rounded,
    'rainbow': Icons.auto_awesome_rounded,
    'extra_space': Icons.unfold_more_double_rounded,
    'adv_undo': Icons.history_rounded,
    'adv_hint': Icons.lightbulb_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(playerStoreProvider.select((d) => d.inventory));

    void report(TxStatus s, String okMsg) {
      switch (s) {
        case TxStatus.applied:
          showToast(context, okMsg);
        case TxStatus.insufficientFunds:
          showToast(context, 'Not enough coins.', error: true);
        case TxStatus.duplicate || TxStatus.invalid:
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: WalletBar())],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionTitle('Boosters'),
          for (final b in Boosters.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(boosterIcons[b.id], color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.name} · ${b.mode == BoosterMode.classic ? 'Classic' : 'Adventure'}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            b.description,
                            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Owned: ${inv[b.id] ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      onPressed: () async {
                        final ok = await confirmPurchase(
                          context,
                          title: 'Buy ${b.name}',
                          message: b.description,
                          currency: Currency.coins,
                          price: b.price,
                        );
                        if (!ok) return;
                        report(
                          ref.read(rewardServiceProvider).buyBooster(b, purchaseId: newTxId(b.id)),
                          '${b.name} added',
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [const Icon(Icons.monetization_on_rounded, size: 16), Text(' ${b.price}')],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Owned boosters are used before coins. Every purchase asks for confirmation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
