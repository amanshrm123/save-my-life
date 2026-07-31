import 'run_state.dart';

/// Everything the Outcome Card (architecture v3 §3) needs about the run that
/// just ended — closes the gap the raw `RunState`/`RunOutcome` pair left for
/// the old placeholder screen. Built once, by `RunController`, at the moment
/// a run transitions to `RunPhase.ended` (see `advanceAfterDwell`).
class RunSummary {
  const RunSummary({
    required this.outcome,
    required this.runNumber,
    required this.lifetimeDeaths,
    required this.peakLifePercent,
    required this.minLifePercent,
    required this.attemptCount,
    required this.playerName,
  });

  final RunOutcome outcome;

  /// This run's lifetime index (matches `RunState.runNumber`).
  final int runNumber;

  /// Lifetime deaths total *after* this run's outcome has been folded in —
  /// used for the death card's "Survived {lifetimeDeaths} deaths first."
  final int lifetimeDeaths;

  final int peakLifePercent;
  final int minLifePercent;

  /// Total attempts taken this run (architecture v6 §5.4) — used for the
  /// Eternal card's "Perfect start · {attemptCount}/{eternalHitCount}".
  final int attemptCount;

  /// '' == anonymous -> the no-name card variant (architecture v3 §3.4).
  final String playerName;

  bool get isAnonymous => playerName.isEmpty;

  @override
  String toString() =>
      'RunSummary(outcome: $outcome, runNumber: $runNumber, '
      'lifetimeDeaths: $lifetimeDeaths, peak: $peakLifePercent, '
      'min: $minLifePercent, attemptCount: $attemptCount, '
      'playerName: $playerName)';
}
