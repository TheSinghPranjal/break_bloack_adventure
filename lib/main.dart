import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/player_store.dart';
import 'core/storage/save_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final repo = SharedPrefsSaveRepository(await SharedPreferences.getInstance());
  final save = await loadSaveData(repo);
  runApp(
    ProviderScope(
      overrides: [saveRepositoryProvider.overrideWithValue(repo), initialSaveProvider.overrideWithValue(save)],
      child: const BlockAdventureApp(),
    ),
  );
}
