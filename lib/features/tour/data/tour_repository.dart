import '../../../core/persistence/preferences_service.dart';

/// Thin wrapper over [PreferencesService] for the tour's one persisted
/// flag, mirroring `SettingsRepository` exactly (design v1 §2.4/§5).
class TourRepository {
  const TourRepository(this._prefs);

  final PreferencesService _prefs;

  /// Whether the Home dashboard tour has already been shown. Means "we have
  /// shown this," not "the player finished it" — skipping and completing
  /// write the identical value (design v1 §2.4).
  bool get shown => _prefs.homeTourShown;

  Future<void> markShown() => _prefs.setHomeTourShown(true);
}
