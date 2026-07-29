import '../../../core/persistence/preferences_service.dart';

/// Reads/writes the player's chosen avatar id via [PreferencesService]
/// (design `home-avatars-v1.md` §5.4) — the same thin repository shape as
/// `SettingsRepository`.
class AvatarRepository {
  const AvatarRepository(this._prefs);

  final PreferencesService _prefs;

  /// `-1` means "never picked" (fresh install).
  int get avatarId => _prefs.avatarId;

  Future<void> setAvatarId(int id) => _prefs.setAvatarId(id);
}
