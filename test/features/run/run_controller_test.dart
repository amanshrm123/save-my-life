// Integration tests for `RunController` (lib/features/run/run_controller.dart)
// — the Notifier that owns life%/target/last-tap-result and is the only
// thing that calls `resolve()` and mutates life. These tests exercise the
// controller itself (not the pure `resolve()` function, which already has
// full boundary coverage in test/features/timing_engine/timing_engine_test.dart).
//
// `clockProvider` is overridden with a `FakeMonotonicClock` so target
// timing is fully deterministic and doesn't require waiting on real
// wall-clock seconds (see test/support/fake_monotonic_clock.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/features/run/run_controller.dart';
import 'package:timing_tap/features/timing_engine/timing_engine.dart';

import '../../support/fake_monotonic_clock.dart';

void main() {
  late FakeMonotonicClock clock;
  late ProviderContainer container;

  setUp(() {
    clock = FakeMonotonicClock(0);
    container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Registers a tap that lands exactly [deltaMicros] away from the
  /// *current* round's target, via the real `RunController.registerTap`
  /// (not `resolve()` directly) — exercises target lookup, life clamp,
  /// state replacement, and the next-round roll together.
  void tapAtDelta(int deltaMicros) {
    final RunState before = container.read(runControllerProvider);
    final int targetMicros = before.roundStartMicros + before.targetDurationMicros;
    final int pressMicros = targetMicros + deltaMicros;
    clock.setMicros(pressMicros);
    container.read(runControllerProvider.notifier).registerTap(pressMicros);
  }

  group('initial state', () {
    test('starts at 50% life, countdown phase, no prior tap, target in range', () {
      final RunState state = container.read(runControllerProvider);
      expect(state.lifePct, 50.0);
      expect(state.phase, RunPhase.countdown);
      expect(state.lastDeltaMs, isNull);
      expect(state.lastBand, isNull);
      expect(state.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(state.targetDurationMicros, lessThan(20000000));
      expect(state.roundStartMicros, 0); // clock started at 0
    });

    test(
      'accessing the notifier directly (without first reading state) still '
      'produces a fully-initialized run — "tap before any round started" is '
      'not reachable through the public API',
      () {
        // Fresh container: never touch `runControllerProvider` (the state
        // provider) before calling through the notifier.
        final ProviderContainer freshContainer = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(FakeMonotonicClock(500))],
        );
        addTearDown(freshContainer.dispose);

        // This lazily runs RunController.build() first, exactly as
        // Riverpod guarantees for any Notifier access — so there is no
        // window where `registerTap` could run against an uninitialized
        // RunState. (Target duration is randomized per-round, so we don't
        // predict which band this lands in — only that it completes
        // safely and produces a fully-formed result.)
        expect(
          () => freshContainer
              .read(runControllerProvider.notifier)
              .registerTap(500 + 10000),
          returnsNormally,
        );

        final RunState state = freshContainer.read(runControllerProvider);
        expect(state.lastBand, isNotNull);
        expect(state.lastDeltaMs, isNotNull);
        expect(state.lifePct, inInclusiveRange(0.0, 100.0));
      },
    );
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
      final int targetBefore =
          container.read(runControllerProvider).targetDurationMicros;

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
      // Register a tap first so lastDeltaMs/lastBand are non-null, then
      // confirm beginPlaying() leaves them untouched (it only owns
      // phase/roundStartMicros/targetDurationMicros per the spec).
      tapAtDelta(10000); // Perfect
      final RunState beforeBeginPlaying = container.read(runControllerProvider);

      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState after = container.read(runControllerProvider);
      expect(after.lifePct, beforeBeginPlaying.lifePct);
      expect(after.lastDeltaMs, beforeBeginPlaying.lastDeltaMs);
      expect(after.lastBand, beforeBeginPlaying.lastBand);
    });

    test('a round\'s timing after beginPlaying() is scored relative to the '
        'new roundStartMicros, not the original build()-time one', () {
      clock.advance(5000000); // simulate countdown elapsing
      container.read(runControllerProvider.notifier).beginPlaying();

      final RunState state = container.read(runControllerProvider);
      final int targetMicros = state.roundStartMicros + state.targetDurationMicros;
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
    test('Perfect tap applies +3% life and records band/delta', () {
      tapAtDelta(10000); // 10ms
      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.perfect);
      expect(state.lastDeltaMs, 10);
      expect(state.lifePct, 53.0);
    });

    test('On-point tap applies +2% life', () {
      tapAtDelta(50000); // 50ms
      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.onPoint);
      expect(state.lastDeltaMs, 50);
      expect(state.lifePct, 52.0);
    });

    test('Miss tap applies -4% life', () {
      tapAtDelta(500000); // 500ms
      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.miss);
      expect(state.lastDeltaMs, 500);
      expect(state.lifePct, 46.0);
    });

    test('a boundary-exact 30ms tap is still Perfect through the controller '
        '(consistent with the pure resolve() boundary test)', () {
      tapAtDelta(30000);
      expect(container.read(runControllerProvider).lastBand, TimingBand.perfect);
    });

    test('a boundary-exact 81ms tap is a Miss through the controller', () {
      tapAtDelta(81000);
      expect(container.read(runControllerProvider).lastBand, TimingBand.miss);
    });
  });

  group('a new target is rolled after every tap', () {
    test('roundStartMicros and targetDurationMicros change after each tap', () {
      final int initialRoundStart = container.read(runControllerProvider).roundStartMicros;
      final int initialTarget = container.read(runControllerProvider).targetDurationMicros;

      tapAtDelta(10000);
      final RunState afterFirst = container.read(runControllerProvider);
      expect(afterFirst.roundStartMicros, isNot(initialRoundStart));

      // Advance the clock a distinguishable amount before the next tap so
      // roundStartMicros is unambiguously different again.
      clock.advance(2000000);
      tapAtDelta(10000);
      final RunState afterSecond = container.read(runControllerProvider);
      expect(afterSecond.roundStartMicros, isNot(afterFirst.roundStartMicros));

      // Not asserting the target *values* differ from `initialTarget`
      // (a same-value re-roll is statistically possible, if astronomically
      // unlikely) — asserting the range contract holds every round instead.
      expect(afterFirst.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(afterFirst.targetDurationMicros, lessThan(20000000));
      expect(afterSecond.targetDurationMicros, greaterThanOrEqualTo(3000000));
      expect(afterSecond.targetDurationMicros, lessThan(20000000));
      // Silence "unused" for initialTarget while keeping the round-trip
      // documented for readers.
      expect(initialTarget, greaterThanOrEqualTo(3000000));
    });

    test('target duration stays in [3_000_000, 20_000_000) across 50 rounds', () {
      for (int i = 0; i < 50; i++) {
        tapAtDelta(10000);
        final int t = container.read(runControllerProvider).targetDurationMicros;
        expect(t, greaterThanOrEqualTo(3000000));
        expect(t, lessThan(20000000));
      }
    });
  });

  group('life accumulates and clamps correctly across a full sequence', () {
    test('repeated same-band taps accumulate additively before clamping', () {
      // 50 -> 53 -> 56 -> 59 (three Perfect taps, no clamp yet).
      tapAtDelta(10000);
      tapAtDelta(10000);
      tapAtDelta(10000);
      expect(container.read(runControllerProvider).lifePct, 59.0);
    });

    test('life clamps at exactly 100.0 and stays there under further Perfect taps', () {
      // 50 -> 100 crosses at some point before 17 taps; clamp must hold.
      for (int i = 0; i < 20; i++) {
        tapAtDelta(10000); // Perfect, +3 each
      }
      expect(container.read(runControllerProvider).lifePct, 100.0);

      // One more Perfect tap must not push it past 100 or corrupt state.
      tapAtDelta(10000);
      expect(container.read(runControllerProvider).lifePct, 100.0);
      expect(container.read(runControllerProvider).lastBand, TimingBand.perfect);
    });

    test('life clamps at exactly 0.0 and stays there under further Miss taps', () {
      // 25 Miss taps: 100 - 4*25 == 0 exactly if starting from 100; from the
      // 50% starting point it clamps well before 25.
      for (int i = 0; i < 20; i++) {
        tapAtDelta(500000); // Miss, -4 each
      }
      expect(container.read(runControllerProvider).lifePct, 0.0);

      // One more Miss must not go negative or corrupt state.
      tapAtDelta(500000);
      expect(container.read(runControllerProvider).lifePct, 0.0);
      expect(container.read(runControllerProvider).lastBand, TimingBand.miss);
    });

    test('life reaches exactly 0.0 from exactly 100.0 after exactly 25 Miss taps', () {
      for (int i = 0; i < 20; i++) {
        tapAtDelta(10000); // drive to 100 first
      }
      expect(container.read(runControllerProvider).lifePct, 100.0);

      for (int i = 0; i < 25; i++) {
        tapAtDelta(500000); // -4 each; 100 - 4*25 == 0
      }
      expect(container.read(runControllerProvider).lifePct, 0.0);
    });
  });

  group('adversarial / edge cases', () {
    test('a very large delta (1000 seconds off target) is a Miss and does not throw', () {
      expect(() => tapAtDelta(1000000000), returnsNormally);
      final RunState state = container.read(runControllerProvider);
      expect(state.lastBand, TimingBand.miss);
      expect(state.lastDeltaMs, 1000000);
      expect(state.lifePct, 46.0);
    });

    test('rapid repeated registerTap calls (no clock advance between them) '
        'do not throw and keep life within [0, 100] at every step', () {
      // Simulates a burst of taps landing in the same instant (e.g. multi-
      // touch or an input queue flush) without the clock moving between
      // them. Each call still resolves against whatever the *current*
      // state's target is at the moment it runs (synchronous, no stale
      // read), so this also probes for any cross-call state corruption.
      for (int i = 0; i < 500; i++) {
        final RunState before = container.read(runControllerProvider);
        final int targetMicros = before.roundStartMicros + before.targetDurationMicros;
        // Alternate between hitting and missing without moving the clock
        // forward, to also vary target math edge alignment.
        final int pressMicros = i.isEven ? targetMicros : targetMicros + 1000000;
        expect(
          () => container.read(runControllerProvider.notifier).registerTap(pressMicros),
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
        () => container.read(runControllerProvider.notifier).registerTap(pressMicros),
        returnsNormally,
      );
      final RunState after = container.read(runControllerProvider);
      expect(after.lastDeltaMs, greaterThanOrEqualTo(0));
    });

    test('adaptive-k scaffold has no effect through the controller at life 0% or 100%', () {
      // Drive life to 0, then confirm an 80ms tap (the onPointMs boundary)
      // is still On-point rather than being tightened by life% (k == 0.0
      // per TimingConfig; adaptive tightening is explicitly OUT for v1).
      for (int i = 0; i < 20; i++) {
        tapAtDelta(500000); // Miss repeatedly -> life clamps to 0
      }
      expect(container.read(runControllerProvider).lifePct, 0.0);
      tapAtDelta(80000); // exactly onPointMs boundary
      expect(container.read(runControllerProvider).lastBand, TimingBand.onPoint);

      for (int i = 0; i < 40; i++) {
        tapAtDelta(10000); // Perfect repeatedly -> life climbs to 100
      }
      expect(container.read(runControllerProvider).lifePct, 100.0);
      tapAtDelta(80000); // exactly onPointMs boundary, now at life == 100
      expect(container.read(runControllerProvider).lastBand, TimingBand.onPoint);
    });
  });
}
