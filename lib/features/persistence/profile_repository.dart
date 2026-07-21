/// Persistence seam for player-profile state — Hive-backed in production
/// (`hive_profile_repository.dart`), swappable/mockable in tests
/// (docs/architecture/v1.md §1.4, v2 §3.4/§4: "extend the existing
/// ProfileRepository, don't add a second store").
///
/// This pass (docs/design/onboarding-flow-v1.md §3.3) only needs the
/// first-launch flag + optional display name. Later phases (outcome/run
/// persistence, settings, skins — v2 §4) extend this same interface rather
/// than introducing a second repository.
abstract class ProfileRepository {
  /// Whether the player has completed (or skipped past) onboarding at least
  /// once. Persisted; defaults to `false` on a fresh install.
  bool get isOnboardingComplete;

  /// The player's display name, or `null` if they skipped naming or never
  /// completed onboarding.
  String? get name;

  /// Marks onboarding complete and, if [name] is non-null, persists it.
  /// The only place `isOnboardingComplete` ever flips to `true`
  /// (onboarding-flow-v1.md §3.3) — called exclusively from
  /// `OnboardingController.submitName` (valid) or `skipNaming`.
  Future<void> markOnboardingComplete({String? name});
}
