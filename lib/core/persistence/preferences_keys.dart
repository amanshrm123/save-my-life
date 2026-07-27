/// Centralised SharedPreferences key names + schema version.
///
/// Keep every prefs key name in one place so a future migration never has to
/// grep for string literals scattered across features.
library;

/// Current prefs schema version. Bump + add migration handling in
/// [PreferencesService] if the meaning of any key below ever changes shape.
const int kPrefsSchemaVersion = 1;

/// Prefs schema version key. int, default [kPrefsSchemaVersion].
const String kKeySchemaVersion = 'schema_version';

/// Whether the one-time onboarding flow has finished. bool, default false.
const String kKeyOnboardingComplete = 'onboarding_complete';

/// The player's chosen display name. String, default '' (absent == anonymous).
const String kKeyPlayerName = 'player_name';

/// Lifetime count of completed Play Loop runs (any outcome). int, default 0.
const String kKeyTotalRunsPlayed = 'total_runs_played';

/// Lifetime count of runs that ended in death. int, default 0.
const String kKeyTotalDeaths = 'total_deaths';

/// Lifetime count of runs that ended `survived`. int, default 0.
const String kKeyTotalSurvives = 'total_survives';

/// Lifetime count of runs that ended `eternal`. int, default 0.
const String kKeyTotalEternal = 'total_eternal';

/// Highest `peakLifePercent` ever recorded across all runs. int, default 0.
const String kKeyBestLifePercent = 'best_life_percent';

/// Current consecutive-day play streak. int, default 0.
const String kKeyStreakCurrent = 'streak_current';

/// Best streak ever reached. int, default 0.
const String kKeyStreakBest = 'streak_best';

/// Local epoch-day index of the last day a run completed. int, default -1
/// (never played).
const String kKeyStreakLastPlayDay = 'streak_last_play_day';

/// Whether sound effects play. bool, default true.
const String kKeySoundEnabled = 'sound_enabled';

/// Whether haptics fire. bool, default true.
const String kKeyHapticsEnabled = 'haptics_enabled';

/// Whether the daily reminder notification is scheduled. bool, default false.
const String kKeyReminderEnabled = 'reminder_enabled';

/// Whether the once-only 8.4 reminder opt-in prompt has already been shown.
/// bool, default false.
const String kKeyReminderOptInShown = 'reminder_opt_in_shown';
