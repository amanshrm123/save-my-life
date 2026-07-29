import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/features/avatar/state/avatar_providers.dart';
import 'package:timing_tap/features/notifications/application/reminder_service.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_noop.dart';
import 'package:timing_tap/features/notifications/state/reminder_providers.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/progression/state/stats_providers.dart';
import 'package:timing_tap/features/settings/presentation/settings_screen.dart';
import 'package:timing_tap/features/settings/state/settings_providers.dart';

/// Settings' reset-progress teardown (architecture v3 §7/§11 risk 6): every
/// prefs key cleared, every dependent RAM provider invalidated, and the
/// `mounted`-check-ordering fix that stops a mid-await disposal from
/// throwing into the framework.
void main() {
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      kKeyTotalRunsPlayed: 12,
      kKeyTotalDeaths: 4,
      kKeyTotalSurvives: 2,
      kKeyTotalEternal: 1,
      kKeyBestLifePercent: 63,
      kKeyStreakCurrent: 5,
      kKeyStreakBest: 7,
      kKeyStreakLastPlayDay: 100,
      kKeyPlayerName: 'Aman',
      kKeyOnboardingComplete: true,
      kKeySoundEnabled: false,
      kKeyHapticsEnabled: false,
      kKeyReminderEnabled: true,
      ...initialPrefs,
    });
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [
        preferencesServiceProvider.overrideWithValue(service),
        // Real Android plugin channels aren't available under `flutter
        // test` — a no-op keeps this test about the reset teardown logic,
        // not the notification plugin.
        reminderServiceProvider.overrideWithValue(const NoopReminderService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          initialRoute: AppRoutes.settings,
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.splash: (_) => const Scaffold(body: Center(child: Text('splash-placeholder'))),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapResetAndConfirm(WidgetTester tester) async {
    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, reset'));
  }

  testWidgets('Reset progress clears every prefs key this app writes', (tester) async {
    final container = await pumpSettings(tester);
    final service = container.read(preferencesServiceProvider);

    await tapResetAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(service.totalRunsPlayed, 0);
    expect(service.totalDeaths, 0);
    expect(service.totalSurvives, 0);
    expect(service.totalEternal, 0);
    expect(service.bestLifePercent, 0);
    expect(service.streakCurrent, 0);
    expect(service.streakBest, 0);
    expect(service.streakLastPlayDay, -1);
    expect(service.playerName, '');
    expect(service.onboardingComplete, false);
    expect(service.soundEnabled, true, reason: 'back to the documented default after a clear');
    expect(service.hapticsEnabled, true);
    expect(service.reminderEnabled, false);
  });

  testWidgets('Reset progress invalidates playerProfileProvider/statsProvider/'
      'settingsProvider so a fresh read reflects the cleared prefs, not a '
      'stale RAM value', (tester) async {
    final container = await pumpSettings(tester);

    // Warm the RAM caches with the pre-reset values.
    await container.read(playerProfileProvider.future);
    expect(container.read(playerProfileProvider).value?.name, 'Aman');
    expect(container.read(statsProvider).totalDeaths, 4);
    expect(container.read(settingsProvider).sound, false);

    await tapResetAndConfirm(tester);
    await tester.pumpAndSettle();

    final freshProfile = await container.read(playerProfileProvider.future);
    expect(freshProfile.name, '', reason: 'playerProfileProvider must be invalidated, not stale');
    expect(container.read(statsProvider).totalDeaths, 0, reason: 'statsProvider must be invalidated');
    expect(container.read(settingsProvider).sound, true, reason: 'settingsProvider must be invalidated');
  });

  testWidgets('REGRESSION: reset progress invalidates selectedAvatarProvider '
      'too, so the avatar card falls back to the never-picked state instead '
      'of leaving the previously-committed avatar stuck in RAM after prefs '
      'have already been wiped', (tester) async {
    final container = await pumpSettings(tester, initialPrefs: {kKeyAvatarId: 5});

    // Warm the RAM cache with the pre-reset committed avatar.
    expect(container.read(selectedAvatarProvider), 5);

    await tapResetAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(
      container.read(selectedAvatarProvider),
      -1,
      reason: 'selectedAvatarProvider must be invalidated, not stale, after reset',
    );
  });

  testWidgets('Reset progress cancels any scheduled reminder before clearing prefs', (tester) async {
    var cancelCalled = false;
    final fakeReminder = _RecordingReminderService(onCancel: () => cancelCalled = true);

    SharedPreferences.setMockInitialValues({kKeyReminderEnabled: true});
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [
        preferencesServiceProvider.overrideWithValue(service),
        reminderServiceProvider.overrideWithValue(fakeReminder),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          initialRoute: AppRoutes.settings,
          routes: {
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.splash: (_) => const Scaffold(body: Center(child: Text('splash-placeholder'))),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapResetAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(cancelCalled, isTrue);
  });

  testWidgets('after reset, the whole nav stack is wiped back to splash '
      '(pushNamedAndRemoveUntil) — the old Settings route cannot be popped '
      'back to', (tester) async {
    await pumpSettings(tester);

    await tapResetAndConfirm(tester);
    await tester.pumpAndSettle();

    expect(find.text('splash-placeholder'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('double-tapping "Yes, reset" (re-entrancy guard) resets '
      'exactly once and still lands cleanly on splash, without throwing', (tester) async {
    final container = await pumpSettings(tester);

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    // Two rapid taps on the confirm button, before any settling in between
    // -- the `_resetting` guard must make the second one a no-op.
    await tester.tap(find.text('Yes, reset'));
    // The first tap's synchronous re-entrancy guard already started tearing
    // things down (and may have moved/removed this button), so the second
    // tap is deliberately allowed to miss its hit test here — the guard
    // under test is `_resetting`, not gesture-arena delivery.
    await tester.tap(find.text('Yes, reset'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('splash-placeholder'), findsOneWidget);
    expect(container.read(preferencesServiceProvider).totalRunsPlayed, 0);
  });

  testWidgets('REGRESSION: disposing SettingsScreen mid-await (during the '
      'reset teardown\'s async gap) does not throw an uncaught exception '
      '-- the mounted-check-ordering fix', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, reset'));

    // Tear the whole widget tree down *before* the reset's async chain
    // (disable() -> clearAll() -> the mounted-guarded invalidate/navigate)
    // has settled, simulating the screen being disposed mid-await. Without
    // the `mounted` guard before touching `ref`/`context` after each
    // `await`, this would throw (e.g. using a disposed `ref` or a
    // deactivated `context`/`Navigator`).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// A `ReminderService` stub that records whether `cancel()` was invoked,
/// without touching any real platform channel.
class _RecordingReminderService implements ReminderService {
  _RecordingReminderService({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> scheduleDaily(int hour) async => true;

  @override
  Future<void> cancel() async {
    onCancel();
  }

  @override
  Future<bool> hasPermission() async => true;
}
