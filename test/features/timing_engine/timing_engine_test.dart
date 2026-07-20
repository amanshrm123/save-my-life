// Unit tests for the pure timing engine (lib/features/timing_engine/timing_engine.dart).
//
// Most deltas below are expressed as whole-millisecond multiples in
// microseconds (e.g. 30_000 micros == 30.000 ms) so the expected band is
// unambiguous. A few cases below use fractional-millisecond deltas
// specifically to assert that band decisions compare deltaMicros directly
// against thresholds — never against the rounded, display-only deltaMs.

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/timing_config.dart';
import 'package:timing_tap/features/timing_engine/timing_engine.dart';

void main() {
  const int target = 1000000; // arbitrary anchor, in microseconds
  const double midLife = 50.0;

  group('resolve() band boundaries', () {
    test('delta == 0 is Perfect', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.perfect);
      expect(result.deltaMs, 0);
      expect(result.lifeDelta, TimingConfig.perfectLifeDelta);
    });

    test('delta == exactly +30ms (perfectMs) is still Perfect (inclusive boundary)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 30000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.perfect);
      expect(result.deltaMs, 30);
      expect(result.lifeDelta, TimingConfig.perfectLifeDelta);
    });

    test('delta == exactly -30ms (press before target) is still Perfect', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target - 30000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.perfect);
      expect(result.deltaMs, 30);
    });

    test('delta == 31ms (just past perfectMs) is On-point', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 31000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 31);
      expect(result.lifeDelta, TimingConfig.onPointLifeDelta);
    });

    test('delta == exactly 80ms (onPointMs) is still On-point (inclusive boundary)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 80000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 80);
      expect(result.lifeDelta, TimingConfig.onPointLifeDelta);
    });

    test('delta == exactly -80ms (press before target) is still On-point', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target - 80000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 80);
    });

    test('delta == 81ms (just past onPointMs) is a Miss', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 81000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.miss);
      expect(result.deltaMs, 81);
      expect(result.lifeDelta, TimingConfig.missLifeDelta);
    });

    test('delta == 30.2ms rounds deltaMs to 30 but is On-point, not Perfect '
        '(guards against banding on the rounded display value)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 30200,
        lifePct: midLife,
      );
      expect(result.deltaMs, 30, reason: 'display value rounds down to 30');
      expect(result.band, TimingBand.onPoint,
          reason: 'true delta (30.2ms) exceeds the 30ms Perfect window');
    });

    test('delta == 80.2ms rounds deltaMs to 80 but is a Miss, not On-point '
        '(guards against banding on the rounded display value)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 80200,
        lifePct: midLife,
      );
      expect(result.deltaMs, 80, reason: 'display value rounds down to 80');
      expect(result.band, TimingBand.miss,
          reason: 'true delta (80.2ms) exceeds the 80ms On-point window');
    });

    test('a large delta is a Miss', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 5000000,
        lifePct: midLife,
      );
      expect(result.band, TimingBand.miss);
      expect(result.lifeDelta, TimingConfig.missLifeDelta);
    });
  });

  group('resolve() adaptive-k scaffold stays disabled', () {
    test('an 80ms delta is On-point regardless of lifePct (k == 0.0)', () {
      final atLowLife = resolve(
        targetMicros: target,
        pressMicros: target + 80000,
        lifePct: 0.0,
      );
      final atHighLife = resolve(
        targetMicros: target,
        pressMicros: target + 80000,
        lifePct: 100.0,
      );
      expect(atLowLife.band, TimingBand.onPoint);
      expect(atHighLife.band, TimingBand.onPoint);
    });
  });

  group('clampLifePct()', () {
    test('clamps values above 100 down to 100', () {
      expect(clampLifePct(150.0), 100.0);
    });

    test('clamps values below 0 up to 0', () {
      expect(clampLifePct(-25.0), 0.0);
    });

    test('leaves in-range values unchanged', () {
      expect(clampLifePct(62.5), 62.5);
    });

    test('leaves exact boundary values unchanged', () {
      expect(clampLifePct(0.0), 0.0);
      expect(clampLifePct(100.0), 100.0);
    });
  });
}
