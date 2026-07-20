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
  static const int onPointMs = 80;

  /// Life gained on a Perfect tap.
  static const double perfectLifeDelta = 3.0;

  /// Life gained on an On-point tap.
  static const double onPointLifeDelta = 2.0;

  /// Life lost on a Miss. Discovery §3a specifies a range of -3% to -5%;
  /// -4% is picked here as a fixed placeholder within that range and is
  /// tunable during Days 3-5 playtesting.
  static const double missLifeDelta = -4.0;

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
