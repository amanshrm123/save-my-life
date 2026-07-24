import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/scoring.dart';

/// Architecture v2 §3 — this project's #1 priority for any logical change.
/// `classifyStop` decides Perfect/Hit/Miss from `error = (stopped -
/// target).abs()`; `lifeDeltaForTier` converts that tier into the life swing
/// that drives everything else in the run (death, final band, eternal).
/// Every boundary here is tested on both sides and in both the undershoot
/// (stopped before target) and overshoot (stopped after target) directions,
/// since `.abs()` must treat them identically.
void main() {
  const config = RunConfig.defaults;
  const target = Duration(seconds: 90); // arbitrary mid-range target

  group('classifyStop — tier boundaries (RunConfig.defaults: '
      'perfectBandMs=60, hitBandMs=180)', () {
    test('error == 0 -> perfect', () {
      expect(
        classifyStop(target: target, stopped: target, config: config),
        StopTier.perfect,
      );
    });

    test('error == 60ms (== perfectBandMs) -> perfect, undershoot', () {
      final stopped = target - const Duration(milliseconds: 60);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.perfect,
      );
    });

    test('error == 60ms (== perfectBandMs) -> perfect, overshoot', () {
      final stopped = target + const Duration(milliseconds: 60);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.perfect,
      );
    });

    test('error == 61ms (just above perfectBandMs) -> hit, undershoot', () {
      final stopped = target - const Duration(milliseconds: 61);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.hit,
      );
    });

    test('error == 61ms (just above perfectBandMs) -> hit, overshoot', () {
      final stopped = target + const Duration(milliseconds: 61);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
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
        '|error| on either side', () {
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
      expect(under, StopTier.perfect);
      expect(over, StopTier.perfect);
    });

    test('microsecond precision is honoured, not just whole milliseconds '
        '(errorMs is truncated from microseconds, so 60ms + 900us is still '
        '<= 60ms once truncated to int milliseconds)', () {
      final stopped =
          target + const Duration(milliseconds: 60, microseconds: 900);
      expect(
        classifyStop(target: target, stopped: stopped, config: config),
        StopTier.perfect,
        reason: '60ms 900us truncates to 60ms via Duration.inMilliseconds, '
            'which is <= perfectBandMs',
      );
    });

    test('a custom RunConfig is honoured, not a hardcoded 60/180 default', () {
      const tightConfig = RunConfig(perfectBandMs: 10, hitBandMs: 20);
      expect(
        classifyStop(
          target: target,
          stopped: target + const Duration(milliseconds: 10),
          config: tightConfig,
        ),
        StopTier.perfect,
      );
      expect(
        classifyStop(
          target: target,
          stopped: target + const Duration(milliseconds: 15),
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

  group('lifeDeltaForTier (RunConfig.defaults: perfect +3, hit +2, miss -5)', () {
    test('perfect -> config.perfectDelta', () {
      expect(lifeDeltaForTier(StopTier.perfect, config), config.perfectDelta);
      expect(lifeDeltaForTier(StopTier.perfect, config), 3);
    });

    test('hit -> config.hitDelta', () {
      expect(lifeDeltaForTier(StopTier.hit, config), config.hitDelta);
      expect(lifeDeltaForTier(StopTier.hit, config), 2);
    });

    test('miss -> config.missDelta (negative)', () {
      expect(lifeDeltaForTier(StopTier.miss, config), config.missDelta);
      expect(lifeDeltaForTier(StopTier.miss, config), -5);
    });

    test('reads from the given RunConfig, not RunConfig.defaults', () {
      const customConfig = RunConfig(perfectDelta: 10, hitDelta: 1, missDelta: -50);
      expect(lifeDeltaForTier(StopTier.perfect, customConfig), 10);
      expect(lifeDeltaForTier(StopTier.hit, customConfig), 1);
      expect(lifeDeltaForTier(StopTier.miss, customConfig), -50);
    });
  });
}
