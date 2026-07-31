import 'run_config.dart';
import 'run_state.dart';

/// Pure, unit-testable scoring (architecture v6 §3, revising v2 §3's 3-tier
/// model to a single band). Classifies a stop against its target using
/// microsecond-precision `Duration` math end to end, reduced to integer
/// milliseconds only for the pass/fail comparison — no floating-point
/// seconds anywhere in the decision path, independent of the `M:SS.CC`
/// *display* format (see `clock_format.dart`).
StopTier classifyStop({
  required Duration target,
  required Duration stopped,
  required RunConfig config,
}) {
  final errorMs = (stopped - target).abs().inMilliseconds;
  return errorMs <= config.hitBandMs ? StopTier.hit : StopTier.miss;
}

/// Life delta for a given tier (architecture v6 §3/§4.1): Hit is neutral
/// (`config.hitDelta`, 0 — "safe" means exactly that, life never rises),
/// Miss costs `config.missDelta` (-10). Applied on *every* stop, including
/// the final band (architecture v6 §4.4) — a fatal final-band stop lands
/// life on exactly 0, and a non-miss final-band stop applies 0 and leaves
/// life unchanged.
///
/// Kept a named, unit-testable function rather than an inline ternary at
/// the call site: it keeps the life economy in one pure function, and
/// re-introducing any Hit gain later is a one-line config change rather
/// than a re-plumb.
int lifeDeltaForTier(StopTier tier, RunConfig config) {
  switch (tier) {
    case StopTier.hit:
      return config.hitDelta;
    case StopTier.miss:
      return config.missDelta;
  }
}
