/// Result of a rewarded-ad view — credit is only ever granted for
/// `completed` (architecture v3 §5): early dismissal never grants a reward.
/// Not driven by any screen this pass (rewarded is founder-skipped, §1 item
/// 9) — kept on the interface only so a future pass can wire it in with zero
/// interface churn.
enum RewardedResult { completed, dismissedEarly, failedToLoad }

/// Result of an interstitial view (architecture v3 §5): unlike rewarded,
/// there is nothing to "earn," so `failedToLoad` is the only distinguished
/// outcome the caller needs — a successful view and an early close both just
/// mean "continue."
enum InterstitialResult { shown, failedToLoad }

/// Ad seams (architecture v3 §1 item 1 / §5) — originally **no real ad SDK**
/// behind this; the real-ad-serving pass adds `AppLovinAdService` alongside
/// the original `FakeAdService`, both behind this same interface with zero
/// UI/flow churn beyond the `rendersOwnUi` branch below.
abstract class AdService {
  /// Whether this implementation renders its own full-screen interstitial
  /// UI through this app's widget tree (`true` — `FakeAdService`'s
  /// `InterstitialScreen`/`AdFailedView` flow, unchanged from before) or the
  /// ad SDK itself already displayed a native full-screen overlay before
  /// `showInterstitial()` resolved (`false` — `AppLovinAdService`, a real
  /// MAX interstitial). Callers (`outcome_card_screen.dart`) branch on this
  /// to decide whether a `shown` result still needs `InterstitialScreen`
  /// pushed, or should go straight to the next run.
  bool get rendersOwnUi;

  Future<InterstitialResult> showInterstitial();

  /// Stays on the interface for a future pass — nothing calls this today
  /// (founder-resolved: rewarded is skipped entirely this pass).
  Future<RewardedResult> showRewarded();
}
