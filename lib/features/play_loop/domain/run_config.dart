/// All Play Loop tunables in one place (architecture v2 §7, revised by
/// architecture v6 §8.1 for the binary hit/miss scoring model). Every value
/// here is a flagged default for playtest tuning unless the architecture doc
/// marks it founder-resolved (display format / target range / tier count are
/// resolved; the exact numbers below remain tunable).
class RunConfig {
  const RunConfig({
    this.startLifePercent = 50,
    this.hitDelta = 0,
    this.missDelta = -10,
    this.hitBandMs = 180,
    this.finalBandThresholdPercent = 10,
    this.targetMinMs = 2000,
    this.targetMaxMs = 4900,
    this.eternalHitCount = 12,
    this.countdownSteps = 3,
    this.countdownStepMs = 700,
    this.flashDwellMs = 600,
    this.autoMissGraceMs = 1000,
    this.minStopElapsedMs = 200,
  }) : assert(
         finalBandThresholdPercent == -missDelta,
         'finalBandThresholdPercent must equal -missDelta or the final band '
         '(and RunOutcome.survived) becomes numerically unreachable.',
       ),
       assert(
         eternalHitCount >= 1,
         'eternalHitCount must be >= 1 or RunOutcome.eternal is unreachable.',
       );

  /// Attrition budget, not growth headroom (architecture v6 §4.2): with life
  /// never increasing, this number's only job is `misses_to_death =
  /// startLifePercent / -missDelta` (= 5 at defaults).
  final int startLifePercent;

  /// Hit is neutral (architecture v6 D3/§4.1): a good stop is "safe", not a
  /// gain. Kept as a real config field (rather than hardcoded 0 at the call
  /// site) so "Hit is safe" is a tuned value, not an assumption spread across
  /// the scoring path and the flash/legend widgets.
  final int hitDelta;
  final int missDelta;

  /// The sole pass/fail threshold on `|stopped - target|` (architecture v6
  /// D2): `errorMs <= hitBandMs` -> Hit, else Miss. This is the old *outer*
  /// forgiveness edge, kept deliberately generous now that a good stop no
  /// longer earns anything — skill only buys not-losing. Primary post-
  /// playtest difficulty dial; expected direction of travel is wider, not
  /// narrower.
  final int hitBandMs;

  /// Final band triggers for the *next* attempt once life is in
  /// `(0, finalBandThresholdPercent]`. Invariant (architecture v6 §4.3):
  /// `finalBandThresholdPercent == -missDelta` — without this the final band
  /// (and therefore `RunOutcome.survived`) becomes numerically unreachable.
  final int finalBandThresholdPercent;

  /// Target range is `[targetMinMs, targetMaxMs]` inclusive, in
  /// milliseconds — `2.00s`-`4.90s` (founder-resolved, re-resolved after
  /// the `MM:SS`/0-5min range proved boring in practice). The former
  /// `targetMaxMs` doc rationale ("capped below 5.00s so the display never
  /// reads like it rolled into a 6th second") applied only to the retired
  /// `SS:CC` format and is void under `M:SS.CC` (architecture v6 §8.2),
  /// where `0:05.40` would already be unambiguous. The value is kept
  /// unchanged regardless — it isn't part of the ask, it was
  /// founder-resolved, and 2.00-4.90s is a well-paced window.
  final int targetMinMs;
  final int targetMaxMs;

  /// First N attempts of a run all Hit (no Miss) -> `RunOutcome.eternal`
  /// (architecture v6 D9/§5: redefined around the hit streak now that there
  /// is no Perfect tier to key off).
  final int eternalHitCount;

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
