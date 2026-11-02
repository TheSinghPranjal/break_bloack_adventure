import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/player_store.dart';

enum Sfx { tap, pickup, place, invalid, clear, combo, win, reward }

/// Haptics + system sounds, gated by the player's persisted settings.
/// (Bundled custom audio arrives with the audio phase; this keeps the same
/// call sites.)
class FeedbackService {
  FeedbackService(this._ref);
  final Ref _ref;

  void play(Sfx s) {
    final settings = _ref.read(playerStoreProvider).settings;
    if (settings.hapticsOn) {
      switch (s) {
        case Sfx.place || Sfx.pickup || Sfx.tap:
          HapticFeedback.selectionClick();
        case Sfx.invalid:
          HapticFeedback.heavyImpact();
        case Sfx.clear || Sfx.combo || Sfx.win || Sfx.reward:
          HapticFeedback.mediumImpact();
      }
    }
    if (settings.soundOn && s != Sfx.pickup) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}

final feedbackProvider = Provider<FeedbackService>(FeedbackService.new);
