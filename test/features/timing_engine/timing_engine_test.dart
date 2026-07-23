// Unit tests for the pure timing engine (lib/features/timing_engine/timing_engine.dart).
//
// Most deltas below are expressed as whole-millisecond multiples in
// microseconds (e.g. 30_000 micros == 30.000 ms) so the expected band is
// unambiguous. A few cases below use fractional-millisecond deltas
// specifically to assert that band decisions compare deltaMicros directly
// against thresholds — never against the rounded, display-only deltaMs.
//
// Architecture v3 §4 adds a required `lifeRoll` ([0, 1)) parameter to
// `resolve()` so life-delta *magnitude* can be rolled per tap while the
// function itself stays pure/deterministic (same inputs, including the
// roll, always produce the same output). Perfect ignores the roll
// entirely and stays fixed; On-point/Miss map the roll to their band's
// value set via the new pure `lifeDeltaFor` helper. Boundary tests below
// pass an explicit fixed `lifeRoll` (0.0 unless otherwise noted) so the
// band assertions remain unambiguous; a dedicated `lifeDeltaFor` group
// covers the roll -> magnitude mapping itself.

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
        lifeRoll: 0.0,
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
        lifeRoll: 0.0,
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
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.perfect);
      expect(result.deltaMs, 30);
    });

    test('delta == 31ms (just past perfectMs) is On-point', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 31000,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 31);
      expect(result.lifeDelta, TimingConfig.onPointLifeDeltaMin);
    });

    test('delta == exactly 200ms (onPointMs) is still On-point (inclusive boundary)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 200000,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 200);
      expect(result.lifeDelta, TimingConfig.onPointLifeDeltaMin);
    });

    test('delta == exactly -200ms (press before target) is still On-point', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target - 200000,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.onPoint);
      expect(result.deltaMs, 200);
    });

    test('delta == 201ms (just past onPointMs) is a Miss', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 201000,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.miss);
      expect(result.deltaMs, 201);
      expect(result.lifeDelta, TimingConfig.missLifeDeltaMin);
    });

    test('delta == 30.2ms rounds deltaMs to 30 but is On-point, not Perfect '
        '(guards against banding on the rounded display value)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 30200,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.deltaMs, 30, reason: 'display value rounds down to 30');
      expect(result.band, TimingBand.onPoint,
          reason: 'true delta (30.2ms) exceeds the 30ms Perfect window');
    });

    test('delta == 200.2ms rounds deltaMs to 200 but is a Miss, not On-point '
        '(guards against banding on the rounded display value)', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 200200,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.deltaMs, 200, reason: 'display value rounds down to 200');
      expect(result.band, TimingBand.miss,
          reason: 'true delta (200.2ms) exceeds the 200ms On-point window');
    });

    test('a large delta is a Miss', () {
      final result = resolve(
        targetMicros: target,
        pressMicros: target + 5000000,
        lifePct: midLife,
        lifeRoll: 0.0,
      );
      expect(result.band, TimingBand.miss);
      expect(result.lifeDelta, TimingConfig.missLifeDeltaMin);
    });
  });

  group('resolve() adaptive-k scaffold stays disabled', () {
    test('a 200ms delta is On-point regardless of lifePct (k == 0.0)', () {
      final atLowLife = resolve(
        targetMicros: target,
        pressMicros: target + 200000,
        lifePct: 0.0,
        lifeRoll: 0.0,
      );
      final atHighLife = resolve(
        targetMicros: target,
        pressMicros: target + 200000,
        lifePct: 100.0,
        lifeRoll: 0.0,
      );
      expect(atLowLife.band, TimingBand.onPoint);
      expect(atHighLife.band, TimingBand.onPoint);
    });
  });

  group('resolve() purity/determinism', () {
    test('identical inputs (including lifeRoll) always produce identical output', () {
      final a = resolve(
        targetMicros: target,
        pressMicros: target + 50000,
        lifePct: 37.0,
        lifeRoll: 0.42,
      );
      final b = resolve(
        targetMicros: target,
        pressMicros: target + 50000,
        lifePct: 37.0,
        lifeRoll: 0.42,
      );
      expect(a, b);
    });

    test('the magnitude never reads lifePct — only lifeRoll changes it, at a '
        'fixed lifeRoll varying lifePct does not change the on-point/miss '
        'life-delta magnitude', () {
      final atLowLife = resolve(
        targetMicros: target,
        pressMicros: target + 50000, // On-point
        lifePct: 0.0,
        lifeRoll: 0.9,
      );
      final atHighLife = resolve(
        targetMicros: target,
        pressMicros: target + 50000,
        lifePct: 100.0,
        lifeRoll: 0.9,
      );
      expect(atLowLife.lifeDelta, atHighLife.lifeDelta);
    });
  });

  group('lifeDeltaFor() — pure roll -> magnitude mapping (architecture v3 §4.2)', () {
    test('Perfect always returns the fixed perfectLifeDelta, ignoring the roll entirely', () {
      expect(lifeDeltaFor(TimingBand.perfect, 0.0), TimingConfig.perfectLifeDelta);
      expect(lifeDeltaFor(TimingBand.perfect, 0.5), TimingConfig.perfectLifeDelta);
      expect(lifeDeltaFor(TimingBand.perfect, 0.999), TimingConfig.perfectLifeDelta);
    });

    test('On-point: lifeRoll 0.0 maps to the floor (min) of the range', () {
      expect(lifeDeltaFor(TimingBand.onPoint, 0.0), TimingConfig.onPointLifeDeltaMin);
    });

    test('On-point: lifeRoll just under 1.0 maps to the ceiling (max) of the range', () {
      expect(lifeDeltaFor(TimingBand.onPoint, 0.999), TimingConfig.onPointLifeDeltaMax);
    });

    test('On-point: only ever returns a value from {2.0, 3.0} across the full roll span', () {
      for (double roll = 0.0; roll < 1.0; roll += 0.01) {
        expect(
          lifeDeltaFor(TimingBand.onPoint, roll),
          anyOf(TimingConfig.onPointLifeDeltaMin, TimingConfig.onPointLifeDeltaMax),
        );
      }
    });

    test('Miss: lifeRoll 0.0 maps to the floor (min, most negative) of the range', () {
      expect(lifeDeltaFor(TimingBand.miss, 0.0), TimingConfig.missLifeDeltaMin);
    });

    test('Miss: lifeRoll just under 1.0 maps to the ceiling (max, least negative) of the range', () {
      expect(lifeDeltaFor(TimingBand.miss, 0.999), TimingConfig.missLifeDeltaMax);
    });

    test('Miss: a mid-range roll lands on the middle value (-4.0), the third '
        'whole-integer step between -5.0 and -3.0', () {
      expect(lifeDeltaFor(TimingBand.miss, 0.5), -4.0);
    });

    test('Miss: only ever returns a value from {-5.0, -4.0, -3.0} across the full roll span', () {
      for (double roll = 0.0; roll < 1.0; roll += 0.01) {
        expect(
          lifeDeltaFor(TimingBand.miss, roll),
          anyOf(
            TimingConfig.missLifeDeltaMin,
            -4.0,
            TimingConfig.missLifeDeltaMax,
          ),
        );
      }
    });

    test('is pure: identical band + lifeRoll always returns identical output', () {
      expect(
        lifeDeltaFor(TimingBand.miss, 0.73),
        lifeDeltaFor(TimingBand.miss, 0.73),
      );
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
