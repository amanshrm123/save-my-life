import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ad_service.dart';
import '../application/applovin_ad_service.dart';
import '../application/fake_ad_service.dart';
import '../domain/ad_config.dart';

/// The `kAdsConfigured` branch selection, extracted into a plain function
/// taking the decision as a parameter — this is what actually lets both
/// branches be unit-tested directly (`ad_providers_test.dart`) without a
/// `--dart-define=APPLOVIN_SDK_KEY=...` test run. `kAdsConfigured` itself
/// stays a genuine build-time `const`-derived gate (mirrors `kFbAppId`'s own
/// safety convention, `ad_config.dart`) and is never weakened/overridden
/// just for testability — only this selection *function* is exposed for
/// tests, not the gate itself.
@visibleForTesting
AdService createAdService(bool adsConfigured) =>
    adsConfigured ? AppLovinAdService() : FakeAdService();

/// Kept-alive for the whole app session — a single `AdService` instance
/// (architecture v3 §5), never `.autoDispose`. Real AppLovin MAX ad serving
/// (`AppLovinAdService`) is used only when [kAdsConfigured] (an SDK key was
/// supplied at build time via `--dart-define`, mirroring the `FB_APP_ID`-
/// style gate used elsewhere); otherwise `FakeAdService` keeps dev/test
/// builds working exactly as before, with no ad-network dependency at all.
///
/// Warmed EAGERLY at app startup (`main.dart`, right after the startup init
/// sequence) rather than left to construct lazily on the first read — a
/// lazily-constructed `AppLovinAdService` starts its SDK init/first-preload
/// in the same tick as the very first `showInterstitial()` attempt, which
/// can never resolve "ready" in time (the first interstitial of every
/// session was guaranteed to fail). Eager construction gives the SDK the
/// ~run-1-and-2 window before the interstitial cadence first fires.
final Provider<AdService> adServiceProvider = Provider<AdService>(
  (ref) => createAdService(kAdsConfigured),
);

/// Resolves once the AppLovin MAX SDK's `initialize()` call has settled
/// (successfully or not) — gates `BannerAdSlot`'s real `MaxAdView` mount
/// (real-ad-serving pass review, fix 6): `MaxAdView` requires the SDK to
/// already be initialized, and mounting it any earlier means its native ad
/// view's own immediate internal `loadAd()` call is silently dropped with no
/// retry (the slot itself never remounts). Resolves immediately when ads
/// aren't configured at all — `BannerAdSlot` never reaches the branch that
/// reads this in that case anyway (its own `kAppLovinBannerUnitId` check
/// short-circuits to the placeholder first).
final FutureProvider<void> adSdkReadyProvider = FutureProvider<void>((ref) {
  if (!kAdsConfigured) return Future<void>.value();
  final service = ref.watch(adServiceProvider);
  return service is AppLovinAdService
      ? service.sdkInitialized
      : Future<void>.value();
});
