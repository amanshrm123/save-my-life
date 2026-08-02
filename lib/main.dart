import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/monitoring/sentry_config.dart';
import 'core/monitoring/sentry_service.dart';

import 'app.dart';
import 'core/persistence/preferences_service.dart';
import 'features/ads/domain/ad_config.dart';
import 'features/ads/state/ad_providers.dart';
import 'features/onboarding/state/onboarding_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry early so startup errors are captured. Only attempted
  // at all when `kSentryEnabled` (no DSN define means no crash reporting,
  // never a crash on startup) — see sentry_config.dart's own doc comments
  // for why none of these three values are ever hardcoded.
  if (kSentryEnabled) {
    await SentryService.init(
      dsn: kSentryDsn,
      environment: kSentryEnvironment,
      release: kSentryRelease,
    );
  }

  final preferencesService = await PreferencesService.create();

  if (!kIsWeb) {
    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (_) {
      // Swallow — falls back to whatever `tz.local` already defaults to.
    }
  }

  // A plain `ProviderContainer` (rather than letting `ProviderScope` create
  // its own internally) so the AppLovin MAX ad service below can be warmed
  // eagerly, on this exact container, before `runApp` — `UncontrolledProviderScope`
  // then hands this same container to the widget tree, so the instance
  // warmed here is the one every screen actually reads from
  // `adServiceProvider`, not a throwaway second instance.
  final container = ProviderContainer(
    overrides: [
      preferencesServiceProvider.overrideWithValue(preferencesService),
    ],
    // `ProviderScope` wires this same handler internally (see its
    // `_ProviderScopeState.initState`) — mirrored by hand here so an
    // uncaught provider error still reaches `FlutterError.onError` (and any
    // future crash-reporting hook attached there) instead of silently
    // falling back to the current zone's default error handler.
    // ignore: invalid_use_of_internal_member
    onError: (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'riverpod'),
      );
    },
  );

  // AppLovin MAX SDK init (real-ad-serving pass) — only attempted at all
  // when `kAdsConfigured` (no SDK key, or a web build, means no ad network;
  // see `kAdsConfigured`'s own doc comment). Reading `adServiceProvider`
  // here constructs `AppLovinAdService` (its constructor fire-and-forgets
  // its own init chain: test-device IDs -> `AppLovinMAX.initialize` ->
  // first interstitial preload — see that class's doc comment for why this
  // one call site owns the WHOLE ordered sequence rather than splitting it
  // with a second, separate `initialize()` call from here). Deliberately
  // not awaited before `runApp`: ad-network init has no bearing on
  // first-frame rendering and must never delay startup. Doing this eagerly
  // here, rather than leaving the service to construct lazily on
  // `OutcomeCardScreen`'s first "Again" tap, gives the SDK the
  // ~run-1-and-2 window to actually finish loading before the interstitial
  // cadence's first trigger ever calls `showInterstitial()` — without this,
  // the first interstitial of every session was guaranteed to fail (init +
  // first preload started in the same tick as the show attempt).
  // Guarded: this runs before `runApp`, so a synchronous throw here (e.g.
  // the debug-only single-instance `assert` in `AppLovinAdService` tripping
  // after an unusual hot-restart) must never take the whole app down with
  // it — a degraded ad-less launch beats a black screen.
  if (kAdsConfigured) {
    try {
      container.read(adServiceProvider);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'ads'),
      );
    }
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const App()),
  );
}
