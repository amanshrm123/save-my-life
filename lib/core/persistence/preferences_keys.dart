/// Centralised SharedPreferences key names + schema version.
///
/// Keep every prefs key name in one place so a future migration never has to
/// grep for string literals scattered across features.
library;

/// Current prefs schema version. Bump + add migration handling in
/// [PreferencesService] if the meaning of any key below ever changes shape.
///
/// Bumped 1 -> 2 for the remote-story-config keys below. No migration code is
/// needed: every new key's absent-value default (empty list / empty string /
/// epoch-zero) is already the correct fresh-install state, and a v1 install
/// upgrading to v2 correctly starts with an empty story cycle and a cold
/// cache.
const int kPrefsSchemaVersion = 2;

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

/// The player's chosen avatar id (`AvatarCatalog`, 0-11). int, default -1
/// (never picked — Home shows the "Pick your look" hint pill until the
/// first commit from `/avatar-picker`).
const String kKeyAvatarId = 'avatar_id';

// --- Remote story config: dedup cycle (options §8.2) ---

/// IDs of story beats already shown in the current cycle. StringList, default [].
const String kKeySeenStoryIdsDeath = 'seen_story_ids_death';
const String kKeySeenStoryIdsSurvived = 'seen_story_ids_survived';
const String kKeySeenStoryIdsEternal = 'seen_story_ids_eternal';

/// The single most recently shown beat ID per tier, used only to avoid an
/// immediate repeat across a cycle-reset boundary. String, default ''.
const String kKeyLastStoryIdDeath = 'last_story_id_death';
const String kKeyLastStoryIdSurvived = 'last_story_id_survived';
const String kKeyLastStoryIdEternal = 'last_story_id_eternal';

// --- Remote story config: remote payload cache (implementation spec §2.4 R5) ---

/// The last successfully-PARSED remote payload, verbatim. String, default ''.
/// Cold-start bootstrap only — never the runtime source of truth. Only ever
/// written after StoryPoolCodec.decode has already succeeded on it.
const String kKeyStoryPoolCache = 'story_pool_cache';

/// ETag of the cached payload, sent as If-None-Match. String, default ''.
const String kKeyStoryPoolEtag = 'story_pool_etag';

/// Epoch millis of the last SUCCESSFUL fetch (200 or 304). int, default 0.
/// Not written on failure, so a failing CDN is retried next session rather
/// than suppressed for the TTL.
const String kKeyStoryPoolFetchedAt = 'story_pool_fetched_at';
