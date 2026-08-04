import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/monitoring/sentry_service.dart';

import 'app.dart';
import 'core/persistence/preferences_service.dart';
import 'features/onboarding/state/onboarding_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry early so startup errors are captured. DSN and other
  // settings are supplied via --dart-define in CI or local runs.
  final dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  final env = const String.fromEnvironment('ENV', defaultValue: 'production');
  final release = const String.fromEnvironment('RELEASE', defaultValue: '1.0.0+1');

  if (dsn.isNotEmpty) {
    await SentryService.init(dsn: dsn, environment: env, release: release);
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
