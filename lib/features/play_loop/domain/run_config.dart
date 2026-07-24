/// All Play Loop tunables in one place (architecture v2 §7). Every value
/// here is a flagged default for playtest tuning unless the architecture doc
/// marks it founder-resolved (display format / target range / tier count are
/// resolved; the exact numbers below remain tunable).
class RunConfig {
  const RunConfig({
    this.startLifePercent = 100,
    this.perfectDelta = 3,
    this.hitDelta = 2,
    this.missDelta = -5,
    this.perfectBandMs = 60,
    this.hitBandMs = 180,
    this.finalBandThresholdPercent = 5,
    this.targetMinMs = 2000,
    this.targetMaxMs = 6000,
    this.eternalPerfectCount = 3,
    this.countdownSteps = 3,
    this.countdownStepMs = 700,
    this.flashDwellMs = 600,
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
  /// milliseconds — `2.00s`-`6.00s` (founder-resolved, re-resolved after
  /// the `MM:SS`/0-5min range proved boring in practice).
  final int targetMinMs;
  final int targetMaxMs;

  /// First N attempts of a run all Perfect -> `RunOutcome.eternal`.
  final int eternalPerfectCount;

  final int countdownSteps;
  final int countdownStepMs;

  /// How long the "Stopped" flash/tier dwell holds before advancing.
  final int flashDwellMs;

  static const RunConfig defaults = RunConfig();
}
