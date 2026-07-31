import 'run_config.dart';

/// Phases of one Play Loop run (architecture v2 §5).
enum RunPhase {
  countdown,
  armed,
  running,
  stopped,
  finalBandArmed,
  finalBandRunning,
  paused,
  ended,
}

/// The 2 scoring tiers (architecture v6 D1/§3): a single band on
/// `|stopped - target|` classifies a stop as safe (`hit`) or costly
/// (`miss`). `StopTier.perfect` is deleted, not retained-and-unused.
enum StopTier { hit, miss }

/// The 3 ways a run ends (architecture v2 §4).
enum RunOutcome { death, survived, eternal }

const Object _unset = Object();

/// Immutable in-RAM run state (architecture v2 §5). The `GameClock` is a
/// mutable resource owned by `RunController` and is deliberately **not**
/// part of this state.
class RunState {
  const RunState({
    required this.phase,
    required this.lifePercent,
    required this.target,
    required this.runNumber,
    required this.deaths,
    required this.attemptIndex,
    required this.hitStreakIntact,
    required this.peakLifePercent,
    required this.minLifePercent,
    this.lastTier,
    this.lastStopElapsed,
    this.lastStopWasFinalBand = false,
    this.outcome,
    this.phaseBeforePause,
  });

  final RunPhase phase;

  /// 0..100, clamped.
  final int lifePercent;

  /// Current attempt's target elapsed time.
  final Duration target;

  /// Lifetime counters (architecture v2 §6, revised per founder decision):
  /// seeded from `RunStatsRepository` when a fresh run starts, persisted via
  /// `shared_preferences` when a run completes (any outcome for `runNumber`,
  /// `death` outcome only for `deaths`). "Restart run" carries both over
  /// unchanged without persisting — abandoning a run isn't a completion.
  final int runNumber;
  final int deaths;

  /// 0-based count of normal (non-final-band) attempts taken this run, used
  /// to detect the Eternal ending (first N attempts, none a Miss —
  /// architecture v6 §5.2).
  final int attemptIndex;

  /// Whether every attempt so far this run has been a Hit (architecture v6
  /// §5.2). Kept as an explicit field, not derived from
  /// `lifePercent == startLifePercent` — that equivalence is an accident of
  /// the current no-heal life economy and would misfire silently if a life
  /// gain were ever reintroduced.
  final bool hitStreakIntact;

  /// Highest/lowest `lifePercent` ever observed this run (architecture v3
  /// §2) — tracked by `RunController.registerStop` so the outcome card can
  /// show "Peaked at N%" / "Down to N%" without re-deriving it from history.
  final int peakLifePercent;
  final int minLifePercent;

  /// Drives the post-stop flash. Only meaningful while [phase] is
  /// [RunPhase.stopped].
  final StopTier? lastTier;
  final Duration? lastStopElapsed;

  /// Whether the just-evaluated stop (rendered while [phase] is
  /// [RunPhase.stopped]) was a sudden-death final-band attempt, vs a normal
  /// incremental one. Not part of the architecture doc's literal field list
  /// (§5) — a small, deliberate addition needed to render the design doc's
  /// distinct "SURVIVED"/"MISS" (no % label) final-band-stopped visual
  /// (design v1 §2.7) instead of the normal tier flash. Flagged for review.
  final bool lastStopWasFinalBand;

  /// Set only when [phase] is [RunPhase.ended].
  final RunOutcome? outcome;

  /// The phase to restore to on resume; set only while [phase] is
  /// [RunPhase.paused].
  final RunPhase? phaseBeforePause;

  bool get isFinalBand =>
      phase == RunPhase.finalBandArmed || phase == RunPhase.finalBandRunning;

  static final RunState initial = RunState(
    phase: RunPhase.countdown,
    lifePercent: RunConfig.defaults.startLifePercent,
    target: Duration.zero,
    runNumber: 1,
    deaths: 0,
    attemptIndex: 0,
    hitStreakIntact: true,
    peakLifePercent: RunConfig.defaults.startLifePercent,
    minLifePercent: RunConfig.defaults.startLifePercent,
  );

  RunState copyWith({
    RunPhase? phase,
    int? lifePercent,
    Duration? target,
    int? runNumber,
    int? deaths,
    int? attemptIndex,
    bool? hitStreakIntact,
    int? peakLifePercent,
    int? minLifePercent,
    bool? lastStopWasFinalBand,
    Object? lastTier = _unset,
    Object? lastStopElapsed = _unset,
    Object? outcome = _unset,
    Object? phaseBeforePause = _unset,
  }) {
    return RunState(
      phase: phase ?? this.phase,
      lifePercent: lifePercent ?? this.lifePercent,
      target: target ?? this.target,
      runNumber: runNumber ?? this.runNumber,
      deaths: deaths ?? this.deaths,
      attemptIndex: attemptIndex ?? this.attemptIndex,
      hitStreakIntact: hitStreakIntact ?? this.hitStreakIntact,
      peakLifePercent: peakLifePercent ?? this.peakLifePercent,
      minLifePercent: minLifePercent ?? this.minLifePercent,
      lastStopWasFinalBand:
          lastStopWasFinalBand ?? this.lastStopWasFinalBand,
      lastTier: identical(lastTier, _unset)
          ? this.lastTier
          : lastTier as StopTier?,
      lastStopElapsed: identical(lastStopElapsed, _unset)
          ? this.lastStopElapsed
          : lastStopElapsed as Duration?,
      outcome: identical(outcome, _unset)
          ? this.outcome
          : outcome as RunOutcome?,
      phaseBeforePause: identical(phaseBeforePause, _unset)
          ? this.phaseBeforePause
          : phaseBeforePause as RunPhase?,
    );
  }

  @override
  String toString() =>
      'RunState(phase: $phase, life: $lifePercent, target: $target, '
      'run: $runNumber, deaths: $deaths, attempt: $attemptIndex, '
      'lastTier: $lastTier, outcome: $outcome, peak: $peakLifePercent, '
      'min: $minLifePercent)';
}
