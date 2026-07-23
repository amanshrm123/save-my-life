/// Band thresholds and life deltas for the timing engine.
///
/// *** PHASE 0 PLACEHOLDER VALUES ***
/// These ms thresholds and life-delta percentages are the discovery doc's
/// "playtest defaults, not final" (docs/discovery/TimingTap_Discovery_v1.md
/// §3a). They are wired in now so the engine is testable end-to-end, but
/// they are explicitly expected to be re-tuned on a real device during
/// Days 3-5 (Gate 1 feel prototype) — do not treat these numbers as locked.
class TimingConfig {
  const TimingConfig._();

  /// Perfect band: |delta| <= this many ms.
  static const int perfectMs = 30;

  /// On-point band: |delta| <= this many ms (and > [perfectMs]).
  /// Beyond this is a Miss.
  ///
  /// Widened from 80 to 200 (architecture v5 §1): the Play task is interval
  /// estimation with no external metronome to align to, so timing error is
  /// dominated by the player's own internal clock and scales with the
  /// target duration (Weber's law / scalar property). The old 80ms window
  /// was narrower than one standard deviation of error even at the easiest
  /// (3s) target, making genuine On-point taps too rare to visibly surface
  /// the {2.0, 3.0} roll variety in the Hit legend pill. 200ms is calibrated
  /// to make On-point common enough to vary during real play while keeping
  /// Perfect (30ms) elite and Miss a real threat at longer intervals.
  static const int onPointMs = 200;

  /// Life gained on a Perfect tap. Fixed, never rolled (architecture v3
  /// §4.1: Perfect is the guaranteed elite-tolerance reward ceiling — if it
  /// were also rolled, a low Perfect roll could land below a lucky On-point
  /// roll, inverting the tier ordering).
  static const double perfectLifeDelta = 3.0;

  /// On-point life-delta range (architecture v3 §4.1/§4.4): rolled per tap,
  /// uniformly, over the whole-integer set `{2.0, 3.0}` via
  /// `timing_engine.lifeDeltaFor`. Replaces the old fixed `onPointLifeDelta`.
  static const double onPointLifeDeltaMin = 2.0;
  static const double onPointLifeDeltaMax = 3.0;

  /// Miss life-delta range (architecture v3 §4.1/§4.4): rolled per tap,
  /// uniformly, over the whole-integer set `{-5.0, -4.0, -3.0}` via
  /// `timing_engine.lifeDeltaFor`. Replaces the old fixed `missLifeDelta`
  /// (`-4.0`), resolving that constant's own stale "picked as a fixed
  /// placeholder within the range" comment.
  static const double missLifeDeltaMin = -5.0;
  static const double missLifeDeltaMax = -3.0;

  /// Adaptive tightening coefficient `k` (Discovery §3a: `HIT_MS = BASE_HIT
  /// - (life% * k)`). Scaffolded per architecture's scope guard (§4:
  /// "Adaptive difficulty tightening" is explicitly OUT for v1 launch) —
  /// declared here for shape only. NOT read or applied by `timing_engine.dart`
  /// in this phase; fixed bands ship instead. Enabling this is a later,
  /// retention-data-driven tuning task.
  static const double adaptiveK = 0.0;

  static const double minLifePct = 0.0;
  static const double maxLifePct = 100.0;
}
