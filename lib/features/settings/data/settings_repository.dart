import '../../../core/persistence/preferences_service.dart';
import '../domain/app_settings.dart';

/// Reads/writes [AppSettings] + the once-only reminder-opt-in-shown flag via
/// [PreferencesService] (architecture v3 §7).
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final PreferencesService _prefs;

  AppSettings load() {
    return AppSettings(
      sound: _prefs.soundEnabled,
      haptics: _prefs.hapticsEnabled,
      reminder: _prefs.reminderEnabled,
    );
  }

  Future<void> setSound(bool value) => _prefs.setSoundEnabled(value);
  Future<void> setHaptics(bool value) => _prefs.setHapticsEnabled(value);
  Future<void> setReminder(bool value) => _prefs.setReminderEnabled(value);

  bool get reminderOptInShown => _prefs.reminderOptInShown;
  Future<void> setReminderOptInShown(bool value) => _prefs.setReminderOptInShown(value);
}
