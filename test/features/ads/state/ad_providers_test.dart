import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/ads/application/applovin_ad_service.dart';
import 'package:timing_tap/features/ads/application/fake_ad_service.dart';
import 'package:timing_tap/features/ads/domain/ad_config.dart';
import 'package:timing_tap/features/ads/state/ad_providers.dart';

/// `adServiceProvider` (real-ad-serving pass): selects `AppLovinAdService`
/// when `kAdsConfigured` (an SDK key was supplied at build time via
/// `--dart-define=APPLOVIN_SDK_KEY=...`), else `FakeAdService` — mirroring
/// the `FB_APP_ID`-style "empty define == feature off" gate used elsewhere.
///
/// This suite runs with no dart-defines (the normal targeted test-run shape
/// for this repo), so `kAdsConfigured` is false here — the real
/// `adServiceProvider` can only ever be observed taking the `FakeAdService`
/// branch in THIS test run. The `kAdsConfigured == true` branch is exercised
/// instead via `createAdService(true)` directly below: `kAdsConfigured`
/// itself is a genuine build-time `const`-derived gate (mirrors
/// `kFbAppId`'s own safety convention, `ad_config.dart`) that this suite
/// deliberately never weakens/overrides just to make it unit-testable — the
/// selection *logic* was extracted into `createAdService` specifically so
/// both branches stay directly, honestly testable without that trade-off.
void main() {
  test(
    'with no dart-define supplied, adServiceProvider resolves FakeAdService '
    '(the realistic default-build path)',
    () {
      expect(kAdsConfigured, isFalse, reason: 'no --dart-define in this test run');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(adServiceProvider), isA<FakeAdService>());
    },
  );

  group('createAdService (both branches of the kAdsConfigured selection)', () {
    test('createAdService(false) resolves FakeAdService', () {
      expect(createAdService(false), isA<FakeAdService>());
    });

    test(
      'createAdService(true) resolves AppLovinAdService — the one branch '
      '`adServiceProvider` itself can never exercise in this dart-define-'
      'less test run',
      () {
        expect(createAdService(true), isA<AppLovinAdService>());
      },
    );
  });
}
