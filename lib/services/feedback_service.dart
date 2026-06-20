import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small, platform-aware feedback cues for chat events.
///
/// Mobile devices have haptics, so a reply completing buzzes gently. Desktops
/// (and the web) have no haptic hardware, so they fall back to a short system
/// sound so the user is still notified when a long reply finishes.
abstract final class AppFeedback {
  /// Signals that a model's reply has finished streaming.
  static void responseComplete() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        HapticFeedback.mediumImpact();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        SystemSound.play(SystemSoundType.alert);
    }
  }
}
