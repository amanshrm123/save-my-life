import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback.dart';
import '../../onboarding/state/onboarding_providers.dart' show preferencesServiceProvider;
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

final Provider<SettingsRepository> settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(preferencesServiceProvider)),
);

/// RAM source of truth for sound/haptics/reminder (architecture v3 §7),
/// write-through to prefs. Also the single writer of the `AppFeedback`
/// `ValueNotifier` gates (§7/§11 risk 8) — updated on load and on every
/// toggle so `StickerButton`/`AudioService` immediately reflect the change.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final settings = ref.watch(settingsRepositoryProvider).load();
    AppFeedback.soundEnabled.value = settings.sound;
    AppFeedback.hapticsEnabled.value = settings.haptics;
    return settings;
  }

  Future<void> setSound(bool value) async {
    state = state.copyWith(sound: value);
    AppFeedback.soundEnabled.value = value;
    await ref.read(settingsRepositoryProvider).setSound(value);
  }

  Future<void> setHaptics(bool value) async {
    state = state.copyWith(haptics: value);
    AppFeedback.hapticsEnabled.value = value;
    await ref.read(settingsRepositoryProvider).setHaptics(value);
  }

  /// Persists just the reminder toggle's RAM+prefs state. Actual OS
  /// scheduling/cancellation is `ReminderController`'s job (notifications
  /// feature) — this only keeps the toggle in sync with that outcome, so
  /// `settings` never needs to depend on `notifications`.
  Future<void> setReminderFlag(bool value) async {
    state = state.copyWith(reminder: value);
    await ref.read(settingsRepositoryProvider).setReminder(value);
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
