import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/puzzle_models.dart';
import 'world_catalog.dart';

/// Loads JSON level packs from assets (cached by Riverpod).
final worldLevelsProvider = FutureProvider.family<List<PuzzleLevel>, int>((ref, worldId) async {
  final raw = await rootBundle.loadString(WorldCatalog.byId(worldId).assetPath);
  final list = jsonDecode(raw) as List;
  return [for (final j in list) PuzzleLevel.fromJson((j as Map).cast<String, dynamic>())];
});
