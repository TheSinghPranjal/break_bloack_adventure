import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistence abstraction. A cloud implementation (e.g. Firebase) can be
/// added later without touching engines or services.
abstract interface class SaveRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);

  /// Stores an unreadable save document so it is never lost.
  Future<void> backup(Map<String, dynamic> data);
}

/// Stores the whole save as a single JSON string, written to a staging key
/// first and then committed, so a crash mid-write never corrupts the
/// last-known-good save.
class SharedPrefsSaveRepository implements SaveRepository {
  SharedPrefsSaveRepository(this._prefs);

  static const _mainKey = 'save.main';
  static const _stagingKey = 'save.staging';
  final SharedPreferences _prefs;

  @override
  Future<Map<String, dynamic>?> load() async {
    for (final key in [_mainKey, _stagingKey]) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        return (jsonDecode(raw) as Map).cast<String, dynamic>();
      } on FormatException {
        continue; // fall back to the other copy
      }
    }
    return null;
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final raw = jsonEncode(data);
    await _prefs.setString(_stagingKey, raw);
    await _prefs.setString(_mainKey, raw);
  }

  @override
  Future<void> backup(Map<String, dynamic> data) async {
    await _prefs.setString('save.backup.${DateTime.now().millisecondsSinceEpoch}', jsonEncode(data));
  }
}

/// For tests and previews.
class InMemorySaveRepository implements SaveRepository {
  InMemorySaveRepository([this.data]);
  Map<String, dynamic>? data;
  Map<String, dynamic>? backedUp;
  int saveCount = 0;

  @override
  Future<void> backup(Map<String, dynamic> d) async => backedUp = d;

  @override
  Future<Map<String, dynamic>?> load() async =>
      data == null ? null : (jsonDecode(jsonEncode(data)) as Map).cast<String, dynamic>();

  @override
  Future<void> save(Map<String, dynamic> d) async {
    saveCount++;
    data = (jsonDecode(jsonEncode(d)) as Map).cast<String, dynamic>();
  }
}
