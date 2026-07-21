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
/// unit-testable in isolation (architecture v1 §1.2).
///
/// [targetMicros] and [pressMicros] must both be read from the same
/// [MonotonicClock] instance (core/clock.dart) — never `DateTime.now()`.
/// [lifePct] is accepted for the (currently disabled) adaptive-tightening
/// coefficient in [TimingConfig.adaptiveK]; with `adaptiveK == 0.0` it has
/// no effect on the result, matching architecture §4's scope guard that
/// ships fixed bands for v1.
TapResult resolve({
  required int targetMicros,
  required int pressMicros,
  required double lifePct,
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
  final double lifeDelta;
  if (deltaMicros <= TimingConfig.perfectMs * 1000) {
    band = TimingBand.perfect;
    lifeDelta = TimingConfig.perfectLifeDelta;
  } else if (deltaMicros <= effectiveOnPointMicros) {
    band = TimingBand.onPoint;
    lifeDelta = TimingConfig.onPointLifeDelta;
  } else {
    band = TimingBand.miss;
    lifeDelta = TimingConfig.missLifeDelta;
  }

  return TapResult(
    band: band,
    deltaMs: deltaMs,
    lifeDelta: lifeDelta,
  );
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
