import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/ads/application/applovin_ad_service.dart';
import 'package:timing_tap/features/ads/application/ad_service.dart';
import 'package:timing_tap/features/ads/domain/ad_config.dart';

/// `AppLovinAdService` (real-ad-serving pass). These tests run with no
/// `--dart-define`s (the normal targeted test-run shape for this repo), so
/// `kAppLovinInterstitialUnitId`/`kAppLovinBannerUnitId`/`kAppLovinSdkKey`
/// are all empty exactly like a real dev build with no ad credentials
/// configured yet — that's the realistic, always-exercised path here.
///
/// The completer-mapping/guard tests below deliberately drive
/// `handleInterstitialHidden`/`handleInterstitialLoadFailed`/
/// `handleInterstitialDisplayFailed` directly (rather than through a full
/// `showInterstitial()` round trip) via the `@visibleForTesting` seam —
/// `showInterstitial()` itself always short-circuits to `failedToLoad`
/// immediately whenever the ad unit ID is empty (tested separately below),
/// so it can never reach the SDK's real ready-check/show path without a
/// `--dart-define` this suite doesn't (and shouldn't) require. The handler
/// methods are exactly what `AppLovinMAX`'s process-global listener
/// callbacks invoke in the real flow, so testing them directly exercises
/// the same completer-resolution/guard logic without needing to fake the
/// SDK's platform-channel plumbing.
///
/// One SHARED `service` instance for the whole file (`setUpAll`), not one
/// per test: `AppLovinAdService` now `assert`s it's constructed at most
/// once (real-ad-serving pass review, fix 15) — `AppLovinMAX`'s ad-event
/// listener is a process-global static, so a second instance would
/// silently steal the first's listener registration. A `test` file runs
/// its `test()`/`group()` bodies in one shared isolate, so constructing a
/// fresh instance per test (the old shape of this file) would trip that
/// `assert` from the second test onward.
void main() {
  late AppLovinAdService service;

  setUpAll(() {
    service = AppLovinAdService();
  });

  test('rendersOwnUi is false — a real MAX interstitial is the SDK\'s own '
      'native overlay, not rendered through this app\'s widget tree', () {
    expect(service.rendersOwnUi, isFalse);
  });

  test(
    'showInterstitial() resolves failedToLoad immediately when the '
    'interstitial ad unit ID dart-define is unset — never blocks waiting '
    'on a load',
    () async {
      expect(kAppLovinInterstitialUnitId, isEmpty, reason: 'no dart-define in this test run');

      final result = await service.showInterstitial();

      expect(result, InterstitialResult.failedToLoad);
    },
  );

  test(
    'REGRESSION: handleInterstitialDisplayed() does NOT resolve the '
    'pending completer — MAX fires this when the overlay merely *appears*, '
    'not when the player dismisses it; resolving here (the old, buggy '
    'behavior) let "Again" proceed to the next run\'s countdown while the '
    'ad was still fullscreen on top of it',
    () {
      final completer = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(completer);

      service.handleInterstitialDisplayed();

      expect(
        completer.isCompleted,
        isFalse,
        reason: 'only handleInterstitialHidden() should resolve `shown`',
      );
    },
  );

  test(
    'handleInterstitialHidden() resolves the pending completer to shown — '
    'the correct "player is actually done with the ad" signal (fix 2)',
    () async {
      final completer = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(completer);

      service.handleInterstitialHidden();

      expect(completer.isCompleted, isTrue);
      expect(await completer.future, InterstitialResult.shown);
    },
  );

  test(
    'handleInterstitialLoadFailed() resolves the pending completer to failedToLoad',
    () async {
      final completer = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(completer);

      service.handleInterstitialLoadFailed();

      expect(completer.isCompleted, isTrue);
      expect(await completer.future, InterstitialResult.failedToLoad);
    },
  );

  test(
    'handleInterstitialDisplayFailed() resolves the pending completer to failedToLoad',
    () async {
      final completer = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(completer);

      service.handleInterstitialDisplayFailed();

      expect(completer.isCompleted, isTrue);
      expect(await completer.future, InterstitialResult.failedToLoad);
    },
  );

  test(
    'REGRESSION: a completer already completed by one event is not '
    'double-completed by an overlapping/duplicate second event — '
    'AppLovinMAX\'s listener callbacks are process-global, not scoped to '
    'one showInterstitial() call, so this guard is load-bearing',
    () async {
      final completer = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(completer);

      service.handleInterstitialHidden();
      expect(await completer.future, InterstitialResult.shown);

      // A second, overlapping native event firing for the same (already
      // resolved) slot must never throw, and must never attempt to
      // re-complete the already-completed completer.
      expect(() => service.handleInterstitialDisplayFailed(), returnsNormally);
      expect(() => service.handleInterstitialLoadFailed(), returnsNormally);
      // Still resolved to the FIRST event's result — never overwritten.
      expect(await completer.future, InterstitialResult.shown);
    },
  );

  test(
    'REGRESSION: an overlapping showInterstitial() call never disturbs a '
    'genuinely-pending prior call\'s completer — with no ad unit ID '
    'dart-define configured, the empty-ad-unit-id gate short-circuits '
    'BEFORE ever touching `_pendingInterstitial`, so a manually-seeded '
    'pending completer (simulating call #1 still in flight) must come out '
    'the other side of a second showInterstitial() call (#2) completely '
    'untouched',
    () async {
      final firstCallCompleter = Completer<InterstitialResult>();
      service.debugSetPendingInterstitial(firstCallCompleter);

      final secondCallResult = await service.showInterstitial();

      expect(secondCallResult, InterstitialResult.failedToLoad);
      expect(
        firstCallCompleter.isCompleted,
        isFalse,
        reason: 'the second call\'s short-circuit must not resolve/clobber the first call\'s completer',
      );

      // Prove the first call's completer is still genuinely wired up —
      // resolving it now (as a real onAdHidden event eventually would)
      // still works exactly as if the second call had never happened.
      service.handleInterstitialHidden();
      expect(await firstCallCompleter.future, InterstitialResult.shown);
    },
  );

  test(
    'handleInterstitialHidden() does not throw even with no interstitial '
    'ad unit ID configured (it is a no-op preload trigger in that case)',
    () {
      expect(() => service.handleInterstitialHidden(), returnsNormally);
    },
  );

  test('showRewarded() is a trivial failedToLoad stub — rewarded is '
      'founder-descoped entirely and nothing calls this', () async {
    final result = await service.showRewarded();
    expect(result, RewardedResult.failedToLoad);
  });

  test(
    'REGRESSION: constructing a SECOND AppLovinAdService trips the '
    'single-instance assert — proves the guard documented on the '
    'constructor is actually load-bearing (in a stripped-assert release '
    'build this would instead silently steal the shared listener '
    'registration, which is the documented, accepted degrade — see that '
    'constructor\'s doc comment)',
    () {
      expect(() => AppLovinAdService(), throwsA(isA<AssertionError>()));
    },
  );

  test(
    'REGRESSION: a late native callback arriving AFTER the 8s timeout has '
    'already resolved the caller is safely ignored — no double-completion, '
    'no throw, and it does not resurrect/clear an unrelated later call\'s '
    'pending slot',
    () {
      fakeAsync((async) {
        final completer = Completer<InterstitialResult>();
        service.debugSetPendingInterstitial(completer);

        InterstitialResult? resolved;
        service.debugAwaitPendingWithTimeout(completer).then((r) => resolved = r);

        async.elapse(const Duration(seconds: 9));
        expect(resolved, InterstitialResult.failedToLoad);
        expect(service.debugHasPendingInterstitial, isFalse);

        // The real native callback for that same (now-timed-out) show
        // attempt finally arrives late. Must not throw, must not affect
        // `resolved` (already settled to failedToLoad), and must leave no
        // pending slot behind for a future call to trip over.
        expect(() => service.handleInterstitialHidden(), returnsNormally);
        expect(resolved, InterstitialResult.failedToLoad);
        expect(service.debugHasPendingInterstitial, isFalse);

        // The original completer itself is simply left forever un-
        // completed (nothing re-derives a value from it) — not an error
        // state, just an orphaned object that becomes eligible for GC.
        expect(completer.isCompleted, isFalse);
      });
    },
  );

  test(
    'REGRESSION: a showInterstitial() attempt with no real native callback '
    'ever firing resolves failedToLoad after the timeout, instead of '
    'wedging the caller forever (fix 5) — also clears the pending slot so '
    'a later call isn\'t permanently bricked for the rest of the session',
    () {
      fakeAsync((async) {
        final completer = Completer<InterstitialResult>();
        service.debugSetPendingInterstitial(completer);
        expect(service.debugHasPendingInterstitial, isTrue);

        InterstitialResult? resolved;
        service.debugAwaitPendingWithTimeout(completer).then((r) => resolved = r);

        async.elapse(const Duration(seconds: 7));
        expect(resolved, isNull, reason: 'must not resolve before the 8s timeout');

        async.elapse(const Duration(seconds: 2));
        expect(resolved, InterstitialResult.failedToLoad);
        expect(
          service.debugHasPendingInterstitial,
          isFalse,
          reason: 'the timeout must clear _pendingInterstitial, not just resolve its own Future',
        );
      });
    },
  );
}
