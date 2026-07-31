import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_keys.dart';

/// Thin async wrapper over [SharedPreferences].
///
/// Every read defends against absent keys or a failed/corrupt read by
/// falling back to a documented default rather than throwing into the UI
/// (architecture v1 §8.7). Every write swallows its own failures the same
/// way (architecture v3 §11) — a failed persist should never throw into the
/// UI either; it just means that particular write silently didn't durably
/// land. This is a write-through durability backup only — the app's
/// in-memory providers are the runtime source of truth.
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

  Future<void> setOnboardingComplete(bool value) async {
    try {
      await _prefs.setBool(kKeyOnboardingComplete, value);
    } catch (_) {
      // Swallow — a failed write never throws into the UI.
    }
  }

  String get playerName {
    try {
      return _prefs.getString(kKeyPlayerName) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setPlayerName(String value) async {
    try {
      await _prefs.setString(kKeyPlayerName, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get schemaVersion {
    try {
      return _prefs.getInt(kKeySchemaVersion) ?? kPrefsSchemaVersion;
    } catch (_) {
      return kPrefsSchemaVersion;
    }
  }

  Future<void> setSchemaVersion(int value) async {
    try {
      await _prefs.setInt(kKeySchemaVersion, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get totalRunsPlayed {
    try {
      return _prefs.getInt(kKeyTotalRunsPlayed) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setTotalRunsPlayed(int value) async {
    try {
      await _prefs.setInt(kKeyTotalRunsPlayed, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get totalDeaths {
    try {
      return _prefs.getInt(kKeyTotalDeaths) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setTotalDeaths(int value) async {
    try {
      await _prefs.setInt(kKeyTotalDeaths, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get totalSurvives {
    try {
      return _prefs.getInt(kKeyTotalSurvives) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setTotalSurvives(int value) async {
    try {
      await _prefs.setInt(kKeyTotalSurvives, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get totalEternal {
    try {
      return _prefs.getInt(kKeyTotalEternal) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setTotalEternal(int value) async {
    try {
      await _prefs.setInt(kKeyTotalEternal, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get bestLifePercent {
    try {
      return _prefs.getInt(kKeyBestLifePercent) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setBestLifePercent(int value) async {
    try {
      await _prefs.setInt(kKeyBestLifePercent, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get streakCurrent {
    try {
      return _prefs.getInt(kKeyStreakCurrent) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setStreakCurrent(int value) async {
    try {
      await _prefs.setInt(kKeyStreakCurrent, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get streakBest {
    try {
      return _prefs.getInt(kKeyStreakBest) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> setStreakBest(int value) async {
    try {
      await _prefs.setInt(kKeyStreakBest, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get streakLastPlayDay {
    try {
      return _prefs.getInt(kKeyStreakLastPlayDay) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<void> setStreakLastPlayDay(int value) async {
    try {
      await _prefs.setInt(kKeyStreakLastPlayDay, value);
    } catch (_) {
      // Swallow.
    }
  }

  bool get soundEnabled {
    try {
      return _prefs.getBool(kKeySoundEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    try {
      await _prefs.setBool(kKeySoundEnabled, value);
    } catch (_) {
      // Swallow.
    }
  }

  bool get hapticsEnabled {
    try {
      return _prefs.getBool(kKeyHapticsEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setHapticsEnabled(bool value) async {
    try {
      await _prefs.setBool(kKeyHapticsEnabled, value);
    } catch (_) {
      // Swallow.
    }
  }

  bool get reminderEnabled {
    try {
      return _prefs.getBool(kKeyReminderEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setReminderEnabled(bool value) async {
    try {
      await _prefs.setBool(kKeyReminderEnabled, value);
    } catch (_) {
      // Swallow.
    }
  }

  bool get reminderOptInShown {
    try {
      return _prefs.getBool(kKeyReminderOptInShown) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setReminderOptInShown(bool value) async {
    try {
      await _prefs.setBool(kKeyReminderOptInShown, value);
    } catch (_) {
      // Swallow.
    }
  }

  int get avatarId {
    try {
      return _prefs.getInt(kKeyAvatarId) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<void> setAvatarId(int value) async {
    try {
      await _prefs.setInt(kKeyAvatarId, value);
    } catch (_) {
      // Swallow.
    }
  }

  // --- Remote story config: dedup cycle ---

  List<String> get seenStoryIdsDeath {
    try {
      return _prefs.getStringList(kKeySeenStoryIdsDeath) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSeenStoryIdsDeath(List<String> value) async {
    try {
      await _prefs.setStringList(kKeySeenStoryIdsDeath, value);
    } catch (_) {
      // Swallow.
    }
  }

  List<String> get seenStoryIdsSurvived {
    try {
      return _prefs.getStringList(kKeySeenStoryIdsSurvived) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSeenStoryIdsSurvived(List<String> value) async {
    try {
      await _prefs.setStringList(kKeySeenStoryIdsSurvived, value);
    } catch (_) {
      // Swallow.
    }
  }

  List<String> get seenStoryIdsEternal {
    try {
      return _prefs.getStringList(kKeySeenStoryIdsEternal) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setSeenStoryIdsEternal(List<String> value) async {
    try {
      await _prefs.setStringList(kKeySeenStoryIdsEternal, value);
    } catch (_) {
      // Swallow.
    }
  }

  String get lastStoryIdDeath {
    try {
      return _prefs.getString(kKeyLastStoryIdDeath) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setLastStoryIdDeath(String value) async {
    try {
      await _prefs.setString(kKeyLastStoryIdDeath, value);
    } catch (_) {
      // Swallow.
    }
  }

  String get lastStoryIdSurvived {
    try {
      return _prefs.getString(kKeyLastStoryIdSurvived) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setLastStoryIdSurvived(String value) async {
    try {
      await _prefs.setString(kKeyLastStoryIdSurvived, value);
    } catch (_) {
      // Swallow.
    }
  }

  String get lastStoryIdEternal {
    try {
      return _prefs.getString(kKeyLastStoryIdEternal) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setLastStoryIdEternal(String value) async {
    try {
      await _prefs.setString(kKeyLastStoryIdEternal, value);
    } catch (_) {
      // Swallow.
    }
  }

  // --- Remote story config: remote payload cache ---

  String get storyPoolCache {
    try {
      return _prefs.getString(kKeyStoryPoolCache) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setStoryPoolCache(String value) async {
    try {
      await _prefs.setString(kKeyStoryPoolCache, value);
    } catch (_) {
      // Swallow.
    }
  }

  String get storyPoolEtag {
    try {
      return _prefs.getString(kKeyStoryPoolEtag) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setStoryPoolEtag(String value) async {
    try {
      await _prefs.setString(kKeyStoryPoolEtag, value);
    } catch (_) {
      // Swallow.
    }
  }

  /// Exposes `DateTime`, not raw millis, so the repository never does epoch
  /// arithmetic itself. Default is the epoch (`DateTime.fromMillisecondsSinceEpoch(0)`).
  DateTime get storyPoolFetchedAt {
    try {
      final millis = _prefs.getInt(kKeyStoryPoolFetchedAt) ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<void> setStoryPoolFetchedAt(DateTime value) async {
    try {
      await _prefs.setInt(kKeyStoryPoolFetchedAt, value.millisecondsSinceEpoch);
    } catch (_) {
      // Swallow.
    }
  }

  /// Full teardown for Settings' "Reset progress" (architecture v3 §7/§11
  /// risk 6): clears every key this app has ever written. Defends against a
  /// failed clear the same way every other write here does — never throws
  /// into the UI. This also drops the remote-story-config dedup cycle and
  /// payload cache: the next launch re-fetches from the network, or falls
  /// back to the bundled asset offline — both fine, but the caller must
  /// separately reset `StoryCycleStore`'s in-memory copy of the same state
  /// (see `StoryCycleStore.reset`), since this call alone does not touch it.
  Future<void> clearAll() async {
    try {
      await _prefs.clear();
    } catch (_) {
      // Swallow — worst case some keys survive a failed reset attempt.
    }
  }
}
