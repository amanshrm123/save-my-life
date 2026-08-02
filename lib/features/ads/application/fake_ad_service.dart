import 'ad_service.dart';

/// Stubbed `AdService` (architecture v3 §1 item 1 / §5): no real ad-network
/// call at all — `showInterstitial()` resolves near-instantly to whichever
/// result [forceFailure] currently selects, so a caller can decide whether to
/// push the real `InterstitialScreen` (5.1) or the `AdFailedView` (8.3). The
/// interstitial's own countdown/close-X timer lives in the screen widget
/// itself, not here — this class only simulates "did an ad become
/// available," the way a real ad SDK's load call would.
class FakeAdService implements AdService {
  /// Toggle to exercise the 8.3 ad-failed path in dev/tests; defaults to
  /// always "succeeding" so the everyday interstitial flow just works.
  bool forceFailure = false;

  /// Unchanged from before the real-ad-serving pass: the fake interstitial
  /// is this app's own `InterstitialScreen`, pushed by the caller exactly
  /// as it always was.
  @override
  bool get rendersOwnUi => true;

  @override
  Future<InterstitialResult> showInterstitial() async {
    return forceFailure ? InterstitialResult.failedToLoad : InterstitialResult.shown;
  }

  /// Not called by any screen this pass (founder-resolved: rewarded is
  /// skipped entirely, architecture §1 item 9) — kept trivially implemented
  /// so the interface stays satisfiable.
  @override
  Future<RewardedResult> showRewarded() async {
    return forceFailure ? RewardedResult.failedToLoad : RewardedResult.completed;
  }
}
