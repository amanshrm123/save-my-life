import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/countdown_view.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/pause_overlay.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/primary_action_button.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/stopwatch_plate.dart';
import 'package:timing_tap/features/play_loop/state/play_loop_providers.dart';

/// Widget-level coverage for `PlayLoopScreen` (architecture v2 §7/§9). The
/// state-machine logic itself is covered exhaustively at the
/// `ProviderContainer` level in `run_controller_test.dart` — these tests
/// exist for what only a real widget pump can catch: the countdown timer
/// actually arming the run, the raw `Listener`/`GestureDetector` wiring
/// actually reaching `RunController`, and — the headline memory-safety risk
/// (architecture v2 §9 risk 1) — `WidgetsBindingObserver` auto-pause firing
/// on a real `AppLifecycleState` change.
void main() {
  Future<PreferencesService> service([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return PreferencesService.create();
  }

  Widget app(PreferencesService svc) {
    return ProviderScope(
      overrides: [preferencesServiceProvider.overrideWithValue(svc)],
      child: const MaterialApp(home: PlayLoopScreen()),
    );
  }

  /// Bounded pumps, not `pumpAndSettle()`: `LifeAvatar` (juice spec effect
  /// 1) now runs a deliberately always-`repeat()`-ing `AnimationController`
  /// for its continuous "sloshing" wave the whole time `PlayLoopScreen` is
  /// mounted — `pumpAndSettle()` can never settle past that (same fix as
  /// `test/integration/support/app_harness.dart`'s `_pumpBriefly`).
  ///
  /// Steps through [extra] in ~16ms increments rather than one bulk pump
  /// (code-review fix #6) — a bulk pump only evaluates animation curves at
  /// one point in time, too coarse for anything multi-stage.
  Future<void> pumpBriefly(
    WidgetTester tester, [
    Duration extra = const Duration(milliseconds: 500),
  ]) async {
    await tester.pump();
    const step = Duration(milliseconds: 16);
    var remaining = extra;
    while (remaining > Duration.zero) {
      final thisStep = remaining < step ? remaining : step;
      await tester.pump(thisStep);
      remaining -= thisStep;
    }
  }

  /// Pumps past the full 3-2-1 countdown (`RunConfig.defaults`:
  /// countdownSteps=3 * countdownStepMs=700 = 2100ms) into `armed`.
  Future<void> pumpPastCountdown(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2200));
    await pumpBriefly(tester);
  }

  RunState readState(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayLoopScreen)),
    );
    return container.read(runControllerProvider);
  }

  testWidgets(
    'countdown auto-arms into the merged button\'s gold "armStart" look; '
    'tapping it starts running and reskins it in place to "stopNormal"',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));

      expect(find.byType(CountdownView), findsOneWidget);
      expect(readState(tester).phase, RunPhase.countdown);

      await pumpPastCountdown(tester);

      expect(find.byType(CountdownView), findsNothing);
      expect(find.byType(PrimaryActionButton), findsOneWidget);
      expect(readState(tester).phase, RunPhase.armed);

      final buttonBefore = tester.widget<PrimaryActionButton>(find.byType(PrimaryActionButton));
      expect(
        buttonBefore.look,
        PrimaryActionLook.armStart,
        reason: 'gold "STOP AT" look while armed',
      );

      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();

      expect(readState(tester).phase, RunPhase.running);
      final buttonAfter = tester.widget<PrimaryActionButton>(find.byType(PrimaryActionButton));
      expect(
        buttonAfter.look,
        PrimaryActionLook.stopNormal,
        reason: 'the SAME widget reskins to coral "STOP" once running',
      );
    },
  );

  testWidgets(
    'backgrounding the app while running auto-pauses the run with no life '
    'penalty and shows the pause overlay (architecture v2 §9 risk 1)',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();
      expect(readState(tester).phase, RunPhase.running);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      final state = readState(tester);
      expect(state.phase, RunPhase.paused);
      expect(state.phaseBeforePause, RunPhase.armed);
      expect(state.lifePercent, 50, reason: 'a discarded in-flight attempt costs no life');
      expect(find.byType(PauseOverlay), findsOneWidget);
    },
  );

  testWidgets(
    'AppLifecycleState.inactive also auto-pauses a running attempt',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(readState(tester).phase, RunPhase.paused);
    },
  );

  testWidgets(
    'backgrounding while merely armed (not running) does not pause — there '
    'is no in-flight attempt to protect',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      expect(readState(tester).phase, RunPhase.armed);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(
        readState(tester).phase,
        RunPhase.armed,
        reason: 'auto-pause only guards a live running attempt, per '
            'architecture v2 §9 risk 1',
      );
    },
  );

  testWidgets(
    'tapping the pause icon opens the overlay; Resume returns to the same '
    'armed target with no state loss',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      final targetBefore = readState(tester).target;

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(find.byType(PauseOverlay), findsOneWidget);
      expect(readState(tester).phase, RunPhase.paused);

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(readState(tester).phase, RunPhase.armed);
      expect(readState(tester).target, targetBefore);
      expect(find.byType(PauseOverlay), findsNothing);
    },
  );

  testWidgets(
    'the Android back gesture opens pause while live, and resumes while '
    'already paused (PopScope wiring)',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);

      // Simulate a system back gesture/button.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(readState(tester).phase, RunPhase.paused);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(readState(tester).phase, RunPhase.armed);
    },
  );

  group('the "Stopped" status label — restored gap readout under SS:CC '
      '(design v1 §2.6, re-resolved)', () {
    /// Same `@visibleForTesting` `state`-pinning technique as
    /// `run_controller_test.dart`: starts running, then forces the stop's
    /// `|error|` to be deterministically `offset` before calling the real
    /// `registerStop()` through the real `RunController`.
    Future<void> forceStopViaController(WidgetTester tester, Duration offset) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayLoopScreen)),
      );
      final controller = container.read(runControllerProvider.notifier);
      controller.startRunning();
      // Burns real wall-clock time past `RunConfig.minStopElapsedMs` so this
      // deliberately-forced stop is never itself mistaken by the
      // fast-double-tap guard for a suppressed accidental one — the guard
      // reads the real `_clock.elapsed` (never faked, architecture v2 G1),
      // which a `tester.pump()` duration does not advance.
      final spin = Stopwatch()..start();
      while (spin.elapsedMilliseconds <= RunConfig.defaults.minStopElapsedMs) {}
      final base = controller.liveElapsed;
      controller.state = controller.state.copyWith(target: base + offset);
      controller.registerStop();
      await tester.pump();
    }

    /// Flushes the screen's post-stop flash-dwell `Future.delayed` timer so
    /// no pending timer survives the test's teardown. Bounded pump, not
    /// `pumpAndSettle()` — see `pumpPastCountdown`'s doc comment above. The
    /// generous 1600ms second window (not just a few hundred ms) also
    /// covers the terminal-outcome case, where this dwell hands off into a
    /// real `OutcomeCardScreen` mount (`kMinStoryLoadDuration` = 1000ms,
    /// plus this harness's un-mocked `outcomeStoryProvider`/HTTP machinery)
    /// — matches `test/integration/support/app_harness.dart`'s own
    /// `flushDwell` fix.
    Future<void> flushDwell(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 700));
      await pumpBriefly(tester, const Duration(milliseconds: 1600));
    }

    testWidgets('a Miss shows "Stopped · off by X.XX", not just "Stopped"', (
      tester,
    ) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);

      await forceStopViaController(tester, const Duration(seconds: 5)); // huge -> miss

      expect(readState(tester).phase, RunPhase.stopped);
      expect(find.textContaining('Stopped · off by'), findsOneWidget);
      expect(find.text('Stopped'), findsNothing);

      await flushDwell(tester);
    });

    testWidgets('a Perfect shows plain "Stopped", no gap readout', (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);

      await forceStopViaController(tester, Duration.zero); // perfect

      expect(find.text('Stopped'), findsOneWidget);
      expect(find.textContaining('off by'), findsNothing);

      await flushDwell(tester);
    });

    testWidgets('a Hit also shows plain "Stopped", no gap readout', (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);

      await forceStopViaController(tester, const Duration(milliseconds: 100)); // hit

      expect(find.text('Stopped'), findsOneWidget);
      expect(find.textContaining('off by'), findsNothing);

      await flushDwell(tester);
    });

    testWidgets(
      'a final-band terminal Miss still shows plain "Stopped" — the gap '
      'readout is reserved for normal (non-final-band) attempts, matching '
      'the SURVIVED/MISS flash which never shows a percentage either',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PlayLoopScreen)),
        );
        final controller = container.read(runControllerProvider.notifier);
        controller.state = controller.state.copyWith(
          phase: RunPhase.finalBandArmed,
          lifePercent: 4,
        );
        await tester.pump();

        await forceStopViaController(tester, const Duration(seconds: 5)); // huge -> miss

        expect(readState(tester).lastStopWasFinalBand, isTrue);
        expect(find.text('Stopped'), findsOneWidget);
        expect(find.textContaining('off by'), findsNothing);

        await flushDwell(tester);
      },
    );
  });

  group('_CenterContent AnimatedSwitcher (founder feedback round 2 — a soft '
      'cross-fade between phases instead of a bare cut)', () {
    /// Directly mutates `RunController.state` (the same technique the
    /// "Stopped" status-label group above already uses) to force phase
    /// transitions back-to-back, faster than the 200ms fade — this is the
    /// only way to reliably land inside an in-flight `AnimatedSwitcher`
    /// transition from a test, since the real `minStopElapsedMs` guard makes
    /// a genuine double-tap-driven armed->running->stopped sequence
    /// physically unable to complete that fast.
    ///
    /// Bypassing `_resolveStop`/`arm()` this way leaves two real (fake-clock)
    /// timers dangling that `flutter_test` asserts against at teardown: the
    /// screen's own 600ms post-stop dwell `Future.delayed`
    /// (`_PlayLoopScreenState._onStopped`) and the controller's
    /// `_scheduleAutoMiss` timer armed by `startRunning()`. This always calls
    /// `arm()` (which cancels the auto-miss timer) then flushes the dwell
    /// delay before the test ends, regardless of which phase the test itself
    /// left the controller in.
    Future<void> cleanUpDanglingTimers(WidgetTester tester, RunController controller) async {
      if (controller.state.phase != RunPhase.stopped) {
        controller.state = controller.state.copyWith(
          phase: RunPhase.stopped,
          lastTier: StopTier.perfect,
          lastStopElapsed: controller.state.target,
        );
        await tester.pump();
      }
      controller.arm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      // Bounded pump, not `pumpAndSettle()` — see `pumpPastCountdown`'s doc
      // comment above (`LifeAvatar`'s continuous wave keeps this screen
      // perpetually "unsettled").
      await pumpBriefly(tester);
    }

    testWidgets(
      'phase changes faster than the 200ms fade never throw and always '
      'settle showing exactly one live content widget, never a stuck overlap '
      'of two phases\' content',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PlayLoopScreen)),
        );
        final controller = container.read(runControllerProvider.notifier);

        // armed -> running: starts the first cross-fade.
        controller.startRunning();
        await tester.pump();
        // Only 20ms into the 200ms fade — deliberately mid-transition.
        await tester.pump(const Duration(milliseconds: 20));

        // running -> stopped, preempting the still-in-flight armed->running
        // fade before it ever finished. `AnimatedSwitcher` must cleanly
        // abandon the outgoing armed fade and start a new one toward this
        // newest child rather than getting confused about which child is
        // "current".
        controller.state = controller.state.copyWith(
          phase: RunPhase.stopped,
          lastTier: StopTier.perfect,
          lastStopElapsed: controller.state.target,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        // stopped -> armed again (re-arm) via the real `arm()` entry point,
        // once more before the previous fade has settled — also doubles as
        // this test's timer cleanup (see `cleanUpDanglingTimers`).
        controller.arm();
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'no exception through a chain of interrupted fades');

        // Let every in-flight AnimatedSwitcher animation fully settle — a
        // bounded pump, not `pumpAndSettle()` (see `pumpPastCountdown`'s doc
        // comment above), comfortably past the 200ms fade.
        await pumpBriefly(tester, const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        // Final phase is `armed`: exactly the armed teaching line shows, with
        // no leftover `StopwatchPlate`/flash content from the intermediate
        // `stopped` frame still hanging around post-settle.
        expect(find.text('Tap below when you\'re ready.'), findsOneWidget);
        expect(find.byType(StopwatchPlate), findsNothing);

        // Flush the still-pending 600ms post-stop dwell Future so no timer
        // leaks past this test (`advanceAfterDwell` itself no-ops here since
        // `_pending` was never set — this bypassed `_resolveStop` entirely).
        await tester.pump(const Duration(milliseconds: 700));
        await pumpBriefly(tester);
      },
    );

    testWidgets(
      'running and finalBandRunning are distinct AnimatedSwitcher keys (both '
      'build the same StopwatchPlate widget type) — verifies a same-type, '
      'different-phase transition still cross-fades rather than being '
      'mistaken for "no change" and skipped',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PlayLoopScreen)),
        );
        final controller = container.read(runControllerProvider.notifier);
        controller.startRunning();
        await tester.pump();
        // Deliberately not `pumpAndSettle()` here: a live phase keeps a real
        // `Ticker` running (by design — it drives the 60fps elapsed digits),
        // which schedules a new frame every engine tick and would make
        // `pumpAndSettle` spin forever waiting for "no more frames".
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Running…'), findsOneWidget);

        // Force straight into finalBandRunning without a real stop — this is
        // the exact "same widget type, different enum value" case the
        // `ValueKey(displayPhase)` doc comment calls out explicitly.
        controller.state = controller.state.copyWith(phase: RunPhase.finalBandRunning);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));

        expect(tester.takeException(), isNull);
        // Same reason as above: still live, so pump a fixed duration well
        // past the 200ms fade instead of `pumpAndSettle`.
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);

        // Only one StopwatchPlate ever visible at once, even mid-cross-fade
        // and after settling.
        expect(find.byType(StopwatchPlate), findsOneWidget);

        await cleanUpDanglingTimers(tester, controller);
      },
    );
  });
}
