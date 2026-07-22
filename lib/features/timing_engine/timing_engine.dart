import '../../core/timing_config.dart';

/// The three possible bands a tap can land in, per
/// docs/discovery/TimingTap_Discovery_v1.md §3a.
enum TimingBand { perfect, onPoint, miss }

/// Result of resolving a single tap against its target time.
///
/// Pure data — no Flutter dependency, safe to construct/compare in tests.
class TapResult {
  const TapResult({
    required this.band,
    required this.deltaMs,
    required this.lifeDelta,
  });

  /// Which band the tap landed in.
  final TimingBand band;

  /// Absolute distance between press and target, in whole milliseconds.
  final int deltaMs;

  /// Life percentage change this tap causes (not yet clamped/applied).
  final double lifeDelta;

  @override
  String toString() =>
      'TapResult(band: $band, deltaMs: $deltaMs, lifeDelta: $lifeDelta)';

  @override
  bool operator ==(Object other) =>
      other is TapResult &&
      other.band == band &&
      other.deltaMs == deltaMs &&
      other.lifeDelta == lifeDelta;

  @override
  int get hashCode => Object.hash(band, deltaMs, lifeDelta);
}

/// The timing engine: one pure function, no Flutter dependency, fully
/// unit-testable in isolation (architecture v1 §1.2, reaffirmed by v3 §4.2:
/// `resolve()` must stay pure/deterministic even with the new [lifeRoll]
/// parameter — same inputs, including the roll, always produce the same
/// output).
///
/// [targetMicros] and [pressMicros] must both be read from the same
/// [MonotonicClock] instance (core/clock.dart) — never `DateTime.now()`.
/// [lifePct] is accepted for the (currently disabled) adaptive-tightening
/// coefficient in [TimingConfig.adaptiveK]; with `adaptiveK == 0.0` it has
/// no effect on the result, matching architecture §4's scope guard that
/// ships fixed bands for v1. **[lifePct] is never read for the life-delta
/// magnitude** — that's [lifeRoll]'s job, and conflating the two would be
/// the banned adaptive-tightening mechanic (architecture v3 §4.5).
///
/// [lifeRoll] is a value in `[0, 1)` that the *caller* (`RunController`,
/// which already owns a `Random`) draws fresh per tap and passes in here —
/// see [lifeDeltaFor]. Keeping the random draw outside this function is
/// what keeps `resolve()` itself pure and headlessly testable with an
/// explicit roll.
TapResult resolve({
  required int targetMicros,
  required int pressMicros,
  required double lifePct,
  required double lifeRoll,
}) {
  final int deltaMicros = (pressMicros - targetMicros).abs();
  // Display-only rounding. Band decisions below compare deltaMicros
  // directly against thresholds in microseconds — never against this
  // rounded value — per architecture §1.2: band math "is never
  // quantized by our own code."
  final int deltaMs = (deltaMicros / 1000).round();

  // Adaptive tightening scaffold — disabled (k == 0.0) per architecture
  // §4 scope guard. When enabled in a later phase this shrinks the
  // on-point window as life climbs.
  final double effectiveOnPointMicros =
      (TimingConfig.onPointMs - (lifePct * TimingConfig.adaptiveK)) * 1000;

  final TimingBand band;
  if (deltaMicros <= TimingConfig.perfectMs * 1000) {
    band = TimingBand.perfect;
  } else if (deltaMicros <= effectiveOnPointMicros) {
    band = TimingBand.onPoint;
  } else {
    band = TimingBand.miss;
  }

  return TapResult(
    band: band,
    deltaMs: deltaMs,
    lifeDelta: lifeDeltaFor(band, lifeRoll),
  );
}

/// Pure helper mapping a resolved [band] + a `[0, 1)` [lifeRoll] to the
/// actual life-delta magnitude for this tap (architecture v3 §4.1/§4.2).
///
/// - **Perfect ignores [lifeRoll] entirely** and always returns the fixed
///   [TimingConfig.perfectLifeDelta] (the guaranteed elite-tolerance
///   reward ceiling — never rolled).
/// - **On-point** and **Miss** pick uniformly, in whole-integer steps, from
///   their band's `{min, ..., max}` set: On-point from `{2.0, 3.0}`, Miss
///   from `{-5.0, -4.0, -3.0}`. `lifeRoll == 0.0` maps to the set's lowest
///   (most negative, for Miss) value; `lifeRoll` approaching `1.0` maps to
///   the highest value — a uniform split of `[0, 1)` into as many buckets
///   as the set has members.
///
/// This is the ONLY place the roll touches the life-delta magnitude — the
/// band itself is decided purely by timing thresholds in [resolve], never
/// by this function or by [lifePct] (architecture v3 §4.5: rolling the
/// magnitude within a band is not the banned adaptive-tightening mechanic,
/// which instead narrows the timing *window* itself via
/// [TimingConfig.adaptiveK]).
double lifeDeltaFor(TimingBand band, double lifeRoll) {
  switch (band) {
    case TimingBand.perfect:
      return TimingConfig.perfectLifeDelta;
    case TimingBand.onPoint:
      return _pickFromRange(
        TimingConfig.onPointLifeDeltaMin,
        TimingConfig.onPointLifeDeltaMax,
        lifeRoll,
      );
    case TimingBand.miss:
      return _pickFromRange(
        TimingConfig.missLifeDeltaMin,
        TimingConfig.missLifeDeltaMax,
        lifeRoll,
      );
  }
}

/// Uniformly picks one whole-integer value from the closed range
/// `[min, max]` (inclusive on both ends, `max - min` assumed to be a small
/// whole number of integer steps) based on [lifeRoll] in `[0, 1)`.
double _pickFromRange(double min, double max, double lifeRoll) {
  final int steps = (max - min).round() + 1;
  final int index = (lifeRoll * steps).floor().clamp(0, steps - 1);
  return min + index;
}

/// Clamps a life percentage to the [TimingConfig.minLifePct,
/// TimingConfig.maxLifePct] range. Exposed here so `RunController` (and
/// tests) share one clamp implementation.
///
/// (Written without `num.clamp` to keep the return type a concrete
/// `double` rather than `num`.)
double clampLifePct(double lifePct) {
  if (lifePct < TimingConfig.minLifePct) return TimingConfig.minLifePct;
  if (lifePct > TimingConfig.maxLifePct) return TimingConfig.maxLifePct;
  return lifePct;
}
