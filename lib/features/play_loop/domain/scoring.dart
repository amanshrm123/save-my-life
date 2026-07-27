import 'run_config.dart';
import 'run_state.dart';

/// Pure, unit-testable scoring (architecture v2 §3). Classifies a stop
/// against its target using microsecond-precision `Duration` math end to
/// end, reduced to integer milliseconds only for the final tier comparison
/// — no floating-point seconds anywhere in the decision path, independent
/// of the `SS:CC` *display* format (see `clock_format.dart`).
StopTier classifyStop({
  required Duration target,
  required Duration stopped,
  required RunConfig config,
}) {
  final errorMs = (stopped - target).abs().inMilliseconds;
  if (errorMs <= config.perfectBandMs) return StopTier.perfect;
  if (errorMs <= config.hitBandMs) return StopTier.hit;
  return StopTier.miss;
}

/// Life delta for a given tier (architecture v2 §3): Perfect +3%, Hit +2%,
/// Miss -5%. Not applied in the final band, which is sudden-death instead
/// (architecture v2 §4) — callers must not call this for a final-band
/// attempt.
int lifeDeltaForTier(StopTier tier, RunConfig config) {
  switch (tier) {
    case StopTier.perfect:
      return config.perfectDelta;
    case StopTier.hit:
      return config.hitDelta;
    case StopTier.miss:
      return config.missDelta;
  }
}
