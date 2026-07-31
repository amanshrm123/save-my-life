import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/scoring.dart';

/// Architecture v6 §3 (revising v2 §3's 3-tier model to a single band) —
/// this project's #1 priority for any logical change. `classifyStop` now
/// decides Hit/Miss purely from `error = (stopped - target).abs()` against
/// the single `hitBandMs` band (`StopTier.perfect`/`perfectBandMs` are
/// deleted, not retained-and-unused). `lifeDeltaForTier` converts that tier
/// into the life swing that drives everything else in the run (death, final
/// band, eternal) — now `hit -> 0` ("safe", life never rises),
/// `miss -> missDelta` (-10). Every boundary here is tested on both sides
/// and in both the undershoot (stopped before target) and overshoot
/// (stopped after target) directions, since `.abs()` must treat them
/// identically.
void main() {
  const config = RunConfig.defaults;
  const target = Duration(seconds: 90); // arbitrary mid-range target

  group('classifyStop — single-band boundary (RunConfig.defaults: '
      'hitBandMs=180)', () {
    test('error == 0 -> hit', () {
      expect(
        classifyStop(target: target, stopped: target, config: config),
        StopTier.hit,
      );
    });

    test('error == 180ms (== hitBandMs) -> hit, undershoot', () {
      final stopped = target - const Duration(milliseconds: 180);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.hit,
      );
    });

    test('error == 180ms (== hitBandMs) -> hit, overshoot', () {
      final stopped = target + const Duration(milliseconds: 180);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.hit,
      );
    });

    test('error == 181ms (just above hitBandMs) -> miss, undershoot', () {
      final stopped = target - const Duration(milliseconds: 181);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.miss,
      );
    });

    test('error == 181ms (just above hitBandMs) -> miss, overshoot', () {
      final stopped = target + const Duration(milliseconds: 181);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.miss,
      );
    });

    test('a huge overshoot is still a miss', () {
      final stopped = target + const Duration(seconds: 5);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.miss,
      );
    });

    test('a huge undershoot (including stopping at zero) is still a miss', () {
      expect(
        classifyStop(target: target, stopped: Duration.zero, config: config),
        StopTier.miss,
      );
    });

    test('classification is symmetric around the target for an identical '
        '|error| on either side, comfortably inside the band', () {
      const error = Duration(milliseconds: 45);
      final under = classifyStop(
        target: target,
        stopped: target - error,
        config: config,
      );
      final over = classifyStop(
        target: target,
        stopped: target + error,
        config: config,
      );
      expect(under, StopTier.hit);
      expect(over, StopTier.hit);
    });

    test('classification is symmetric around the target just past the band '
        'too', () {
      const error = Duration(milliseconds: 181);
      final under = classifyStop(
        target: target,
        stopped: target - error,
        config: config,
      );
      final over = classifyStop(
        target: target,
        stopped: target + error,
        config: config,
      );
      expect(under, StopTier.miss);
      expect(over, StopTier.miss);
    });

    test('microsecond precision is honoured, not just whole milliseconds '
        '(errorMs is truncated from microseconds, so 180ms + 900us is still '
        '<= 180ms once truncated to int milliseconds)', () {
      final stopped =
          target + const Duration(milliseconds: 180, microseconds: 900);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.hit,
        reason: '180ms 900us truncates to 180ms via Duration.inMilliseconds, '
            'which is <= hitBandMs',
      );
    });

    test('a custom RunConfig is honoured, not a hardcoded 180 default', () {
      const tightConfig = RunConfig(hitBandMs: 20);
      expect(
        classifyStop(
          target: target,
          stopped: target + const Duration(milliseconds: 20),
          config: tightConfig,
        ),
        StopTier.hit,
      );
      expect(
        classifyStop(
          target: target,
          stopped: target + const Duration(milliseconds: 21),
          config: tightConfig,
        ),
        StopTier.miss,
      );
    });
  });

  group('lifeDeltaForTier (architecture v6 §3/§4.1: hit -> 0 "safe", '
      'miss -> -10)', () {
    test('lifeDeltaForTier(hit) == 0 — hit is neutral, life never rises', () {
      expect(lifeDeltaForTier(StopTier.hit, config), 0);
      expect(lifeDeltaForTier(StopTier.hit, config), config.hitDelta);
    });

    test('lifeDeltaForTier(miss) == -10', () {
      expect(lifeDeltaForTier(StopTier.miss, config), -10);
      expect(lifeDeltaForTier(StopTier.miss, config), config.missDelta);
    });

    test('reads from the given RunConfig, not RunConfig.defaults', () {
      const customConfig = RunConfig(
        hitDelta: 0,
        missDelta: -25,
        finalBandThresholdPercent: 25,
      );
      expect(lifeDeltaForTier(StopTier.hit, customConfig), 0);
      expect(lifeDeltaForTier(StopTier.miss, customConfig), -25);
    });
  });
}
