/// All Play Loop tunables in one place (architecture v2 §7). Every value
/// here is a flagged default for playtest tuning unless the architecture doc
/// marks it founder-resolved (display format / target range / tier count are
/// resolved; the exact numbers below remain tunable).
class RunConfig {
  const RunConfig({
    this.startLifePercent = 50,
    this.perfectDelta = 3,
    this.hitDelta = 2,
    this.missDelta = -5,
    this.perfectBandMs = 60,
    this.hitBandMs = 180,
    this.finalBandThresholdPercent = 5,
    this.targetMinMs = 2000,
    this.targetMaxMs = 4900,
    this.eternalPerfectCount = 3,
    this.countdownSteps = 3,
    this.countdownStepMs = 700,
    this.flashDwellMs = 1100,
    this.autoMissGraceMs = 1000,
    this.minStopElapsedMs = 200,
  });

  final int startLifePercent;

  final int perfectDelta;
  final int hitDelta;
  final int missDelta;

  /// |error| <= this -> Perfect.
  final int perfectBandMs;

  /// perfectBandMs < |error| <= this -> Hit. Above this -> Miss.
  final int hitBandMs;

  /// Final band triggers for the *next* attempt once life is in
  /// `(0, finalBandThresholdPercent]`.
  final int finalBandThresholdPercent;

  /// Target range is `[targetMinMs, targetMaxMs]` inclusive, in
  /// milliseconds — `2.00s`-`4.90s` (founder-resolved, re-resolved after
  /// the `MM:SS`/0-5min range proved boring in practice; capped below
  /// `5.00s` so the `SS:CC` display never reads like it rolled into a
  /// 6th second).
  final int targetMinMs;
  final int targetMaxMs;

  /// First N attempts of a run all Perfect -> `RunOutcome.eternal`.
  final int eternalPerfectCount;

  final int countdownSteps;
  final int countdownStepMs;

  /// How long the "Stopped" flash/tier dwell holds before advancing.
  final int flashDwellMs;

  /// Grace period (design spec v2 §4), added past the point a Miss becomes
  /// numerically unavoidable (`target + hitBandMs`), before the run
  /// auto-resolves the attempt as a Miss on the player's behalf — a stalled
  /// finger/dropped tap can no longer strand an attempt forever.
  final int autoMissGraceMs;

  /// Merged-button double-tap guard: a stop resolves only once
  /// `_clock.elapsed` (the same capture [handlePrimaryPointerDown]/
  /// [registerStop] already read as their literal first statement, per
  /// architecture G2) is at least this many ms. Below it, the tap is treated
  /// as a no-op instead of a stop — never consuming `_stopConsumed`,
  /// mutating phase, or advancing `attemptIndex`.
  ///
  /// Guards against a fast double-tap landing on the merged button: tap once
  /// to start a run, then tap again almost immediately (finger already on
  /// the same widget, no longer needing to hunt for a separate STOP
  /// button) — with no guard this always resolves as a stop at ~0-20ms
  /// elapsed, which is always a `StopTier.miss` since `targetMinMs` is
  /// 2000ms (an instant death if it happens during `finalBandRunning`).
  /// Comfortably below `targetMinMs` (2000ms) so a legitimate stop, however
  /// fast, can never be suppressed by this guard.
  final int minStopElapsedMs;

  static const RunConfig defaults = RunConfig();
}
