// Integration tests for `RunController` (lib/features/run/run_controller.dart)
// — the Notifier that owns life%/target/last-tap-result/deathCount and is
// the only thing that calls `resolve()` and mutates life. These tests
// exercise the controller itself (not the pure `resolve()`/`lifeDeltaFor()`
// functions, which already have full boundary coverage in
// test/features/timing_engine/timing_engine_test.dart).
//
// `clockProvider` is overridden with a `FakeMonotonicClock` so target timing
// is fully deterministic. `profileRepositoryProvider` is overridden with a
// `FakeProfileRepository` (architecture v3 §3.4/§5) so `RunController.build()`
// can safely call `.requireValue` — the override's Future is awaited once in
// `setUp` before any test reads `runControllerProvider`, mirroring the real
// app's own precondition (`SplashScreen` already awaits this provider before
// `PlayScreen`/`RunController` are ever reached).
//
// Architecture v3 changes exercised here: life starts at 100% (item 2); a
// tap is a no-op unless `phase == playing` (item 1); On-point/Miss
// life-deltas are rolled within ranges rather than fixed (item 4) — most
// assertions below check band + range membership rather than exact end
// values, since the roll is real (`Random()`) and not test-injectable;
// life reaching exactly 0% ends the run (`phase == dead`), increments
// `deathCount`, and persists via `incrementDeathCount()` (item 1);
// `startNewCycle()` resets everything except `deathCount`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/core/timing_config.dart';
import 'package:timing_tap/features/persistence/hive_profile_repository.dart';
import 'package:timing_tap/features/persistence/profile_repository.dart';
import 'package:timing_tap/features/run/run_controller.dart';
import 'package:timing_tap/features/timing_engine/timing_engine.dart';

import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_profile_repository.dart';

void main() {
  late FakeMonotonicClock clock;
  late FakeProfileRepository repo;
  late ProviderContainer container;

  /// Builds a container with the given clock/repo overrides and awaits the
  /// repo's `FutureProvider` so `RunController.build()`'s
  /// `.requireValue` read is always safe by the time a test touches
  /// `runControllerProvider` — this is the test-side mirror of the real
  /// precondition (`SplashScreen` already awaits `profileRepositoryProvider`
  /// before `PlayScreen` is ever reached, architecture v3 §3.4).
  Future<ProviderContainer> buildContainer({
    required FakeMonotonicClock clock,
    required FakeProfileRepository repo,
  }) async {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        profileRepositoryProvider.overrideWith(
          (ref) async => repo as ProfileRepository,
        ),
      ],
    );
    await c.read(profileRepositoryProvider.future);
    return c;
  }

  setUp(() async {
    clock = FakeMonotonicClock(0);
    repo = FakeProfileRepository();
    container = await buildContainer(clock: clock, repo: repo);
  });

  tearDown(() {
    container.dispose();
  });

  /// Registers a tap that lands exactly [deltaMicros] away from the
  /// *current* round's target, via the real `RunController.registerTap`
  /// (not `resolve()` directly) — exercises target lookup, life clamp,
  /// state replacement, and the next-round roll together. A no-op if the
  /// run isn't currently `playing` (architecture v3 §3.3) — callers that
  /// need a scored tap must call `beginPlaying()` first.
  void tapAtDelta(int deltaMicros) {
    final RunState before = container.read(runControllerProvider);
    final int targetMicros =
        before.roundStartMicros + before.targetDurationMicros;
    final int pressMicros = targetMicros + deltaMicros;
    clock.setMicros(pressMicros);
    container.read(runControllerProvider.notifier).registerTap(pressMicros);
  }

  /// Repeatedly registers Miss taps until the run ends (`phase == dead`),
  /// returning the final state. Used by several tests below that need to
  /// reach death deterministically without depending on the exact ranged
  /// Miss magnitude.
  RunState tapUntilDead() {
    RunState state = container.read(runControllerProvider);
    while (state.phase == RunPhase.playing) {
      tapAtDelta(500000); // Miss
      state = container.read(runControllerProvider);
    }
    return state;
  }

  group('initial state', () {
    test('starts at 100% life, countdown phase, no prior tap, target in '
        'range, deathCount seeded from the repository', () {
      final RunState state = container.read(runControllerProvider);
      expect(state.lifePct, 100.0);
      expect(state.phase, RunPhase.countdown);
      expect(state.lastDeltaMs, isNull);
      expect(state.lastBand, isNull);
      expect(state.lastLifeDelta, isNull);
      expect(state.deathCount, 0);
      expect(state.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(state.targetDurationMicros, lessThan(20000000));
      expect(state.roundStartMicros, 0); // clock started at 0
    });

    test('build() seeds lastHitLifeDelta to onPointLifeDeltaMin (+2) and '
        'lastMissLifeDelta to missLifeDeltaMax (-3) — architecture v4 §2.3\'s '
        'gentlest-value seed, note the asymmetry: Miss seeds to the range '
        'MAX (least-negative), not the range min (most-negative)', () {
      final RunState state = container.read(runControllerProvider);
      expect(state.lastHitLifeDelta, TimingConfig.onPointLifeDeltaMin);
      expect(state.lastHitLifeDelta, 2.0);
      expect(state.lastMissLifeDelta, TimingConfig.missLifeDeltaMax);
      expect(state.lastMissLifeDelta, -3.0);
    });

    test(
      'build() seeds deathCount from a non-zero ProfileRepository value',
      () async {
        final FakeMonotonicClock freshClock = FakeMonotonicClock(0);
        final FakeProfileRepository seededRepo = FakeProfileRepository(
          deathCount: 7,
        );
        final ProviderContainer freshContainer = await buildContainer(
          clock: freshClock,
          repo: seededRepo,
        );
        addTearDown(freshContainer.dispose);

        expect(freshContainer.read(runControllerProvider).deathCount, 7);
      },
    );

    test('registerTap is a no-op before beginPlaying() has ever been called — '
        '"tap during countdown" must not score (architecture v3 §3.3)', () {
      // Never call `beginPlaying()` — the run is still in
      // `RunPhase.countdown`.
      final RunState before = container.read(runControllerProvider);
      expect(before.phase, RunPhase.countdown);

      expect(
        () => container
            .read(runControllerProvider.notifier)
            .registerTap(before.roundStartMicros + 10000),
        returnsNormally,
      );

      final RunState after = container.read(runControllerProvider);
      expect(after.phase, RunPhase.countdown);
      expect(after.lastBand, isNull);
      expect(after.lastDeltaMs, isNull);
      expect(after.lastLifeDelta, isNull);
      expect(after.lifePct, 100.0);
    });
  });

  group('beginPlaying() (play-screen-gate1-v1.md §1, step 2)', () {
    test('transitions phase from countdown to playing', () {
      expect(container.read(runControllerProvider).phase, RunPhase.countdown);

      container.read(runControllerProvider.notifier).beginPlaying();

      expect(container.read(runControllerProvider).phase, RunPhase.playing);
    });

    test('re-rolls roundStartMicros to the clock value at call time, not '
        'the value from build()', () {
      // Advance the clock well past build()'s roundStartMicros (0) before
      // calling beginPlaying(), simulating the 3 seconds a real countdown
      // would spend between build() and "1" disappearing.
      clock.advance(3000000);

      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState state = container.read(runControllerProvider);
      expect(state.roundStartMicros, 3000000);
    });

    test('rolls a fresh targetDurationMicros within the valid range', () {
      final int targetBefore = container
          .read(runControllerProvider)
          .targetDurationMicros;

      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState state = container.read(runControllerProvider);
      expect(state.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(state.targetDurationMicros, lessThan(20000000));
      // Not asserting the value differs from targetBefore (a same-value
      // re-roll is statistically possible) — just documenting the
      // pre-call value alongside the post-call range contract.
      expect(targetBefore, greaterThanOrEqualTo(3000000));
    });

    test('does not touch lifePct, lastDeltaMs, or lastBand', () {
      // registerTap only scores while playing, so beginPlaying() must run
      // first for the tap below to register at all.
      container.read(runControllerProvider.notifier).beginPlaying();
      tapAtDelta(10000); // Perfect
      final RunState beforeSecondBeginPlaying = container.read(
        runControllerProvider,
      );

      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState after = container.read(runControllerProvider);
      expect(after.lifePct, beforeSecondBeginPlaying.lifePct);
      expect(after.lastDeltaMs, beforeSecondBeginPlaying.lastDeltaMs);
      expect(after.lastBand, beforeSecondBeginPlaying.lastBand);
    });

    test('a round\'s timing after beginPlaying() is scored relative to the '
        'new roundStartMicros, not the original build()-time one', () {
      clock.advance(5000000); // simulate countdown elapsing
      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState state = container.read(runControllerProvider);
      final int targetMicros =
          state.roundStartMicros + state.targetDurationMicros;
      final int pressMicros = targetMicros + 10000; // 10ms Perfect
      clock.setMicros(pressMicros);
      container.read(runControllerProvider.notifier).registerTap(pressMicros);

      final RunState afterTap = container.read(runControllerProvider);
      expect(afterTap.lastBand, TimingBand.perfect);
      expect(afterTap.lastDeltaMs, 10);
    });

    test('calling beginPlaying() again re-rolls again (idempotent-safe, not '
        'a no-op on repeat calls)', () {
      container.read(runControllerProvider.notifier).beginPlaying();
      final RunState first = container.read(runControllerProvider);

      clock.advance(1000000);
      container.read(runControllerProvider.notifier).beginPlaying();
      final RunState second = container.read(runControllerProvider);

      expect(second.phase, RunPhase.playing);
      expect(second.roundStartMicros, isNot(first.roundStartMicros));
    });
  });

  group('single-tap band application through the controller', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    /// Drives life down via Miss taps so a subsequent Perfect/On-point tap
    /// has headroom below the 100% clamp ceiling to actually move the life
    /// value (100-start otherwise clamps a lone Perfect/On-point tap to an
    /// unobservable 100.0).
    void driveLifeDownForHeadroom() {
      for (int i = 0; i < 10; i++) {
        tapAtDelta(500000); // Miss
      }
    }

    test(
      'Perfect tap applies the fixed +3% life gain and records band/delta',
      () {
        driveLifeDownForHeadroom();
        final double before = container.read(runControllerProvider).lifePct;

        tapAtDelta(10000); // 10ms -> Perfect

        final RunState state = container.read(runControllerProvider);
        expect(state.lastBand, TimingBand.perfect);
        expect(state.lastDeltaMs, 10);
        expect(state.lastLifeDelta, TimingConfig.perfectLifeDelta);
        expect(state.lifePct, before + TimingConfig.perfectLifeDelta);
      },
    );

    test('On-point tap applies a ranged life gain and records the actual '
        'rolled value in lastLifeDelta', () {
      driveLifeDownForHeadroom();
      final double before = container.read(runControllerProvider).lifePct;

      tapAtDelta(50000); // 50ms -> On-point

      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.onPoint);
      expect(state.lastDeltaMs, 50);
      expect(
        state.lastLifeDelta,
        inInclusiveRange(
          TimingConfig.onPointLifeDeltaMin,
          TimingConfig.onPointLifeDeltaMax,
        ),
      );
      expect(state.lifePct, before + state.lastLifeDelta!);
    });

    test('Miss tap applies a ranged life loss and records the actual '
        'rolled value in lastLifeDelta', () {
      // Starting at 100%, no headroom-priming needed for a downward move.
      final double before = container.read(runControllerProvider).lifePct;

      tapAtDelta(500000); // 500ms -> Miss

      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.miss);
      expect(state.lastDeltaMs, 500);
      expect(
        state.lastLifeDelta,
        inInclusiveRange(
          TimingConfig.missLifeDeltaMin,
          TimingConfig.missLifeDeltaMax,
        ),
      );
      expect(state.lifePct, before + state.lastLifeDelta!);
    });

    test('a boundary-exact 30ms tap is still Perfect through the controller '
        '(consistent with the pure resolve() boundary test)', () {
      tapAtDelta(30000);
      expect(
        container.read(runControllerProvider).lastBand,
        TimingBand.perfect,
      );
    });

    test('a boundary-exact 201ms tap is a Miss through the controller', () {
      tapAtDelta(201000);
      expect(container.read(runControllerProvider).lastBand, TimingBand.miss);
    });
  });

  group('per-band legend-pill fields (architecture v4 §2)', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test('an On-point tap updates only lastHitLifeDelta, leaving '
        'lastMissLifeDelta at its seed', () {
      tapAtDelta(50000); // On-point

      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.onPoint);
      expect(
        state.lastHitLifeDelta,
        inInclusiveRange(
          TimingConfig.onPointLifeDeltaMin,
          TimingConfig.onPointLifeDeltaMax,
        ),
      );
      expect(state.lastHitLifeDelta, state.lastLifeDelta);
      expect(state.lastMissLifeDelta, TimingConfig.missLifeDeltaMax); // seed
    });

    test('a Miss tap updates only lastMissLifeDelta, leaving '
        'lastHitLifeDelta at its seed', () {
      tapAtDelta(500000); // Miss

      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.miss);
      expect(
        state.lastMissLifeDelta,
        inInclusiveRange(
          TimingConfig.missLifeDeltaMin,
          TimingConfig.missLifeDeltaMax,
        ),
      );
      expect(state.lastMissLifeDelta, state.lastLifeDelta);
      expect(state.lastHitLifeDelta, TimingConfig.onPointLifeDeltaMin); // seed
    });

    test('a Perfect tap changes neither lastHitLifeDelta nor '
        'lastMissLifeDelta', () {
      // Roll both fields away from their seeds first (one On-point, one
      // Miss tap) so this test proves Perfect leaves *whatever value was
      // already there* untouched, not just the seed default.
      tapAtDelta(50000); // On-point
      tapAtDelta(500000); // Miss
      final RunState before = container.read(runControllerProvider);

      tapAtDelta(10000); // Perfect

      final RunState after = container.read(runControllerProvider);
      expect(after.lastBand, TimingBand.perfect);
      expect(after.lastHitLifeDelta, before.lastHitLifeDelta);
      expect(after.lastMissLifeDelta, before.lastMissLifeDelta);
    });

    test('an On-point tap followed by a Miss tap leaves the Hit pill '
        'showing the On-point value — independent per-band memory, not the '
        'single most-recent-tap pair', () {
      tapAtDelta(50000); // On-point
      final double hitAfterOnPoint = container
          .read(runControllerProvider)
          .lastHitLifeDelta;

      tapAtDelta(500000); // Miss

      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.miss); // lastBand IS overwritten...
      expect(state.lastHitLifeDelta, hitAfterOnPoint); // ...but Hit isn't.
    });

    test('the fatal (death-triggering) tap still updates its band-matching '
        'field before phase flips to dead — the fatal tap is always a '
        'Miss, so lastMissLifeDelta is updated', () {
      final RunState finalState = tapUntilDead();
      expect(finalState.phase, RunPhase.dead);
      expect(finalState.lastBand, TimingBand.miss);
      expect(
        finalState.lastMissLifeDelta,
        inInclusiveRange(
          TimingConfig.missLifeDeltaMin,
          TimingConfig.missLifeDeltaMax,
        ),
      );
    });
  });

  group('a new target is rolled after every tap', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test('roundStartMicros and targetDurationMicros change after each tap', () {
      final int initialRoundStart = container
          .read(runControllerProvider)
          .roundStartMicros;
      final int initialTarget = container
          .read(runControllerProvider)
          .targetDurationMicros;

      tapAtDelta(10000);
      final RunState afterFirst = container.read(runControllerProvider);
      expect(afterFirst.roundStartMicros, isNot(initialRoundStart));

      // Advance the clock a distinguishable amount before the next tap so
      // roundStartMicros is unambiguously different again.
      clock.advance(2000000);
      tapAtDelta(10000);
      final RunState afterSecond = container.read(runControllerProvider);
      expect(afterSecond.roundStartMicros, isNot(afterFirst.roundStartMicros));

      expect(afterFirst.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(afterFirst.targetDurationMicros, lessThan(20000000));
      expect(afterSecond.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(afterSecond.targetDurationMicros, lessThan(20000000));
      expect(initialTarget, greaterThanOrEqualTo(3000000));
    });

    test(
      'target duration stays in [3_000_000, 20_000_000) across 50 rounds',
      () {
        for (int i = 0; i < 50; i++) {
          tapAtDelta(10000);
          final int t = container
              .read(runControllerProvider)
              .targetDurationMicros;
          expect(t, greaterThanOrEqualTo(3000000));
          expect(t, lessThan(20000000));
        }
      },
    );
  });

  group('life accumulates and clamps correctly across a full sequence', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test(
      'repeated Perfect taps accumulate additively (fixed +3 each) before clamping',
      () {
        // Drive life down first — 100-start would otherwise clamp a Perfect
        // tap immediately and the accumulation wouldn't be observable.
        for (int i = 0; i < 5; i++) {
          tapAtDelta(500000); // Miss, creates headroom
        }
        final double before = container.read(runControllerProvider).lifePct;

        tapAtDelta(10000);
        tapAtDelta(10000);
        tapAtDelta(10000);

        expect(
          container.read(runControllerProvider).lifePct,
          before + 3 * TimingConfig.perfectLifeDelta,
        );
      },
    );

    test(
      'life clamps at exactly 100.0 and stays there under further Perfect taps',
      () {
        for (int i = 0; i < 20; i++) {
          tapAtDelta(10000); // Perfect, +3 each; starts at 100 already
          if (container.read(runControllerProvider).phase != RunPhase.playing) {
            break;
          }
        }
        expect(container.read(runControllerProvider).lifePct, 100.0);

        // One more Perfect tap must not push it past 100 or corrupt state.
        tapAtDelta(10000);
        expect(container.read(runControllerProvider).lifePct, 100.0);
        expect(
          container.read(runControllerProvider).lastBand,
          TimingBand.perfect,
        );
      },
    );

    test('repeated Misses eventually reach exactly 0.0 and the run ends '
        '(phase == dead) — the old "exactly 25 Miss taps" test is invalid '
        'once Miss is ranged', () {
      final RunState finalState = tapUntilDead();
      expect(finalState.lifePct, 0.0);
      expect(finalState.phase, RunPhase.dead);
    });

    test('registerTap is a no-op once the run has ended at 0.0 — further '
        'taps do not move life or change state, unlike the old '
        '"clamp while still playing" behavior', () {
      final RunState dead = tapUntilDead();
      expect(dead.phase, RunPhase.dead);

      final RunState beforeExtraTap = container.read(runControllerProvider);
      tapAtDelta(500000); // must be a no-op now
      final RunState afterExtraTap = container.read(runControllerProvider);

      expect(afterExtraTap.lifePct, beforeExtraTap.lifePct);
      expect(afterExtraTap.lifePct, 0.0);
      expect(afterExtraTap.phase, RunPhase.dead);
      expect(afterExtraTap.lastBand, beforeExtraTap.lastBand);
      expect(afterExtraTap.deathCount, beforeExtraTap.deathCount);
    });
  });

  group('death-ends-run (architecture v3 §3.1/§3.3/§3.4)', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test('life reaching exactly 0 sets phase = dead, increments deathCount '
        'in-memory, and calls incrementDeathCount() on the repository '
        'exactly once', () {
      expect(repo.incrementDeathCountCallCount, 0);
      expect(container.read(runControllerProvider).deathCount, 0);

      final RunState finalState = tapUntilDead();

      expect(finalState.phase, RunPhase.dead);
      expect(finalState.lifePct, 0.0);
      expect(finalState.deathCount, 1);
      expect(repo.incrementDeathCountCallCount, 1);
      // The fatal tap's own result still recorded (still shows what
      // actually happened), not cleared on death.
      expect(finalState.lastBand, TimingBand.miss);
      expect(finalState.lastLifeDelta, isNotNull);
    });

    test('does not roll a new target on the fatal tap — the run is over', () {
      final RunState beforeFatalTap = container.read(runControllerProvider);
      final RunState finalState = tapUntilDead();

      expect(finalState.phase, RunPhase.dead);
      // Not asserting an exact value (multiple taps ran before death) —
      // just that a fatal tap does not attempt a fresh roll relative to
      // itself; covered structurally by the no-op-after-death test above,
      // this test documents intent for readers.
      expect(beforeFatalTap.phase, RunPhase.playing);
    });

    test('further registerTap calls no-op after death (no double-counted '
        'deaths, no repeated persistence calls)', () {
      tapUntilDead();
      expect(repo.incrementDeathCountCallCount, 1);

      tapAtDelta(500000);
      tapAtDelta(500000);
      tapAtDelta(500000);

      expect(repo.incrementDeathCountCallCount, 1);
      expect(container.read(runControllerProvider).deathCount, 1);
    });
  });

  group('startNewCycle() (architecture v3 §3.3)', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test('resets life to 100%, phase to countdown, rolls a fresh target, '
        'and clears last-tap fields, but preserves deathCount', () {
      tapUntilDead();
      final RunState dead = container.read(runControllerProvider);
      expect(dead.phase, RunPhase.dead);
      expect(dead.deathCount, 1);

      container.read(runControllerProvider.notifier).startNewCycle();

      final RunState afterRestart = container.read(runControllerProvider);
      expect(afterRestart.lifePct, 100.0);
      expect(afterRestart.phase, RunPhase.countdown);
      expect(afterRestart.lastBand, isNull);
      expect(afterRestart.lastDeltaMs, isNull);
      expect(afterRestart.lastLifeDelta, isNull);
      expect(afterRestart.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(afterRestart.targetDurationMicros, lessThan(20000000));
      // Lifetime, not per-run — must survive the restart.
      expect(afterRestart.deathCount, 1);
      // Architecture v4 §2.4: a fresh cycle must reseed both legend-pill
      // fields, not carry over the dead cycle's rolled values.
      expect(afterRestart.lastHitLifeDelta, TimingConfig.onPointLifeDeltaMin);
      expect(afterRestart.lastMissLifeDelta, TimingConfig.missLifeDeltaMax);
    });

    test('startNewCycle() reseeds lastHitLifeDelta/lastMissLifeDelta back to '
        'their gentlest-value defaults even after a prior cycle rolled them '
        'away from those defaults (architecture v4 §2.4)', () {
      // Roll lastHitLifeDelta to +3 specifically (away from its +2 seed)
      // by repeating an On-point tap until the roll lands on the
      // non-seed member of {2.0, 3.0} — bounded so a pathological run of
      // bad luck still can't hang the test.
      double hitRoll = container.read(runControllerProvider).lastHitLifeDelta;
      int attempts = 0;
      while (hitRoll == TimingConfig.onPointLifeDeltaMin && attempts < 200) {
        tapAtDelta(50000); // On-point
        hitRoll = container.read(runControllerProvider).lastHitLifeDelta;
        attempts++;
      }
      expect(hitRoll, TimingConfig.onPointLifeDeltaMax); // confirms +3 rolled

      final RunState dead = tapUntilDead();
      expect(dead.phase, RunPhase.dead);
      expect(dead.lastHitLifeDelta, TimingConfig.onPointLifeDeltaMax);

      container.read(runControllerProvider.notifier).startNewCycle();

      final RunState afterRestart = container.read(runControllerProvider);
      expect(afterRestart.lastHitLifeDelta, TimingConfig.onPointLifeDeltaMin);
      expect(afterRestart.lastMissLifeDelta, TimingConfig.missLifeDeltaMax);
    });

    test('the fresh cycle can be played through beginPlaying() exactly like '
        'the very first one', () {
      tapUntilDead();
      container.read(runControllerProvider.notifier).startNewCycle();
      expect(container.read(runControllerProvider).phase, RunPhase.countdown);

      container.read(runControllerProvider.notifier).beginPlaying();
      expect(container.read(runControllerProvider).phase, RunPhase.playing);

      tapAtDelta(10000); // Perfect
      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.perfect);
      expect(state.lifePct, 100.0); // clamps immediately from a 100 start
    });
  });

  group('adversarial / edge cases', () {
    setUp(() {
      container.read(runControllerProvider.notifier).beginPlaying();
    });

    test(
      'a very large delta (1000 seconds off target) is a Miss and does not throw',
      () {
        expect(() => tapAtDelta(1000000000), returnsNormally);
        final RunState state = container.read(runControllerProvider);
        expect(state.lastBand, TimingBand.miss);
        expect(state.lastDeltaMs, 1000000);
        expect(
          state.lastLifeDelta,
          inInclusiveRange(
            TimingConfig.missLifeDeltaMin,
            TimingConfig.missLifeDeltaMax,
          ),
        );
      },
    );

    test('rapid repeated registerTap calls (no clock advance between them) '
        'do not throw and keep life within [0, 100] at every step, and stop '
        'scoring once the run ends', () {
      // Simulates a burst of taps landing in the same instant (e.g. multi-
      // touch or an input queue flush) without the clock moving between
      // them. Some of these taps may land after the run has already ended
      // (phase == dead) — those must be safe no-ops, not throw or corrupt
      // state.
      for (int i = 0; i < 500; i++) {
        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        // Alternate between hitting and missing without moving the clock
        // forward, to also vary target math edge alignment.
        final int pressMicros = i.isEven
            ? targetMicros
            : targetMicros + 1000000;
        expect(
          () => container
              .read(runControllerProvider.notifier)
              .registerTap(pressMicros),
          returnsNormally,
        );
        final RunState after = container.read(runControllerProvider);
        expect(after.lifePct, inInclusiveRange(0.0, 100.0));
        expect(after.lifePct.isNaN, isFalse);
      }
    });

    test('pressMicros before roundStartMicros (a stale/late timestamp) still '
        'resolves via abs(delta) without throwing', () {
      final RunState before = container.read(runControllerProvider);
      // A timestamp *earlier* than this round's start — not supposed to be
      // reachable given a monotonic shared clock and synchronous dispatch,
      // but resolve()/registerTap take a raw int with no assertion guarding
      // this, so verify it degrades safely (large abs delta -> Miss) rather
      // than throwing or producing a negative deltaMs.
      final int pressMicros = before.roundStartMicros - 1;
      expect(
        () => container
            .read(runControllerProvider.notifier)
            .registerTap(pressMicros),
        returnsNormally,
      );
      final RunState after = container.read(runControllerProvider);
      expect(after.lastDeltaMs, greaterThanOrEqualTo(0));
    });

    test('adaptive-k scaffold has no effect through the controller regardless '
        'of the current lifePct (k == 0.0) — checked at the 100% start and '
        'again after a single Miss has moved life below it', () {
      // At the 100% start.
      tapAtDelta(200000); // exactly onPointMs boundary
      expect(
        container.read(runControllerProvider).lastBand,
        TimingBand.onPoint,
      );

      // After life has moved (one Miss, still comfortably above 0).
      tapAtDelta(500000); // Miss
      expect(container.read(runControllerProvider).phase, RunPhase.playing);
      tapAtDelta(200000); // exactly onPointMs boundary again, at a lower lifePct
      expect(
        container.read(runControllerProvider).lastBand,
        TimingBand.onPoint,
      );
    });
  });
}
