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
