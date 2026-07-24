import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider;
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/state/play_loop_providers.dart';

/// `RunController`/`RunState` state-machine coverage (architecture v2 §5) —
/// the highest-value test surface per this project's timing/scoring
/// priority. Pure `ProviderContainer` tests, no widget pump: the domain
/// state machine has nothing to do with the display Ticker.
///
/// ## The "how do we control tiers deterministically" problem
///
/// `RunController` owns a private, real `Stopwatch`-backed `GameClock` and a
/// private `Random` for target selection — neither is injectable (by design:
/// architecture v2 §9 risk 10, exactly one instance, never exposed). Even
/// now that the target range is a short `[2.00s, 6.00s]` (re-resolved from
/// the earlier 0-5min range) waiting real wall-clock time for the `Random`
/// to land near a given tier boundary would still be slow and flaky —
/// nothing pins *which* target within the range gets drawn, or exactly when
/// a real tap lands relative to it.
///
/// Instead these tests use the sanctioned `@visibleForTesting` `state`
/// setter that `Notifier` itself exposes (see `package:riverpod`'s
/// `notifier_provider.dart`) to pin `state.target` to a value computed
/// relative to the *real* `liveElapsed` read at that instant, immediately
/// before calling the real `registerStop()`. This keeps `registerStop()`'s
/// own capture-and-classify code path completely real (nothing about
/// `GameClock` or `classifyStop` is mocked) while making the resulting tier
/// deterministic:
///   - offset 0            -> error is only the few microseconds of test
///                             overhead -> comfortably inside the 60ms
///                             Perfect band.
///   - offset 100ms         -> error is ~100ms minus that same tiny
///                             overhead -> comfortably inside the
///                             60-180ms Hit band.
///   - offset 5s            -> error is seconds -> comfortably a Miss.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> buildContainer([
    Map<String, Object> initialPrefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Starts running (must already be `armed`/`finalBandArmed`) then forces a
  /// stop whose `|error|` is deterministically `offset` (see file doc).
  StopTier forceStop(RunController c, Duration offset) {
    c.startRunning();
    final base = c.liveElapsed;
    c.state = c.state.copyWith(target: base + offset);
    c.registerStop();
    return c.state.lastTier!;
  }

  const perfectOffset = Duration.zero;
  const hitOffset = Duration(milliseconds: 100);
  const missOffset = Duration(seconds: 5);

  group('fresh run seeding (architecture v2 §6)', () {
    test('build() seeds phase=countdown, life=100%, attempt 0, streak intact', () async {
      final container = await buildContainer();
      final state = container.read(runControllerProvider);

      expect(state.phase, RunPhase.countdown);
      expect(state.lifePercent, 100);
      expect(state.attemptIndex, 0);
      expect(state.perfectStreakIntact, isTrue);
      expect(state.outcome, isNull);
    });

    test('runNumber = totalRunsPlayed + 1 and deaths = totalDeaths, seeded '
        'from the repository', () async {
      final container = await buildContainer({
        kKeyTotalRunsPlayed: 7,
        kKeyTotalDeaths: 3,
      });
      final state = container.read(runControllerProvider);

      expect(state.runNumber, 8);
      expect(state.deaths, 3);
    });

    test('first-ever launch (empty prefs) seeds runNumber=1, deaths=0', () async {
      final container = await buildContainer();
      final state = container.read(runControllerProvider);

      expect(state.runNumber, 1);
      expect(state.deaths, 0);
    });
  });

  group('countdown -> armed', () {
    test('arm() transitions countdown -> armed', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);

      c.arm();

      expect(c.state.phase, RunPhase.armed);
    });

    test('arm() is a no-op from phases other than countdown/stopped', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm(); // countdown -> armed
      c.startRunning(); // armed -> running
      final before = c.state;

      c.arm(); // invalid from `running`

      expect(c.state.phase, RunPhase.running);
      expect(c.state, same(before));
    });
  });

  group('armed -> running (startRunning) and its double-tap guard', () {
    test('startRunning() from armed starts the clock and moves to running', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      c.startRunning();

      expect(c.state.phase, RunPhase.running);
    });

    test('startRunning() is a no-op outside armed/finalBandArmed (architecture '
        'v2 §9 risk 4) — a second tap after the plate hides does nothing, and '
        'critically does not reset the in-flight clock', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.startRunning();

      // Burn a little real time so liveElapsed is meaningfully > 0.
      final spin = Stopwatch()..start();
      while (spin.elapsed < const Duration(milliseconds: 15)) {}
      final elapsedBeforeSecondTap = c.liveElapsed;

      c.startRunning(); // invalid from `running` — must be a no-op

      expect(c.state.phase, RunPhase.running);
      expect(
        c.liveElapsed,
        greaterThanOrEqualTo(elapsedBeforeSecondTap),
        reason: 'a guarded second startRunning() must not reset the clock '
            'back to zero mid-attempt',
      );
    });

    test('startRunning() is a no-op called while countdown/stopped (never '
        'armed yet, or already evaluating)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);

      c.startRunning(); // still `countdown` — invalid
      expect(c.state.phase, RunPhase.countdown);

      c.arm();
      forceStop(c, perfectOffset); // -> stopped
      expect(c.state.phase, RunPhase.stopped);
      final before = c.state;

      c.startRunning(); // invalid from `stopped`
      expect(c.state, same(before));
    });
  });

  group('registerStop() — tier classification & life application (normal attempts)', () {
    test('a Perfect stop applies +3% life', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 50);

      final tier = forceStop(c, perfectOffset);

      expect(tier, StopTier.perfect);
      expect(c.state.lifePercent, 53);
      expect(c.state.phase, RunPhase.stopped);
      expect(c.state.lastStopWasFinalBand, isFalse);
      expect(c.state.attemptIndex, 1);
    });

    test('a Hit stop applies +2% life', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 50);

      final tier = forceStop(c, hitOffset);

      expect(tier, StopTier.hit);
      expect(c.state.lifePercent, 52);
    });

    test('a Miss stop applies -5% life', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 50);

      final tier = forceStop(c, missOffset);

      expect(tier, StopTier.miss);
      expect(c.state.lifePercent, 45);
    });

    test('life clamps at 100% (a Perfect at 99% does not overflow to 102%)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 99);

      forceStop(c, perfectOffset);

      expect(c.state.lifePercent, 100);
    });

    test('life clamps at 0% (does not go negative)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 3);

      forceStop(c, missOffset);

      expect(c.state.lifePercent, 0);
    });

    test('lastStopElapsed is populated with the captured stop time', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      forceStop(c, perfectOffset);

      expect(c.state.lastStopElapsed, isNotNull);
    });
  });

  group('registerStop() double-tap guards (architecture v2 §9 risk 3)', () {
    test('a second registerStop() while already `stopped` is a no-op', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      forceStop(c, perfectOffset);
      final afterFirst = c.state;

      c.registerStop(); // already consumed / already `stopped`

      expect(c.state.phase, RunPhase.stopped);
      expect(c.state.attemptIndex, afterFirst.attemptIndex);
      expect(c.state.lifePercent, afterFirst.lifePercent);
      expect(c.state.lastTier, afterFirst.lastTier);
      expect(c.state.lastStopElapsed, afterFirst.lastStopElapsed);
    });

    test('registerStop() while armed (never started running) is a no-op', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      c.registerStop();

      expect(c.state.phase, RunPhase.armed);
      expect(c.state.lastTier, isNull);
      expect(c.state.attemptIndex, 0);
    });

    test('registerStop() while countdown (before the run has even armed) is a no-op', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);

      c.registerStop();

      expect(c.state.phase, RunPhase.countdown);
      expect(c.state.attemptIndex, 0);
    });
  });

  group('the raw-Listener STOP capture invariant (architecture G2/v2 §9 risk 3)', () {
    test('registerStop() reads _clock.elapsed as its literal first '
        'statement, before the _stopConsumed/phase guards can reject it — '
        'i.e. the capture is not skippable, not merely "guards happen to '
        'run first"', () {
      final source = File(
        'lib/features/play_loop/state/play_loop_providers.dart',
      ).readAsStringSync();

      final methodStart = source.indexOf('void registerStop() {');
      expect(
        methodStart,
        isNot(-1),
        reason: 'registerStop() must exist verbatim in play_loop_providers.dart',
      );
      final methodEnd = source.indexOf('void advanceAfterDwell()', methodStart);
      final body = source.substring(methodStart, methodEnd);

      final captureIndex = body.indexOf('final stopped = _clock.elapsed;');
      final consumedGuardIndex = body.indexOf('if (_stopConsumed)');
      final phaseGuardIndex = body.indexOf('state.phase != RunPhase.running');

      expect(captureIndex, isNot(-1), reason: 'the direct elapsed capture must exist');
      expect(consumedGuardIndex, isNot(-1), reason: 'the _stopConsumed guard must exist');
      expect(phaseGuardIndex, isNot(-1), reason: 'the phase guard must exist');

      expect(
        captureIndex,
        lessThan(consumedGuardIndex),
        reason: 'the elapsed read must precede the _stopConsumed guard so a '
            'reject can never happen before the instant is captured',
      );
      expect(
        captureIndex,
        lessThan(phaseGuardIndex),
        reason: 'the elapsed read must precede the phase guard so a reject '
            'can never happen before the instant is captured',
      );
    });

    test('behavioral corroboration: even under a rapid double registerStop() '
        '(simulating overlapping pointer-downs), the tier/life recorded is '
        'from the first genuine capture and the second call cannot corrupt '
        'it', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.startRunning();
      final base = c.liveElapsed;
      c.state = c.state.copyWith(target: base); // -> perfect on first stop

      c.registerStop();
      c.registerStop(); // fires immediately after; must be fully inert
      c.registerStop();

      expect(c.state.lastTier, StopTier.perfect);
      expect(c.state.attemptIndex, 1, reason: 'only the first stop may count');
    });
  });

  group('final-band entry condition: 0 < life <= 5 after a delta', () {
    test('a Miss that lands exactly at life=5 enters the final band on '
        'advanceAfterDwell (boundary inclusive)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 10); // 10 - 5 = 5

      forceStop(c, missOffset);
      expect(c.state.lifePercent, 5);
      c.advanceAfterDwell();

      expect(c.state.phase, RunPhase.finalBandArmed);
      expect(c.state.outcome, isNull);
    });

    test('a Miss that lands at life=6 (just above the threshold) rearms '
        'normally instead of entering the final band', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 11); // 11 - 5 = 6

      forceStop(c, missOffset);
      expect(c.state.lifePercent, 6);
      c.advanceAfterDwell();

      expect(c.state.phase, RunPhase.armed);
    });

    test('life<=0 is immediate death and takes precedence over the final '
        'band (0 is excluded from the final-band\'s "0 < life" condition)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 5); // 5 - 5 = 0

      forceStop(c, missOffset);
      expect(c.state.lifePercent, 0);
      c.advanceAfterDwell();

      expect(c.state.phase, RunPhase.ended);
      expect(c.state.outcome, RunOutcome.death);
    });

    test('a life-driving Miss deep past zero also dies (clamped, not negative)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 2); // 2 - 5 = -3 -> clamp 0

      forceStop(c, missOffset);
      c.advanceAfterDwell();

      expect(c.state.lifePercent, 0);
      expect(c.state.phase, RunPhase.ended);
      expect(c.state.outcome, RunOutcome.death);
    });
  });

  group('final band (finalBandArmed/finalBandRunning) — sudden death (architecture v2 §4)', () {
    test('a non-miss (Perfect) in the final band ends the run as survived, '
        'with no incremental life change', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);

      final tier = forceStop(c, perfectOffset);
      expect(tier, StopTier.perfect);
      expect(c.state.lastStopWasFinalBand, isTrue);
      expect(c.state.lifePercent, 4, reason: 'sudden death applies no incremental delta');

      c.advanceAfterDwell();
      expect(c.state.phase, RunPhase.ended);
      expect(c.state.outcome, RunOutcome.survived);
    });

    test('a non-miss (Hit, not just Perfect) in the final band also survives', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);

      final tier = forceStop(c, hitOffset);
      expect(tier, StopTier.hit);

      c.advanceAfterDwell();
      expect(c.state.outcome, RunOutcome.survived);
    });

    test('a Miss in the final band ends the run as death and increments the '
        'lifetime deaths counter in `state`', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.state = c.state.copyWith(
        phase: RunPhase.finalBandArmed,
        lifePercent: 4,
        deaths: 9,
      );

      forceStop(c, missOffset);
      c.advanceAfterDwell();

      expect(c.state.phase, RunPhase.ended);
      expect(c.state.outcome, RunOutcome.death);
      expect(c.state.deaths, 10);
    });
  });

  group('Eternal ending: first 3 attempts of a run all Perfect (architecture v2 §4)', () {
    test('3 Perfect attempts in a row from a fresh run end it as eternal', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      forceStop(c, perfectOffset);
      c.advanceAfterDwell(); // rearm (attempt 1 of 3)
      expect(c.state.phase, RunPhase.armed);

      forceStop(c, perfectOffset);
      c.advanceAfterDwell(); // rearm (attempt 2 of 3)
      expect(c.state.phase, RunPhase.armed);

      forceStop(c, perfectOffset);
      c.advanceAfterDwell(); // attempt 3 of 3 -> eternal

      expect(c.state.phase, RunPhase.ended);
      expect(c.state.outcome, RunOutcome.eternal);
    });

    test('a Hit anywhere in the first 3 attempts permanently breaks the '
        'streak — even if attempts 4+ are all Perfect, Eternal is never '
        'reached', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      forceStop(c, perfectOffset); // attempt 1: perfect
      c.advanceAfterDwell();
      expect(c.state.perfectStreakIntact, isTrue);

      forceStop(c, hitOffset); // attempt 2: hit -> breaks the streak
      c.advanceAfterDwell();
      expect(c.state.perfectStreakIntact, isFalse);

      forceStop(c, perfectOffset); // attempt 3: perfect again
      c.advanceAfterDwell();
      expect(
        c.state.phase,
        isNot(RunPhase.ended),
        reason: 'the streak was already broken at attempt 2 — reaching '
            'attempt 3 with a Perfect must not resurrect Eternal',
      );

      // Attempts 4 and 5: also Perfect — still must never reach Eternal,
      // because perfectStreakIntact can only ever go true->false, never
      // false->true again.
      forceStop(c, perfectOffset);
      c.advanceAfterDwell();
      forceStop(c, perfectOffset);
      c.advanceAfterDwell();

      expect(c.state.attemptIndex, 5);
      expect(c.state.perfectStreakIntact, isFalse);
      expect(c.state.phase, isNot(RunPhase.ended));
      expect(c.state.outcome, isNull);
    });

    test('a Miss anywhere in the first 3 attempts also permanently breaks '
        'the streak', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      // Keep life high so the Miss doesn't accidentally end the run via
      // death/final-band and mask the streak assertion.
      c.state = c.state.copyWith(lifePercent: 80);

      forceStop(c, missOffset); // attempt 1: miss
      c.advanceAfterDwell();
      expect(c.state.perfectStreakIntact, isFalse);

      forceStop(c, perfectOffset); // attempt 2: perfect
      c.advanceAfterDwell();
      forceStop(c, perfectOffset); // attempt 3: perfect

      c.advanceAfterDwell();
      expect(c.state.phase, isNot(RunPhase.ended));
    });
  });

  group('pause/resume — discards an in-flight attempt with no life penalty '
      '(architecture v2 §9 risk 1/8)', () {
    test('pause() while armed freezes to paused and resume() restores armed '
        'with the same target', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      final targetBefore = c.state.target;

      c.pause();
      expect(c.state.phase, RunPhase.paused);
      expect(c.state.phaseBeforePause, RunPhase.armed);

      c.resume();
      expect(c.state.phase, RunPhase.armed);
      expect(c.state.target, targetBefore);
    });

    test('pause() mid-RUNNING discards the in-flight attempt: no life '
        'change, no attemptIndex increment, and resume returns to armed '
        '(not back into running)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      final targetBefore = c.state.target;
      c.startRunning();

      c.pause();

      expect(c.state.phase, RunPhase.paused);
      expect(c.state.phaseBeforePause, RunPhase.armed);
      expect(c.state.lifePercent, 100, reason: 'no life penalty for a discarded attempt');
      expect(c.state.attemptIndex, 0, reason: 'a discarded attempt must not count');

      c.resume();
      expect(c.state.phase, RunPhase.armed);
      expect(c.state.target, targetBefore);

      // The clock must have been genuinely stopped, not left running in the
      // background — a fresh startRunning() should begin again near zero.
      c.startRunning();
      expect(c.liveElapsed, lessThan(const Duration(milliseconds: 50)));
    });

    test('pause() mid-finalBandRunning discards the attempt and resume '
        'returns to finalBandArmed, not ending the run', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 3);
      c.startRunning();

      c.pause();
      expect(c.state.phase, RunPhase.paused);
      expect(c.state.phaseBeforePause, RunPhase.finalBandArmed);

      c.resume();
      expect(c.state.phase, RunPhase.finalBandArmed);
      expect(c.state.lifePercent, 3);
      expect(c.state.outcome, isNull);
    });

    test('pause() is a no-op outside a pausable phase (countdown)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);

      c.pause();

      expect(c.state.phase, RunPhase.countdown);
      expect(c.state.phaseBeforePause, isNull);
    });

    test('pause() is a no-op while already `stopped` (mid flash-dwell, not '
        'a pausable phase)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      forceStop(c, perfectOffset);
      expect(c.state.phase, RunPhase.stopped);

      c.pause();

      expect(c.state.phase, RunPhase.stopped);
    });

    test('pause() is a no-op if already paused (does not overwrite '
        'phaseBeforePause)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.startRunning();
      c.pause();
      expect(c.state.phaseBeforePause, RunPhase.armed);

      c.pause(); // already paused -> must be inert

      expect(c.state.phase, RunPhase.paused);
      expect(c.state.phaseBeforePause, RunPhase.armed);
    });

    test('resume() is a no-op unless currently paused', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      c.arm();

      c.resume();

      expect(c.state.phase, RunPhase.armed);
    });
  });

  group('restartRun() — regression: preserves runNumber AND deaths, resets '
      'everything else (architecture v2 §6/§10 flag 7)', () {
    test('restartRun() resets life to 100%, target, attemptIndex, and the '
        'perfect streak, and moves to armed', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 4, kKeyTotalDeaths: 1});
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 60);
      forceStop(c, hitOffset); // dirty attemptIndex/streak/lastTier

      c.restartRun();

      expect(c.state.phase, RunPhase.armed);
      expect(c.state.lifePercent, 100);
      expect(c.state.attemptIndex, 0);
      expect(c.state.perfectStreakIntact, isTrue);
      expect(c.state.lastTier, isNull);
      expect(c.state.lastStopElapsed, isNull);
      expect(c.state.outcome, isNull);
    });

    test('REGRESSION: restartRun() carries runNumber/deaths over from the '
        'current in-memory state, NOT a fresh re-read of the repository — '
        'even if the repository\'s persisted totals changed after this run '
        'started (e.g. another run completed independently)', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 4, kKeyTotalDeaths: 1});
      final c = container.read(runControllerProvider.notifier);

      // Fresh run seeded runNumber=5, deaths=1.
      expect(c.state.runNumber, 5);
      expect(c.state.deaths, 1);

      // Simulate some *other* run completing independently and bumping the
      // persisted lifetime totals, without going through this controller.
      final repo = container.read(runStatsRepositoryProvider);
      await repo.recordRunCompleted(wasDeath: true);
      expect(repo.totalRunsPlayed, 5);
      expect(repo.totalDeaths, 2);

      c.restartRun();

      // A bug-reverted restartRun() that re-seeds from the repository would
      // now read runNumber=6, deaths=2. The fix must carry over the
      // *pre-restart in-memory* values (5, 1) unchanged.
      expect(
        c.state.runNumber,
        5,
        reason: 'restart must not re-read the repository — this run is not '
            'the "next" run, it is the same run restarted',
      );
      expect(
        c.state.deaths,
        1,
        reason: 'restart must not inflate deaths from a change that '
            'happened elsewhere while this run was in progress',
      );
    });

    test('restartRun() does not itself call recordRunCompleted (abandoning '
        'progress via Restart is not a completion)', () async {
      final container = await buildContainer();
      final c = container.read(runControllerProvider.notifier);
      final service = container.read(preferencesServiceProvider);
      c.arm();

      c.restartRun();
      await pumpEventQueue();

      expect(service.totalRunsPlayed, 0);
      expect(service.totalDeaths, 0);
    });

    test('restartRun() works from a paused state (the only reachable path '
        'via the pause overlay\'s "Restart run" button) and preserves the '
        'counters carried into pause', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 2, kKeyTotalDeaths: 0});
      final c = container.read(runControllerProvider.notifier);
      c.arm();
      c.pause();
      expect(c.state.phase, RunPhase.paused);

      c.restartRun();

      expect(c.state.phase, RunPhase.armed);
      expect(c.state.runNumber, 3);
      expect(c.state.deaths, 0);
    });
  });

  group('lifetime counters persisted on run completion (architecture v2 §6)', () {
    test('a death outcome calls recordRunCompleted and persists both '
        'totalRunsPlayed and totalDeaths', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 0, kKeyTotalDeaths: 0});
      final c = container.read(runControllerProvider.notifier);
      final service = container.read(preferencesServiceProvider);
      c.arm();
      c.state = c.state.copyWith(lifePercent: 5);

      forceStop(c, missOffset); // 5 - 5 = 0 -> death
      c.advanceAfterDwell();
      await pumpEventQueue(); // let the fire-and-forget prefs write settle

      expect(service.totalRunsPlayed, 1);
      expect(service.totalDeaths, 1);
    });

    test('a survived outcome persists totalRunsPlayed but NOT totalDeaths', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 0, kKeyTotalDeaths: 0});
      final c = container.read(runControllerProvider.notifier);
      final service = container.read(preferencesServiceProvider);
      c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 4);

      forceStop(c, perfectOffset); // non-miss in final band -> survived
      c.advanceAfterDwell();
      await pumpEventQueue();

      expect(service.totalRunsPlayed, 1);
      expect(service.totalDeaths, 0);
    });

    test('an eternal outcome persists totalRunsPlayed but NOT totalDeaths', () async {
      final container = await buildContainer({kKeyTotalRunsPlayed: 0, kKeyTotalDeaths: 0});
      final c = container.read(runControllerProvider.notifier);
      final service = container.read(preferencesServiceProvider);
      c.arm();

      forceStop(c, perfectOffset);
      c.advanceAfterDwell();
      forceStop(c, perfectOffset);
      c.advanceAfterDwell();
      forceStop(c, perfectOffset);
      c.advanceAfterDwell(); // -> eternal
      await pumpEventQueue();

      expect(service.totalRunsPlayed, 1);
      expect(service.totalDeaths, 0);
    });

    test('a fresh RunController built after a prior session\'s run '
        'completed (simulating Home -> Play again via a new '
        'ProviderContainer) picks up the incremented lifetime totals', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await PreferencesService.create();

      final containerA = ProviderContainer(
        overrides: [preferencesServiceProvider.overrideWithValue(service)],
      );
      final cA = containerA.read(runControllerProvider.notifier);
      expect(cA.state.runNumber, 1);
      expect(cA.state.deaths, 0);

      cA.arm();
      cA.state = cA.state.copyWith(lifePercent: 5);
      forceStop(cA, missOffset); // -> death
      cA.advanceAfterDwell();
      await pumpEventQueue();
      containerA.dispose();

      // A brand-new container/controller, as if the player quit to Home and
      // pressed Play again for a fresh Play session.
      final containerB = ProviderContainer(
        overrides: [preferencesServiceProvider.overrideWithValue(service)],
      );
      addTearDown(containerB.dispose);
      final cB = containerB.read(runControllerProvider.notifier);

      expect(cB.state.runNumber, 2, reason: 'totalRunsPlayed was persisted as 1');
      expect(cB.state.deaths, 1, reason: 'totalDeaths was persisted as 1');
    });
  });
}
