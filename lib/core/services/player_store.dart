import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/save_data.dart';
import '../storage/save_repository.dart';

/// Overridden in main() / tests.
final saveRepositoryProvider = Provider<SaveRepository>((ref) => InMemorySaveRepository());
final initialSaveProvider = Provider<SaveData>((ref) => const SaveData());
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final randomProvider = Provider<Random>((ref) => Random());

/// Loads and parses the save. If the stored document can't be read, it is
/// copied to a backup slot before a fresh profile is used.
Future<SaveData> loadSaveData(SaveRepository repo) async {
  Map<String, dynamic>? raw;
  try {
    raw = await repo.load();
    if (raw == null) return const SaveData();
    return SaveData.fromJson(raw);
  } catch (e, st) {
    debugPrint('Save load failed, starting fresh: $e\n$st');
    // Never silently discard progress: keep the unreadable document.
    if (raw != null) await repo.backup(raw);
    return const SaveData();
  }
}

/// The single source of truth for persistent player data. Every mutation
/// goes through [commit], which updates state and persists in order.
class PlayerStore extends Notifier<SaveData> {
  Future<void> _writes = Future.value();

  @override
  SaveData build() => ref.read(initialSaveProvider);

  SaveRepository get _repo => ref.read(saveRepositoryProvider);

  /// Current save data (read-only view for services).
  SaveData get data => state;

  void commit(SaveData next) {
    if (identical(next, state)) return;
    state = next;
    final json = next.toJson();
    final repo = _repo;
    _writes = _writes.then((_) => repo.save(json)).catchError((Object e) {
      debugPrint('Save failed: $e');
    });
  }

  /// Completes once every queued write has been persisted.
  Future<void> flush() => _writes;
}

final playerStoreProvider = NotifierProvider<PlayerStore, SaveData>(PlayerStore.new);

int _txCounter = 0;

/// Unique id for one-off transactions (spends, booster uses).
String newTxId(String prefix) =>
    '$prefix:${DateTime.now().microsecondsSinceEpoch}:${_txCounter++}:${Random().nextInt(1 << 30)}';
