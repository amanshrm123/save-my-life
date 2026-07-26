import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/countdown_view.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/pause_overlay.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/stop_button.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/target_arm_button.dart';
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

  /// Pumps past the full 3-2-1 countdown (`RunConfig.defaults`:
  /// countdownSteps=3 * countdownStepMs=700 = 2100ms) into `armed`.
  Future<void> pumpPastCountdown(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
  }

  RunState readState(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayLoopScreen)),
    );
    return container.read(runControllerProvider);
  }

  testWidgets(
    'countdown auto-arms into the gold "STOP AT" plate; tapping it starts '
    'running and enables the STOP button',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));

      expect(find.byType(CountdownView), findsOneWidget);
      expect(readState(tester).phase, RunPhase.countdown);

      await pumpPastCountdown(tester);

      expect(find.byType(CountdownView), findsNothing);
      expect(find.byType(TargetArmButton), findsOneWidget);
      expect(readState(tester).phase, RunPhase.armed);

      final stopBefore = tester.widget<StopButton>(find.byType(StopButton));
      expect(stopBefore.enabled, isFalse, reason: 'STOP is dimmed while armed');

      await tester.tap(find.byType(TargetArmButton));
      await tester.pump();

      expect(readState(tester).phase, RunPhase.running);
      expect(find.byType(TargetArmButton), findsNothing);
      final stopAfter = tester.widget<StopButton>(find.byType(StopButton));
      expect(stopAfter.enabled, isTrue, reason: 'STOP goes live once running');
    },
  );

  testWidgets(
    'backgrounding the app while running auto-pauses the run with no life '
    'penalty and shows the pause overlay (architecture v2 §9 risk 1)',
    (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      await tester.tap(find.byType(TargetArmButton));
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
      await tester.tap(find.byType(TargetArmButton));
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
      final base = controller.liveElapsed;
      controller.state = controller.state.copyWith(target: base + offset);
      controller.registerStop();
      await tester.pump();
    }

    /// Flushes the screen's post-stop flash-dwell `Future.delayed` timer so
    /// no pending timer survives the test's teardown.
    Future<void> flushDwell(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
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
}
