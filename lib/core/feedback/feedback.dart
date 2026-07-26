import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Process-global haptics/sound gates (architecture v3 §7/§11 risk 8).
///
/// Deliberately **Riverpod-free** — `StickerButton` lives in `core/widgets/`
/// and must stay decoupled from Riverpod, so this is a plain `ValueNotifier`
/// singleton instead of a provider. `settingsProvider` writes these two
/// notifiers on load and on every toggle; consumers (`StickerButton`,
/// `AudioService`) read `.value` synchronously at the moment they need it
/// rather than subscribing as listeners — there is nothing to leak.
///
/// Named `AppFeedback` rather than the more obvious `Feedback` to avoid a
/// name clash with `package:flutter/material.dart`'s own `Feedback` widget
/// class, which almost every screen in this app also imports.
class AppFeedback {
  const AppFeedback._();

  static final ValueNotifier<bool> hapticsEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(true);

  /// Convenience used by widgets that just want to "buzz if enabled" without
  /// importing `flutter/services.dart` themselves.
  static void lightImpactIfEnabled() {
    if (hapticsEnabled.value) HapticFeedback.lightImpact();
  }

  static void mediumImpactIfEnabled() {
    if (hapticsEnabled.value) HapticFeedback.mediumImpact();
  }

  static void heavyImpactIfEnabled() {
    if (hapticsEnabled.value) HapticFeedback.heavyImpact();
  }
}
