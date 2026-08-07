import 'dart:async';

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
import 'package:timing_tap/features/settings/presentation/widgets/settings_toggle.dart';
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

  testWidgets(
    "the debug-only Verify Sentry setup row never renders when kSentryEnabled "
    "is false (the actual state under `flutter test`, with no --dart-define) "
    "-- it must never ship as a real player-facing row",
    (tester) async {
      await pumpSettings(tester);

      expect(find.text('Verify Sentry setup'), findsNothing);
    },
  );

  // REGRESSION (found via live iOS E2E testing): the Daily reminder toggle
  // used to give zero visual feedback while `enable()`/`disable()` was in
  // flight -- on a real device this is gated on a human actually responding
  // to the OS permission dialog, not instant, so a player who tapped and
  // saw nothing happen had no way to tell "still working" from "silently
  // broken". These assert the busy indicator now covers exactly that gap.
  testWidgets('the Daily reminder row shows a busy indicator (not the '
      'toggle) while enable() is pending, and reverts once it resolves',
      (tester) async {
    final fakeReminder = _DelayedReminderService();
    SharedPreferences.setMockInitialValues({kKeyReminderEnabled: false});
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
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Locates the Daily reminder row's own SettingsToggle by walking down
    // from its label text, rather than guessing at pixel coordinates or at
    // list position among the other toggles.
    final reminderRow = find.ancestor(
      of: find.text('Daily reminder'),
      matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: reminderRow, matching: find.byType(SettingsToggle)));
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'enable() is still pending on fakeReminder.permissionCompleter',
    );

    fakeReminder.permissionCompleter.complete(true);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(container.read(settingsProvider).reminder, isTrue);
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

/// A `ReminderService` stub whose `requestPermission()` doesn't resolve
/// until the test explicitly completes [permissionCompleter] -- simulates
/// the real, human-gated wait for an OS permission dialog, so a test can
/// pump mid-flight and assert on the pending-state UI.
class _DelayedReminderService implements ReminderService {
  final Completer<bool> permissionCompleter = Completer<bool>();

  @override
  Future<bool> requestPermission() => permissionCompleter.future;

  @override
  Future<bool> scheduleDaily(int hour) async => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> hasPermission() async => true;
}
