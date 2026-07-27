import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/persistence/preferences_service.dart';
import 'features/onboarding/state/onboarding_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencesService = await PreferencesService.create();

  // `timezone` initialised exactly once, here, before any scheduling call
  // (architecture v3 §8/§11 risk 1). Harmless on web/iOS too (just unused
  // there — `ReminderService` is a no-op off Android), so no platform
  // branch is needed for this step itself.
  //
  // `tz.local` defaults to UTC until a location is explicitly set — without
  // this, "19:00 local" was actually firing at 19:00 UTC for any non-UTC
  // device. Look up the device's real IANA zone (`flutter_timezone`) and
  // point `tz.local` at it; swallow failures (best-effort — worst case the
  // reminder fires on UTC wall-clock instead of crashing startup).
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
