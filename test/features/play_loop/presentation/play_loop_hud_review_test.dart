import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_figure.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/life_avatar.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/primary_action_button.dart';
import 'package:timing_tap/features/play_loop/state/play_loop_providers.dart';

/// QA follow-up coverage for the Play Loop v2 revision (design spec
/// `docs/design/play-loop-v2.md`) — targeted, independent re-verification of
/// the specific claims made in the just-completed review/fix pass, on top of
/// (not duplicating) `run_controller_test.dart` and `play_loop_screen_test.dart`'s
/// existing coverage:
///   - the merged button's `Semantics.onTap` actually triggers the SAME real
///     callback a physical tap does (not a declared-but-inert stub);
///   - the restored start-tap haptic fires on a genuine start and ONLY a
///     genuine start (never a suppressed too-fast stop, never a real stop);
///   - the Deaths chip is genuinely gone from every reachable HUD phase;
///   - `LifeAvatar` is sized correctly (doesn't blow the 72dp HUD row) and
///     forwards `state.lifePercent` verbatim (no tier-flash / no final-band
///     override reintroduced).
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

  // Bounded pumps, not `pumpAndSettle()`: `LifeAvatar` (juice spec effect 1)
  // now runs a deliberately always-`repeat()`-ing `AnimationController` for
  // its continuous "sloshing" wave while `PlayLoopScreen` is mounted, which
  // `pumpAndSettle()` can never settle past (see
  // `test/integration/support/app_harness.dart`'s `_pumpBriefly` for the
  // same fix applied to the shared integration-test harness).
  //
  // Steps through [extra] in ~16ms increments rather than one bulk pump
  // (code-review fix #6) — a bulk pump only evaluates animation curves at
  // one point in time, too coarse for anything multi-stage.
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

  Future<void> pumpPastCountdown(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2200));
    await pumpBriefly(tester);
  }

  RunController controllerOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(PlayLoopScreen)),
  ).read(runControllerProvider.notifier);

  RunState stateOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(PlayLoopScreen)),
  ).read(runControllerProvider);

  group('merged button Semantics — onTap must be genuinely wired, not a stub', () {
    testWidgets(
      'invoking the Semantics onTap action (as TalkBack/accessibility '
      'tooling would) starts the run exactly like a physical pointer tap',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);
        expect(stateOf(tester).phase, RunPhase.armed);

        final handle = tester.ensureSemantics();

        final node = tester.getSemantics(find.byType(PrimaryActionButton));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'the Semantics node must declare an activatable onTap, not '
              'just button:true/a label',
        );

        // ignore: deprecated_member_use
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pump();

        expect(
          stateOf(tester).phase,
          RunPhase.running,
          reason: 'the Semantics-triggered tap must reach the exact same '
              'handlePrimaryPointerDown() a physical tap does',
        );

        // Clean up: the semantics handle must be disposed BEFORE the test
        // body returns (flutter_test's end-of-test invariant check runs
        // ahead of any `addTearDown` callback), and the run just started by
        // the semantics tap left a pending auto-miss Timer that must not
        // survive teardown either.
        controllerOf(tester).pause();
        handle.dispose();
      },
    );
  });

  group('haptic gating — the restored start-tap light haptic', () {
    late List<String> vibrateTypes;

    setUp(() {
      vibrateTypes = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          vibrateTypes.add(call.arguments as String? ?? '');
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('a genuine start tap fires exactly one lightImpact haptic', (
      tester,
    ) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      vibrateTypes.clear(); // the 3-2-1 countdown itself fires its own lightImpact haptics

      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();

      expect(stateOf(tester).phase, RunPhase.running);
      expect(
        vibrateTypes.where((t) => t == 'HapticFeedbackType.lightImpact').length,
        1,
        reason: 'exactly one light-impact haptic for the genuine start tap',
      );

      // Clean up the pending auto-miss Timer this run's startRunning()
      // scheduled, so it doesn't survive this test's teardown.
      controllerOf(tester).pause();
    });

    testWidgets(
      'a suppressed too-fast second tap (landing on the same widget right '
      'after the start tap, within minStopElapsedMs) fires NO additional '
      'haptic at all — not a light-impact (not a start) and not a '
      'medium/heavy one either (nothing genuine happened)',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);
        vibrateTypes.clear(); // the 3-2-1 countdown itself fires its own lightImpact haptics

        // Two taps back-to-back, no pump in between — the second lands
        // while phase is already `running`, at ~0ms elapsed, well under
        // `RunConfig.minStopElapsedMs`.
        await tester.tap(find.byType(PrimaryActionButton));
        await tester.tap(find.byType(PrimaryActionButton), warnIfMissed: false);
        await tester.pump();

        expect(
          stateOf(tester).phase,
          RunPhase.running,
          reason: 'the too-fast second tap must have been fully suppressed',
        );
        expect(
          vibrateTypes.where((t) => t == 'HapticFeedbackType.lightImpact').length,
          1,
          reason: 'only the FIRST tap (the genuine start) may have fired a '
              'light-impact haptic; the suppressed second tap must add none',
        );

        controllerOf(tester).pause();
      },
    );

    testWidgets(
      'a genuine stop tap (well past minStopElapsedMs) fires its own '
      'tier-based haptic (medium/heavy), never an extra light-impact '
      '"start" haptic',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        await tester.tap(find.byType(PrimaryActionButton)); // start
        await tester.pump();
        vibrateTypes.clear(); // isolate the stop tap's haptics only

        // Burn real wall-clock time so the stop is genuinely accepted, not
        // suppressed.
        final spin = Stopwatch()..start();
        while (spin.elapsedMilliseconds <= RunConfig.defaults.minStopElapsedMs) {}

        await tester.tap(find.byType(PrimaryActionButton)); // stop
        await tester.pump();

        expect(stateOf(tester).phase, RunPhase.stopped);
        expect(
          vibrateTypes.contains('HapticFeedbackType.lightImpact'),
          isFalse,
          reason: 'a stop tap must never fire the start-only light-impact '
              'haptic',
        );
        expect(
          vibrateTypes.any(
            (t) =>
                t == 'HapticFeedbackType.mediumImpact' ||
                t == 'HapticFeedbackType.heavyImpact',
          ),
          isTrue,
          reason: 'a genuine stop still fires its own pre-existing '
              'tier-based haptic',
        );

        await tester.pump(const Duration(milliseconds: 700));
        // Not `pumpAndSettle()` — this stop doesn't end the run, so
        // `PlayLoopScreen`/`LifeAvatar` (and its continuous wave) stay
        // mounted; see `pumpPastCountdown`'s comment above.
        await pumpBriefly(tester);
      },
    );
  });

  group('Deaths chip removal — no trace of it in any reachable HUD phase', () {
    testWidgets('armed phase shows no Deaths chip', (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);

      expect(find.textContaining('Deaths'), findsNothing);
    });

    testWidgets('running phase shows no Deaths chip', (tester) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();

      expect(find.textContaining('Deaths'), findsNothing);
      controllerOf(tester).pause();
    });

    testWidgets('the paused overlay phase shows no Deaths chip underneath', (
      tester,
    ) async {
      final svc = await service();
      await tester.pumpWidget(app(svc));
      await pumpPastCountdown(tester);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      expect(stateOf(tester).phase, RunPhase.paused);
      expect(find.textContaining('Deaths'), findsNothing);
    });

    testWidgets(
      'a completed run (death) still tracks RunState.deaths/Outcome data '
      'correctly even though it is never rendered in the Play Loop HUD',
      (tester) async {
        final svc = await service({kKeyTotalDeaths: 2});
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final c = controllerOf(tester);
        c.state = c.state.copyWith(lifePercent: 5);
        await tester.pump();
        c.startRunning();
        final spin = Stopwatch()..start();
        while (spin.elapsedMilliseconds <= RunConfig.defaults.minStopElapsedMs) {}
        c.state = c.state.copyWith(target: c.liveElapsed + const Duration(seconds: 5));
        c.registerStop(); // huge miss -> life 0 -> death (pending until advanceAfterDwell)
        await tester.pump();

        expect(find.textContaining('Deaths'), findsNothing);

        // The screen's own flash-dwell Future.delayed calls advanceAfterDwell(),
        // which is where the death outcome/deaths increment is actually
        // applied — read it back immediately after that single pump, before
        // a further `pumpAndSettle()` completes the hand-off navigation and
        // tears the (autoDispose) provider down. Comfortably past
        // `RunConfig.flashDwellMs` (1100ms).
        await tester.pump(const Duration(milliseconds: 1200));

        expect(c.state.outcome, RunOutcome.death);
        expect(c.state.deaths, 3, reason: 'RunState.deaths itself is untouched by the HUD change');
        expect(find.textContaining('Deaths'), findsNothing);

        await tester.pumpAndSettle();
      },
    );
  });

  group('LifeAvatar sizing/coloring inside the real HUD row', () {
    testWidgets(
      'renders at exactly the spec\'d 58x72 box, never blowing the HUD '
      'row\'s height budget',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final size = tester.getSize(find.byType(LifeAvatar));
        expect(size.width, 58);
        expect(size.height, 72);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'forwards state.lifePercent verbatim to AvatarFigure.fillPercent, '
      'with shouldAnimate always true, even deep in the final band — no '
      'tier-flash / no forced-red override reintroduced',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final c = controllerOf(tester);
        c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);
        await tester.pump();

        final figure = tester.widget<AvatarFigure>(find.byType(AvatarFigure));
        expect(
          figure.fillPercent,
          4,
          reason: 'the avatar fill must be the raw percent-band value, '
              'never overridden/clamped for the final band',
        );
        expect(figure.shouldAnimate, isTrue);
      },
    );

    testWidgets(
      'forwards the exact boundary percents (59 and 60) unmodified — the '
      'color-band decision itself is delegated to avatarFillColorForPercent, '
      'already exhaustively boundary-tested at the domain level',
      (tester) async {
        final svc = await service();
        await tester.pumpWidget(app(svc));
        await pumpPastCountdown(tester);

        final c = controllerOf(tester);

        c.state = c.state.copyWith(lifePercent: 59);
        await tester.pump();
        expect(tester.widget<AvatarFigure>(find.byType(AvatarFigure)).fillPercent, 59);

        c.state = c.state.copyWith(lifePercent: 60);
        await tester.pump();
        expect(tester.widget<AvatarFigure>(find.byType(AvatarFigure)).fillPercent, 60);

        c.state = c.state.copyWith(lifePercent: 19);
        await tester.pump();
        expect(tester.widget<AvatarFigure>(find.byType(AvatarFigure)).fillPercent, 19);

        c.state = c.state.copyWith(lifePercent: 20);
        await tester.pump();
        expect(tester.widget<AvatarFigure>(find.byType(AvatarFigure)).fillPercent, 20);
      },
    );
  });
}
