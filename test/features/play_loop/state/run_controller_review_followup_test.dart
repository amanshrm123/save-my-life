import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider;
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/state/play_loop_providers.dart';

/// QA follow-up: independent re-verification of two specific claims from the
/// Play Loop v2 review/fix pass, deliberately NOT just re-running
/// `run_controller_test.dart`'s existing assertions:
///
///  1. The 7 documented auto-miss-timer cancellation points
///     (`RunController._cancelAutoMiss()`) — `run_controller_test.dart`
///     already covers manual stop, pause() while `running`, restartRun(),
///     and dispose exhaustively. This file adds the 3 gaps: pause() while
///     `finalBandRunning` specifically, and the defensive cancellation
///     inside `arm()`/`enterFinalBand()` themselves (verified directly,
///     since no *reachable* production call sequence can otherwise present
///     those two methods with a still-live timer to cancel — see inline
///     notes).
///  2. The fast-double-tap suppression guard (`RunConfig.minStopElapsedMs`),
///     re-verified using a genuinely different technique than the
///     `burnPastMinStopElapsed()` busy-spin loop used everywhere else in
///     this codebase's test suite: a real awaited `Future.delayed`, which
///     lets actual wall-clock time elapse without spinning the CPU.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    // `runControllerProvider` is `.autoDispose` (architecture v2 §9 risk
    // 9/10) — a bare `container.read(...)` with no active listener is
    // eligible to be torn down the moment a real event-loop turn actually
    // passes (which a genuinely-awaited `Future.delayed` causes, unlike the
    // fakeAsync/busy-spin techniques elsewhere in this suite). A persistent
    // listener, mirroring `PlayLoopScreen`'s own `ref.listenManual` in the
    // real app, is required to keep it alive across a real `await` gap.
    final sub = container.listen<RunState>(runControllerProvider, (prev, next) {});
    addTearDown(sub.close);
    return container;
  }

  group('auto-miss timer cancellation — the 3 gaps not already covered', () {
    test(
      'pause() while finalBandRunning specifically cancels the pending '
      'auto-miss timer (existing coverage only exercises the plain '
      '`running` branch of pause())',
      () async {
        final container = await buildContainer();
        final c = container.read(runControllerProvider.notifier);
        c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);

        fakeAsync((async) {
          c.startRunning();
          expect(c.state.phase, RunPhase.finalBandRunning);
          expect(
            async.nonPeriodicTimerCount,
            1,
            reason: 'the auto-miss timer is scheduled the instant the '
                'final-band attempt goes live',
          );

          c.pause();
          expect(
            async.nonPeriodicTimerCount,
            0,
            reason: 'pause() must cancel the pending auto-miss timer from '
                'the finalBandRunning branch specifically, not just the '
                'plain running one',
          );

          final afterPause = c.state;
          async.elapse(const Duration(seconds: 10));
          expect(
            c.state,
            same(afterPause),
            reason: 'no stale auto-miss timer may fire while paused from '
                'the final band',
          );
        });
      },
    );

    test(
      'arm() cancels a timer if one happens to still be live at call time '
      '(defensive robustness check on `_cancelAutoMiss()` inside `arm()` '
      'itself) — NOTE: no real player input sequence can reach `arm()` '
      'with a genuinely pending auto-miss timer today, because `arm()` '
      'only ever proceeds from `countdown` or `stopped`, and by the time '
      'the phase is `stopped` the timer has already been cancelled via '
      '`_resolveStop()`. This test forces the otherwise-unreachable '
      'precondition directly (bypassing `_resolveStop` via the '
      '`@visibleForTesting` state setter) purely to confirm the defensive '
      'call inside `arm()` genuinely works, in case a future refactor ever '
      'makes the precondition reachable.',
      () async {
        final container = await buildContainer();
        final c = container.read(runControllerProvider.notifier);
        c.arm();

        fakeAsync((async) {
          c.startRunning();
          expect(async.nonPeriodicTimerCount, 1);

          // Force `stopped` WITHOUT going through `_resolveStop()` (which
          // would itself cancel the timer) — simulating a hypothetical
          // future code path that reaches `stopped` some other way while a
          // timer is still outstanding.
          c.state = c.state.copyWith(phase: RunPhase.stopped);
          expect(
            async.nonPeriodicTimerCount,
            1,
            reason: 'sanity check: forcing state directly must NOT itself '
                'cancel the timer (only real controller methods do)',
          );

          c.arm();

          expect(
            async.nonPeriodicTimerCount,
            0,
            reason: 'arm() must cancel any live auto-miss timer as its '
                'first statement, defensively, regardless of how it got '
                'left pending',
          );
        });
      },
    );

    test(
      'enterFinalBand() cancels a timer if one happens to still be live at '
      'call time (same defensive-robustness rationale as the arm() test '
      'above — enterFinalBand() only ever proceeds from `stopped`, where '
      '_resolveStop() has already cancelled any real timer in every '
      'reachable production path)',
      () async {
        final container = await buildContainer();
        final c = container.read(runControllerProvider.notifier);
        c.arm();

        fakeAsync((async) {
          c.startRunning();
          expect(async.nonPeriodicTimerCount, 1);

          c.state = c.state.copyWith(phase: RunPhase.stopped);
          expect(async.nonPeriodicTimerCount, 1);

          c.enterFinalBand();

          expect(
            async.nonPeriodicTimerCount,
            0,
            reason: 'enterFinalBand() must cancel any live auto-miss timer '
                'as its first statement, defensively',
          );
          expect(c.state.phase, RunPhase.finalBandArmed);
        });
      },
    );
  });

  group(
    'fast-double-tap suppression guard — INDEPENDENT re-verification using '
    'a real awaited Future.delayed instead of the busy-spin-loop pattern '
    '(`burnPastMinStopElapsed()`) every other test file in this suite uses',
    () {
      test(
        'a stop fired via a real awaited ~10ms delay after start (nowhere '
        'near minStopElapsedMs=200) is fully suppressed: phase stays '
        'running, no life change, no attempt counted',
        () async {
          final container = await buildContainer();
          final c = container.read(runControllerProvider.notifier);
          c.arm();
          c.startRunning();

          await Future<void>.delayed(const Duration(milliseconds: 10));

          c.registerStop();

          expect(
            c.state.phase,
            RunPhase.running,
            reason: 'a stop at ~10ms real elapsed must be fully suppressed',
          );
          expect(c.state.lifePercent, 50);
          expect(c.state.attemptIndex, 0);
          expect(c.state.lastTier, isNull);

          c.pause(); // clean up the still-pending auto-miss timer
        },
      );

      test(
        'a stop fired via a real awaited delay comfortably PAST '
        'minStopElapsedMs=200 (e.g. ~260ms) resolves normally — the '
        'boundary-adjacent case that would silently regress if the '
        'threshold constant were ever changed incorrectly',
        () async {
          final container = await buildContainer();
          final c = container.read(runControllerProvider.notifier);
          c.arm();
          c.startRunning();

          await Future<void>.delayed(const Duration(milliseconds: 260));
          expect(
            c.liveElapsed.inMilliseconds,
            greaterThan(RunConfig.defaults.minStopElapsedMs),
            reason: 'sanity check on the real elapsed time this awaited '
                'delay actually produced',
          );

          // Pin the target so this genuine stop lands as a deterministic
          // Perfect (see run_controller_test.dart's file doc for why this
          // is the sanctioned technique for controlling tiers).
          c.state = c.state.copyWith(target: c.liveElapsed);
          c.registerStop();

          expect(
            c.state.phase,
            RunPhase.stopped,
            reason: 'a stop meaningfully past minStopElapsedMs must be '
                'accepted normally, never suppressed',
          );
          expect(c.state.lastTier, StopTier.perfect);
          expect(c.state.attemptIndex, 1);
        },
      );

      test(
        'the same real-delay technique applied during finalBandRunning: a '
        'too-fast stop does not end the run as an unearned death',
        () async {
          final container = await buildContainer();
          final c = container.read(runControllerProvider.notifier);
          c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);
          c.startRunning();

          await Future<void>.delayed(const Duration(milliseconds: 15));
          c.registerStop();

          expect(c.state.phase, RunPhase.finalBandRunning);
          expect(c.state.outcome, isNull);
          expect(c.state.lifePercent, 4);

          c.pause();
        },
      );
    },
  );
}
