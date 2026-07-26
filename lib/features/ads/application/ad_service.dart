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

/// Ad seams (architecture v3 §1 item 1 / §5) — **no real ad SDK** behind
/// this; `FakeAdService` is the only implementation this pass. Interface-
/// first so a real network swaps in later with zero UI/flow churn.
abstract class AdService {
  Future<InterstitialResult> showInterstitial();

  /// Stays on the interface for a future pass — nothing calls this today
  /// (founder-resolved: rewarded is skipped entirely this pass).
  Future<RewardedResult> showRewarded();
}
