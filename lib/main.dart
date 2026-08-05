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

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
      child: const App(),
    ),
  );
}
