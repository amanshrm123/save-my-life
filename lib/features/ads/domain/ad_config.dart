/// AppLovin MAX ad-network configuration — mirrors `kFbAppId`'s exact
/// convention (`lib/features/sharing/domain/share_target.dart` lines 38-43):
/// every value here is injected at build time only via `--dart-define`,
/// empty by default, and NEVER hardcoded with a real credential. A build
/// with no defines degrades gracefully (the SDK simply never initializes,
/// see [kAdsConfigured]) rather than crashing or shipping a placeholder
/// value that looks like a real key.
///
/// Consent/ATT (GDPR CMP, App Tracking Transparency) is explicitly out of
/// scope for this pass — AppLovin's own test ad units don't require either,
/// and nothing in this ad layer prompts for consent/tracking permission.
/// (The one exception: `ios/Runner/Info.plist`'s `NSUserTrackingUsageDescription`
/// key, a one-line native config addition so iOS's own ATT system prompt —
/// which the AppLovin SDK triggers automatically during `initialize()` — can
/// fire safely instead of the OS terminating the process for a missing usage
/// string. That's plain Info.plist config, not anything owned by this file.)
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// AppLovin MAX SDK key — `--dart-define=APPLOVIN_SDK_KEY=...`. Empty by
/// default; an empty key means the SDK is never initialized at all (see
/// [kAdsConfigured]) rather than being handed an empty string.
const String kAppLovinSdkKey = String.fromEnvironment('APPLOVIN_SDK_KEY');

/// AppLovin MAX interstitial ad unit ID —
/// `--dart-define=APPLOVIN_INTERSTITIAL_UNIT_ID=...`. Empty by default.
///
/// AppLovin publishes fixed, well-known PUBLIC TEST ad unit ID strings in
/// their own MAX integration docs specifically for exercising an
/// integration before a real account/ad unit exists. Deliberately left
/// empty-by-default here rather than hardcoded with a guessed value: these
/// published test IDs can change over time, and a wrong hardcoded "test ID"
/// string is indistinguishable at a glance from a real (if incorrect)
/// credential — safer to point a dev build at AppLovin's own current docs
/// ("Testing Your Integration" / test ad unit IDs) and pass whatever they
/// currently publish via `--dart-define=APPLOVIN_INTERSTITIAL_UNIT_ID=...`.
/// With no define, `AppLovinAdService.showInterstitial()` degrades to
/// `InterstitialResult.failedToLoad` rather than attempting to load with an
/// empty ad unit ID.
const String kAppLovinInterstitialUnitId = String.fromEnvironment(
  'APPLOVIN_INTERSTITIAL_UNIT_ID',
);

/// AppLovin MAX banner ad unit ID —
/// `--dart-define=APPLOVIN_BANNER_UNIT_ID=...`. Empty by default; see
/// [kAppLovinInterstitialUnitId]'s doc comment for why this isn't
/// pre-filled with a guessed test ID string. With no define, `BannerAdSlot`
/// renders its permanent empty placeholder rather than ever attempting to
/// create a banner with an empty ad unit ID.
const String kAppLovinBannerUnitId = String.fromEnvironment(
  'APPLOVIN_BANNER_UNIT_ID',
);

/// Registered test-device advertising ID (IDFA/IDFV) —
/// `--dart-define=APPLOVIN_TEST_DEVICE_ID=...`. Optional: AppLovin's own
/// published test ad unit IDs are documented to serve reliably without a
/// registered test device, so this is only useful if testing with a *real*
/// (non-test) ad unit ID in the SDK's test mode. Empty by default; only
/// applied (via `AppLovinMAX.setTestDeviceAdvertisingIds`) when non-empty.
const String kAppLovinTestDeviceAdvertisingId = String.fromEnvironment(
  'APPLOVIN_TEST_DEVICE_ID',
);

/// Gate: the SDK only initializes at all if an SDK key was supplied at
/// build time. Interstitial/banner ad unit IDs are checked independently of
/// this (and of each other) — one could be configured without the other,
/// e.g. a build that only wants interstitials and never mounts a banner.
///
/// Also explicitly excludes `kIsWeb` (matching this repo's established
/// platform-gating convention elsewhere, e.g.
/// `outcome_card_screen.dart`'s own `kIsWeb` check): `defaultTargetPlatform`
/// can still read as `android`/`iOS` on a mobile-web build, which would
/// otherwise let this gate slip through and attempt to build a real
/// `AndroidView`/`UiKitView` platform view or call the native AppLovin SDK
/// method channel on a target that has neither.
bool get kAdsConfigured => !kIsWeb && kAppLovinSdkKey.isNotEmpty;
