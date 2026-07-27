import '../../../core/persistence/preferences_keys.dart';
import '../../../core/persistence/preferences_service.dart';
import '../domain/player_profile.dart';

/// Reads/writes [PlayerProfile] via [PreferencesService].
///
/// Writes happen only at the single terminal onboarding action (Start
/// playing / Skip for now) — never per-keystroke, never per-card
/// (architecture v1 §3, §8.1).
class PlayerProfileRepository {
  const PlayerProfileRepository(this._prefs);

  final PreferencesService _prefs;

  /// Loads the current profile from prefs. Defends against absent/failed
  /// reads by falling back to defaults (architecture v1 §8.7) — this never
  /// throws into the UI.
  Future<PlayerProfile> load() async {
    return PlayerProfile(
      name: _prefs.playerName,
      onboardingComplete: _prefs.onboardingComplete,
    );
  }

  /// Terminal action: player submitted a valid, sanitized [name].
  Future<PlayerProfile> completeWithName(String name) async {
    await _prefs.setPlayerName(name);
    await _prefs.setOnboardingComplete(true);
    await _prefs.setSchemaVersion(kPrefsSchemaVersion);
    return PlayerProfile(name: name, onboardingComplete: true);
  }

  /// Terminal action: player tapped "Skip for now" — anonymous, but
  /// onboarding is permanently complete (architecture v1 §4).
  Future<PlayerProfile> completeAnonymous() async {
    await _prefs.setPlayerName('');
    await _prefs.setOnboardingComplete(true);
    await _prefs.setSchemaVersion(kPrefsSchemaVersion);
    return const PlayerProfile(name: '', onboardingComplete: true);
  }
}
