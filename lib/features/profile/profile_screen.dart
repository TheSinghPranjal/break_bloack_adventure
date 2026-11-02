import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/player_store.dart';
import '../../core/storage/save_data.dart';
import '../../shared/widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(playerStoreProvider);
    final store = ref.read(playerStoreProvider.notifier);
    void setSettings(GameSettings s) => store.commit(store.data.copyWith(settings: s));

    Widget stat(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SoftCard(
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFB06BFF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      d.playerName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.playerName, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${d.adventure.totalStars} stars collected',
                        style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () async {
                    final c = TextEditingController(text: d.playerName);
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Your name'),
                        content: TextField(controller: c, maxLength: 16, autofocus: true),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (name != null && name.isNotEmpty) store.commit(store.data.copyWith(playerName: name));
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('Player stats'),
          SoftCard(
            child: Column(
              children: [
                stat('Adventure levels completed', '${d.adventure.levelsCompleted}'),
                stat('3-star levels', '${d.adventure.threeStarLevels}'),
                stat('Classic best (10×10)', '${d.classic.best(10)}'),
                stat('Classic best (8×8)', '${d.classic.best(8)}'),
                stat('Classic games played', '${d.classic.gamesPlayed}'),
                stat('Lines cleared', '${d.classic.totalLines}'),
                stat('Highest combo', 'x${d.classic.highestCombo}'),
                stat('Coins earned', '${d.lifetime.coinsEarned}'),
                stat('Boosters used', '${d.lifetime.boostersUsed}'),
                stat('Best login streak', '${d.daily.bestStreak} days'),
              ],
            ),
          ),
          const SectionTitle('Settings'),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound effects', style: TextStyle(fontWeight: FontWeight.w800)),
                  value: d.settings.soundOn,
                  onChanged: (v) => setSettings(d.settings.copyWith(soundOn: v)),
                ),
                SwitchListTile(
                  title: const Text('Haptics', style: TextStyle(fontWeight: FontWeight.w800)),
                  value: d.settings.hapticsOn,
                  onChanged: (v) => setSettings(d.settings.copyWith(hapticsOn: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
