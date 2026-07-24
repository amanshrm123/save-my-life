import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_keys.dart';

/// Thin async wrapper over [SharedPreferences].
///
/// Every read defends against absent keys or a failed/corrupt read by
/// falling back to a documented default rather than throwing into the UI
/// (architecture v1 §8.7). This is a write-through durability backup only —
/// the app's in-memory providers are the runtime source of truth.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  /// Constructs a [PreferencesService] backed by the platform's shared
  /// preferences instance. Call once in `main()` before `runApp`.
  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  bool get onboardingComplete {
    try {
      return _prefs.getBool(kKeyOnboardingComplete) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setOnboardingComplete(bool value) {
    return _prefs.setBool(kKeyOnboardingComplete, value);
  }

  String get playerName {
    try {
      return _prefs.getString(kKeyPlayerName) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setPlayerName(String value) {
    return _prefs.setString(kKeyPlayerName, value);
  }

  int get schemaVersion {
    try {
      return _prefs.getInt(kKeySchemaVersion) ?? kPrefsSchemaVersion;
    } catch (_) {
      return kPrefsSchemaVersion;
    }
  }

  Future<void> setSchemaVersion(int value) {
    return _prefs.setInt(kKeySchemaVersion, value);
  }
}
