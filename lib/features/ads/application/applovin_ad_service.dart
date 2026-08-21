import 'dart:async';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/foundation.dart';

import '../domain/ad_config.dart';
import 'ad_service.dart';

/// Real AppLovin MAX-backed `AdService` (real-ad-serving pass) — only ever
/// constructed by `adServiceProvider` when [kAdsConfigured]. `rendersOwnUi
/// => false`: a MAX interstitial is a native full-screen overlay the SDK
/// itself displays via `AppLovinMAX.showInterstitial`, NOT rendered through
/// this app's own widget tree the way `FakeAdService`'s `InterstitialScreen`
/// is.
///
/// Must be constructed at most once and kept alive for the app's lifetime
/// (mirrors `adGateProvider`'s own kept-alive `Provider` pattern,
/// `ad_providers.dart`) — `AppLovinMAX`'s ad listeners are process-global
/// statics, not scoped per-instance/per-call, so a second instance
/// registering its own listener would silently clobber the first
/// registration rather than erroring. `main.dart` is the single owner of
/// eagerly constructing this (via one `adServiceProvider` read right after
/// startup), and this constructor also owns the WHOLE SDK init ordering
/// itself (test-device IDs -> SDK init -> first preload) — nothing else in
/// this app calls `AppLovinMAX.initialize`/`setTestDeviceAdvertisingIds`, so
/// there is exactly one place the ordering can be gotten wrong.
class AppLovinAdService implements AdService {
  AppLovinAdService() {
    assert(
      !_listenersRegistered,
      'AppLovinAdService must only be constructed once — AppLovinMAX\'s ad '
      'listeners are process-global statics, so a second instance would '
      'silently steal the first instance\'s listener registration, and a '
      'second instance\'s showInterstitial() would then set a completer '
      'that NOTHING could ever resolve (since listeners stay bound to the '
      'first instance\'s closures) — worse than not guarding at all.',
    );
    _listenersRegistered = true;
    AppLovinMAX.setInterstitialListener(
      InterstitialListener(
        onAdLoadedCallback: (ad) {},
        onAdLoadFailedCallback: (adUnitId, error) =>
            handleInterstitialLoadFailed(),
        onAdDisplayedCallback: (ad) => handleInterstitialDisplayed(),
        onAdDisplayFailedCallback: (ad, error) =>
            handleInterstitialDisplayFailed(),
        onAdClickedCallback: (ad) {},
        onAdHiddenCallback: (ad) => handleInterstitialHidden(),
      ),
    );
    // Fire-and-forget: nothing in this constructor's caller (the
    // `adServiceProvider` read) should block on ad-network init.
    unawaited(_init());
  }

  /// The one in-flight `showInterstitial()` call's completer, if any.
  /// Deliberately at most one at a time (see the early-return guard in
  /// [showInterstitial]) — this app never attempts to show a second
  /// interstitial while one is already in flight.
  Completer<InterstitialResult>? _pendingInterstitial;

  /// `AppLovinMAX`'s ad-event listener is a process-global static, set once
  /// for the whole app rather than per-instance — this guards (via the
  /// `assert` in the constructor above) against a second `AppLovinAdService`
  /// (shouldn't happen given the kept-alive provider, but defended against
  /// explicitly) silently replacing the first registration, which would
  /// otherwise be a very confusing bug to chase down later. An `assert`
  /// rather than a silent no-op: a silent skip would leave a second
  /// instance's `showInterstitial()` setting a completer nothing could ever
  /// resolve — strictly worse than failing loudly in debug builds.
  static bool _listenersRegistered = false;

  /// Completes once `AppLovinMAX.initialize()` has settled — successfully or
  /// not; a failed init still needs to unblock `adSdkReadyProvider`
  /// (`ad_providers.dart`), which only cares whether the SDK call was
  /// attempted-and-settled, not whether it succeeded (a failed init degrades
  /// the same way a real network hiccup would: the native ad view attempts
  /// to load and gracefully reports no fill, rather than this app hand-
  /// rolling its own retry on top).
  final Completer<void> _sdkInitialized = Completer<void>();

  /// Test/gating seam for [adSdkReadyProvider] — see that provider's doc
  /// comment for why `BannerAdSlot` needs this signal.
  Future<void> get sdkInitialized => _sdkInitialized.future;

  /// Safety net bounding ONLY the pre-display window — the TOCTOU gap
  /// between the `isInterstitialReady` check and the native overlay
  /// actually appearing (see [showInterstitial]'s doc comment). Cancelled
  /// and replaced by [_postDisplayTimeout] the instant
  /// [handleInterstitialDisplayed] fires (real-ad-serving pass review, fix
  /// 9) — a single timer covering the whole show used to also cover
  /// however long the player spent actually watching the ad, and fired
  /// mid-display on any creative longer than this, wrongly reporting
  /// `failedToLoad` for an ad the player was still looking at.
  static const Duration _preDisplayTimeout = Duration(seconds: 8);

  /// Ultimate safety net once the overlay is confirmed on screen — only
  /// guards against a genuinely dropped `onAdHidden` callback (MAX is
  /// documented to always fire it; this is defense-in-depth, not an
  /// expected path), never against ordinary viewing time. Deliberately
  /// generous so it can never race a real player actually watching the ad.
  static const Duration _postDisplayTimeout = Duration(minutes: 5);

  /// The single show attempt's pending timeout — [_preDisplayTimeout]
  /// until [handleInterstitialDisplayed] rearms it as [_postDisplayTimeout],
  /// cancelled outright once any handler resolves the completer via
  /// [_completeIfPending].
  Timer? _showTimeoutTimer;

  Future<void> _init() async {
    // Order matters here: `AppLovinMAX`'s plugin consumes
    // `testDeviceAdvertisingIdsToSet` INSIDE `initialize()` and clears it
    // immediately after, so this must run BEFORE `initialize()`, never
    // after — this is also why `main.dart` no longer calls
    // `AppLovinMAX.initialize()` itself at all: this constructor is now the
    // sole owner of the entire ordered sequence, so there's no second call
    // site that could race ahead of this one.
    // `set*` calls below (`setTestDeviceAdvertisingIds`,
    // `setTermsAndPrivacyPolicyFlowEnabled`, `setPrivacyPolicyUrl`,
    // `setTermsOfServiceUrl`) are all fire-and-forget `void` methods that
    // internally call `MethodChannel.invokeMethod` WITHOUT exposing the
    // resulting Future — so a failure (e.g. no platform channel/binding
    // registered, exactly a plain `test()`/`setUpAll` environment with no
    // `TestWidgetsFlutterBinding`) surfaces as an unhandled async Zone
    // error, not a synchronously-catchable exception at the call site. A
    // plain `try/catch` around them (as already used for `initialize()`
    // below, which properly returns and is awaited) cannot see that error
    // at all. `runZonedGuarded` routes it to the same best-effort no-op
    // degrade this whole init chain already uses everywhere else.
    runZonedGuarded(() {
      // Order matters here: `AppLovinMAX`'s plugin consumes
      // `testDeviceAdvertisingIdsToSet` INSIDE `initialize()` and clears it
      // immediately after, so this must run BEFORE `initialize()` below,
      // never after — this is also why `main.dart` no longer calls
      // `AppLovinMAX.initialize()` itself at all: this constructor is now
      // the sole owner of the entire ordered sequence, so there's no
      // second call site that could race ahead of this one.
      if (kAppLovinTestDeviceAdvertisingId.isNotEmpty) {
        AppLovinMAX.setTestDeviceAdvertisingIds([
          kAppLovinTestDeviceAdvertisingId,
        ]);
      }

      // Enables AppLovin's own bundled Terms and Privacy Policy Flow
      // (real-ad-serving pass review, fix 10) — like the test-device IDs
      // above, MUST be set before `initialize()` below. This is what
      // actually shows the iOS App Tracking Transparency system prompt and
      // an EEA/UK consent (CMP) flow when applicable; neither happens on
      // its own just because `Info.plist` declares
      // `NSUserTrackingUsageDescription` — see `ad_config.dart`'s doc
      // comment for the (corrected) full explanation.
      AppLovinMAX.setTermsAndPrivacyPolicyFlowEnabled(true);
      AppLovinMAX.setPrivacyPolicyUrl(kPrivacyPolicyUrl);
      AppLovinMAX.setTermsOfServiceUrl(kTermsOfServiceUrl);
    }, (error, stack) {});

    try {
      // Wrapped in try/catch defensively: with no ad network reachable (or,
      // in a plain unit-test environment, no platform channel registered at
      // all), this must degrade quietly rather than leave an unhandled
      // async error from this fire-and-forget init chain.
      await AppLovinMAX.initialize(kAppLovinSdkKey);
    } catch (_) {
      // Best-effort — `showInterstitial()`'s own readiness check simply
      // keeps reporting "not ready" and degrades to `failedToLoad`.
    } finally {
      if (!_sdkInitialized.isCompleted) _sdkInitialized.complete();
    }
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (kAppLovinInterstitialUnitId.isEmpty) return;
    AppLovinMAX.loadInterstitial(kAppLovinInterstitialUnitId);
  }

  void _completeIfPending(InterstitialResult result) {
    final completer = _pendingInterstitial;
    _pendingInterstitial = null;
    _showTimeoutTimer?.cancel();
    _showTimeoutTimer = null;
    // Note: the `!completer.isCompleted` half of this guard is currently
    // unreachable in production — this method is the only place that both
    // reads AND nulls `_pendingInterstitial`, runs synchronously (never
    // re-entered mid-call), and a second overlapping native event finds
    // `_pendingInterstitial` already null (so `completer` is null and the
    // whole branch is skipped) rather than ever reaching a
    // *non-null-but-already-completed* completer. Kept anyway as cheap
    // insurance against a future refactor that might complete this
    // completer from somewhere else before reaching here — if that never
    // happens, this check is a no-op today, not the load-bearing guard it
    // might look like at a glance.
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  // --- Named (rather than anonymous-closure-only) handlers so unit tests
  // can simulate AppLovin's ad-lifecycle events directly, without needing
  // to fake the SDK's platform-channel plumbing.

  @visibleForTesting
  void handleInterstitialDisplayed() {
    // Deliberately does NOT resolve the pending completer. MAX fires this
    // the instant the full-screen overlay *appears*, not when the player
    // dismisses it — completing `shown` here (the old, buggy behavior) let
    // `_onAgain` immediately proceed to `_goToPlay` (arming the run's 3-2-1
    // countdown/haptics) while the ad was still fullscreen on top of it.
    // The real "the player is done with the ad" signal is
    // `onAdHiddenCallback` (`handleInterstitialHidden`), which now owns the
    // completion instead. This handler only marks "display started" (no-op
    // today beyond documenting that), so a later `onAdDisplayFailed` for the
    // same show attempt is still handled correctly by
    // `handleInterstitialDisplayFailed`, not racing a completer that
    // already resolved on display.
    //
    // It DOES rearm the safety-net timer to [_postDisplayTimeout] (fix 9):
    // the overlay is confirmed on screen now, so the [_preDisplayTimeout]
    // armed in [showInterstitial] — which only ever existed to bound the
    // pre-display TOCTOU gap — must stop ticking through the player's
    // actual viewing time.
    final completer = _pendingInterstitial;
    if (completer != null) {
      _armShowTimeout(completer, _postDisplayTimeout);
    }
  }

  @visibleForTesting
  void handleInterstitialLoadFailed() =>
      _completeIfPending(InterstitialResult.failedToLoad);

  @visibleForTesting
  void handleInterstitialDisplayFailed() =>
      _completeIfPending(InterstitialResult.failedToLoad);

  @visibleForTesting
  void handleInterstitialHidden() {
    // The overlay is actually gone now — this is the correct point to
    // unblock a pending `showInterstitial()` caller with `shown` (fix 2,
    // real-ad-serving pass review): resolving here instead of on-displayed
    // means `_onAgain`'s `_goToPlay` (and its 3-2-1 countdown/haptics) only
    // ever starts once the ad has genuinely closed, giving the player the
    // "get ready" beat back.
    _completeIfPending(InterstitialResult.shown);

    // Preload the next interstitial the instant this one closes —
    // deliberately never a queue of more than one preloaded ad: this
    // bounds the SDK's own native-side cached-creative memory to at most a
    // single interstitial regardless of how many runs the player completes
    // in one long-lived, RAM-resident session (CLAUDE.md rule 7). The
    // SDK's own built-in retry/backoff handles a load failure from here —
    // this app never hand-rolls a retry timer on top of it.
    _loadInterstitial();
  }

  /// Test-only seam: lets a unit test set up a pending completer to
  /// exercise [handleInterstitialHidden]/[handleInterstitialLoadFailed]/
  /// [handleInterstitialDisplayFailed]'s completion mapping and the
  /// already-completed guard, without needing a real (mocked) ad-ready
  /// round trip through `showInterstitial()`.
  @visibleForTesting
  void debugSetPendingInterstitial(Completer<InterstitialResult> completer) {
    _pendingInterstitial = completer;
  }

  /// Test-only seam: whether a `showInterstitial()` call is currently
  /// considered in flight — lets a unit test confirm the timeout path
  /// actually clears this, rather than just observing the returned Future's
  /// value in isolation.
  @visibleForTesting
  bool get debugHasPendingInterstitial => _pendingInterstitial != null;

  /// Test-only seam exercising the exact [_preDisplayTimeout] arming
  /// [showInterstitial] applies to a real show attempt's completer, without
  /// needing to drive it through the ad-unit-id/ready-check gates that
  /// short-circuit immediately whenever no `--dart-define` is supplied (the
  /// normal targeted test-run shape for this repo).
  @visibleForTesting
  Future<InterstitialResult> debugArmPreDisplayTimeout(
    Completer<InterstitialResult> completer,
  ) {
    _pendingInterstitial = completer;
    _armShowTimeout(completer, _preDisplayTimeout);
    return completer.future;
  }

  /// Test-only seam exercising the exact [_postDisplayTimeout] rearming
  /// [handleInterstitialDisplayed] applies — lets a unit test drive the
  /// post-display safety net directly, without needing a full
  /// pre-display -> displayed round trip first.
  @visibleForTesting
  Future<InterstitialResult> debugArmPostDisplayTimeout(
    Completer<InterstitialResult> completer,
  ) {
    _pendingInterstitial = completer;
    _armShowTimeout(completer, _postDisplayTimeout);
    return completer.future;
  }

  @override
  bool get rendersOwnUi => false;

  @override
  Future<InterstitialResult> showInterstitial() async {
    if (kAppLovinInterstitialUnitId.isEmpty) {
      return InterstitialResult.failedToLoad;
    }
    // Never block the "Again" tap waiting on a second concurrent show
    // attempt — shouldn't happen given `OutcomeCardScreen`'s own
    // `_navigating` guard, but defended against here too since this
    // service could in principle be called from more than one call site
    // later.
    if (_pendingInterstitial != null) {
      return InterstitialResult.failedToLoad;
    }

    bool ready;
    try {
      ready =
          await AppLovinMAX.isInterstitialReady(kAppLovinInterstitialUnitId) ??
          false;
    } catch (_) {
      ready = false;
    }
    // Not currently loaded/ready — resolve immediately rather than
    // blocking the "Again" tap waiting on a load; the SDK's own built-in
    // retry/backoff (not hand-rolled here) keeps trying in the background
    // via the preload triggered from `handleInterstitialHidden`/`_init`.
    if (!ready) {
      return InterstitialResult.failedToLoad;
    }

    final completer = Completer<InterstitialResult>();
    _pendingInterstitial = completer;
    // `showInterstitial` is fire-and-forget on the plugin side: there is a
    // TOCTOU gap between the `isInterstitialReady` check above and this
    // call (the ad can expire in between), and a rejected/dropped platform-
    // channel call surfaces no exception here. If no native callback ever
    // fires as a result (expired ad, no foreground activity, channel
    // error), nothing would otherwise ever resolve `completer` — wedging
    // this caller forever (`_navigating` stuck true on `OutcomeCardScreen`)
    // and leaving `_pendingInterstitial` non-null so every later
    // `showInterstitial()` call this session immediately returns
    // `failedToLoad` too. [_armShowTimeout] bounds that risk — only for
    // this pre-display window ([_preDisplayTimeout]); once
    // [handleInterstitialDisplayed] confirms the overlay is actually on
    // screen, it rearms this same timer to [_postDisplayTimeout] instead,
    // so the clock never runs through the player's real viewing time
    // (fix 9 — the single-timeout version of this used to do exactly that).
    _armShowTimeout(completer, _preDisplayTimeout);
    AppLovinMAX.showInterstitial(kAppLovinInterstitialUnitId);
    return completer.future;
  }

  /// Arms (replacing any existing timer) the safety-net timeout that
  /// resolves [completer] to `failedToLoad` after [duration] if nothing
  /// else has resolved it by then — used for both [_preDisplayTimeout] (in
  /// [showInterstitial]) and [_postDisplayTimeout] (in
  /// [handleInterstitialDisplayed]), so there is always at most one timer
  /// ticking per in-flight show attempt, never a stale pre-display one
  /// still running alongside a post-display one.
  void _armShowTimeout(Completer<InterstitialResult> completer, Duration duration) {
    _showTimeoutTimer?.cancel();
    _showTimeoutTimer = Timer(duration, () {
      // Only clear the shared `_pendingInterstitial` slot if it's still
      // pointing at THIS completer — defends against clobbering a
      // genuinely newer in-flight call in the (currently unreachable in
      // production, since only one call is ever in flight at a time) case
      // where a stale timeout fires after a newer completer has already
      // taken the slot.
      if (identical(_pendingInterstitial, completer)) {
        _pendingInterstitial = null;
        _showTimeoutTimer = null;
      }
      if (!completer.isCompleted) {
        completer.complete(InterstitialResult.failedToLoad);
      }
    });
  }

  /// Rewarded is founder-descoped entirely (see `AdService.showRewarded`'s
  /// own doc comment on the interface) — nothing calls this; kept trivially
  /// implemented so the interface stays satisfiable.
  @override
  Future<RewardedResult> showRewarded() async => RewardedResult.failedToLoad;
}
