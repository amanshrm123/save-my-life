import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/timing_config.dart';
import '../persistence/hive_profile_repository.dart';
import '../persistence/profile_repository.dart';
import '../timing_engine/timing_engine.dart';

/// Run phase. `countdown` is the 3-2-1 shown before a round starts scoring;
/// `playing` is the live tap loop; `dead` is entered the instant life
/// reaches exactly 0% (architecture v3 §3.3) — the cycle-end state, shown as
/// a minimal placeholder ("You died" / "Play again") until the real
/// Days 6-11 outcome-card system replaces it.
enum RunPhase { countdown, playing, dead }

/// Immutable snapshot of run state. The Play screen reads this read-only;
/// only [RunController] mutates it.
class RunState {
  const RunState({
    required this.lifePct,
    required this.roundStartMicros,
    required this.targetDurationMicros,
    required this.phase,
    required this.deathCount,
    this.lastDeltaMs,
    this.lastBand,
    this.lastLifeDelta,
  });

  /// Current life percentage, always in [0, 100].
  final double lifePct;

  /// Elapsed-microseconds value (on the shared [MonotonicClock]) when the
  /// current round began.
  final int roundStartMicros;

  /// How many microseconds after [roundStartMicros] this round's target
  /// sits.
  final int targetDurationMicros;

  final RunPhase phase;

  /// Lifetime death count, seeded from [ProfileRepository.deathCount] in
  /// `build()` and incremented in-memory (immediately, without re-reading
  /// Hive) whenever life reaches 0% (architecture v3 §3.2/§3.3). Never
  /// reset by [startNewCycle] — it's a lifetime counter, not per-run.
  final int deathCount;

  /// Last tap's delta/band/life-delta, or null before the first tap of the
  /// run.
  final int? lastDeltaMs;
  final TimingBand? lastBand;

  /// The actual rolled life-delta magnitude applied by the most recent tap
  /// (architecture v3 §4.3) — the flash pill and flying pill must show
  /// this real value, never a `TimingConfig` constant (deltas are now
  /// ranged for On-point/Miss, so no single constant describes any given
  /// tap's outcome).
  final double? lastLifeDelta;

  RunState copyWith({
    double? lifePct,
    int? roundStartMicros,
    int? targetDurationMicros,
    RunPhase? phase,
    int? deathCount,
    int? lastDeltaMs,
    TimingBand? lastBand,
    double? lastLifeDelta,
  }) {
    return RunState(
      lifePct: lifePct ?? this.lifePct,
      roundStartMicros: roundStartMicros ?? this.roundStartMicros,
      targetDurationMicros: targetDurationMicros ?? this.targetDurationMicros,
      phase: phase ?? this.phase,
      deathCount: deathCount ?? this.deathCount,
      // Zone C intentionally holds the previous value until overwritten by
      // a new tap (play-screen-skeleton-v1.md §2, State 1) — never reset to
      // null here. (`startNewCycle()` clears these by building a fresh
      // `RunState` directly instead of going through `copyWith`.)
      lastDeltaMs: lastDeltaMs ?? this.lastDeltaMs,
      lastBand: lastBand ?? this.lastBand,
      lastLifeDelta: lastLifeDelta ?? this.lastLifeDelta,
    );
  }
}

/// *** PHASE 0 PLACEHOLDER *** — per-round target duration range, in
/// microseconds. Round pacing isn't specced beyond the discovery doc's
/// illustrative examples ("TARGET: 16.00s", "TARGET: 09.40s"); this range
/// is picked to land in that ballpark. Tune alongside the Days 3-5 feel
/// pass, same as the ms band values.
const int _minTargetDurationMicros = 3 * 1000000;
const int _maxTargetDurationMicros = 20 * 1000000;

/// Starting life percentage — 100% (architecture v3 §5 / founder item 2;
/// was 50% pre-v3).
const double _startingLifePct = 100.0;

/// The shared [MonotonicClock] instance used by both tap measurement
/// (`TapSurface`) and round timing (`RunController.registerTap`/
/// `beginPlaying`) — architecture v1 §1.2: one clock instance for the
/// whole run so every reader agrees on the same zero point. Started once,
/// on first read.
final clockProvider = Provider<MonotonicClock>((ref) {
  final clock = MonotonicClock()..start();
  ref.onDispose(clock.stop);
  return clock;
});

final runControllerProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);

/// Owns all run state for this phase: life%, the current round's target,
/// the last tap's result, and the lifetime death count. The only thing
/// that calls `timing_engine.resolve()` and mutates life. Death-ends-run
/// detection (architecture v3 §3) lives here: when a tap drives life to
/// exactly 0%, the run ends (`RunPhase.dead`) and the death is persisted
/// via `ProfileRepository`.
class RunController extends Notifier<RunState> {
  final Random _random = Random();

  @override
  RunState build() {
    final MonotonicClock clock = ref.watch(clockProvider);

    // Safe synchronous read (architecture v3 §3.4): `PlayScreen`/
    // `RunController` are only ever reached after `SplashScreen` has
    // already awaited `profileRepositoryProvider` — the same guarantee
    // `CountdownView.build()` already relies on for `name`. If a future
    // entry point could reach Play before the repo resolves, this must be
    // revisited (it can't today).
    final ProfileRepository repo =
        ref.read(profileRepositoryProvider).requireValue;

    return RunState(
      lifePct: _startingLifePct,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
      phase: RunPhase.countdown,
      deathCount: repo.deathCount,
    );
  }

  /// Called by `CountdownView` once the 3-2-1 has finished (Gate-1 spec
  /// §1, step 2). Moves the run into `RunPhase.playing` and re-rolls
  /// `roundStartMicros`/`targetDurationMicros` so the first scored round's
  /// timing starts clean at this instant, not from whenever `build()`
  /// happened to run (which could be seconds before the countdown ends).
  void beginPlaying() {
    final MonotonicClock clock = ref.read(clockProvider);
    state = state.copyWith(
      phase: RunPhase.playing,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
    );
  }

  int _rollTargetDurationMicros() {
    final int span = _maxTargetDurationMicros - _minTargetDurationMicros;
    return _minTargetDurationMicros + _random.nextInt(span);
  }

  /// Called with the timestamp captured in `TapSurface`'s `onPointerDown`.
  /// [pressMicros] must come from the same `MonotonicClock` instance
  /// exposed by [clockProvider].
  ///
  /// A no-op unless `state.phase == RunPhase.playing` (architecture v3
  /// §3.3) — a tap during `countdown` or after death must not score.
  void registerTap(int pressMicros) {
    if (state.phase != RunPhase.playing) return;

    final MonotonicClock clock = ref.read(clockProvider);
    final int targetMicros = state.roundStartMicros + state.targetDurationMicros;

    // `RunController` owns all nondeterminism (it already rolls target
    // durations) — the fresh `lifeRoll` is drawn here and passed into the
    // otherwise-pure `resolve()` (architecture v3 §4.2). This never reads
    // `lifePct` for the magnitude — that would be the banned adaptive-
    // tightening mechanic (§4.5).
    final TapResult result = resolve(
      targetMicros: targetMicros,
      pressMicros: pressMicros,
      lifePct: state.lifePct,
      lifeRoll: _random.nextDouble(),
    );

    final double newLifePct = clampLifePct(state.lifePct + result.lifeDelta);

    if (newLifePct <= TimingConfig.minLifePct) {
      // Death: the cycle ends here (architecture v3 §3.1/§3.3). The fatal
      // tap's band/delta still records — the death state's flash still
      // shows what actually happened — but no new target is rolled; the
      // run is over.
      final int newDeathCount = state.deathCount + 1;
      state = state.copyWith(
        lifePct: newLifePct,
        phase: RunPhase.dead,
        deathCount: newDeathCount,
        lastDeltaMs: result.deltaMs,
        lastBand: result.band,
        lastLifeDelta: result.lifeDelta,
      );

      // Fire-and-forget — never await in the tap path.
      unawaited(
        ref.read(profileRepositoryProvider).requireValue.incrementDeathCount(),
      );
      return;
    }

    state = state.copyWith(
      lifePct: newLifePct,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
      lastDeltaMs: result.deltaMs,
      lastBand: result.band,
      lastLifeDelta: result.lifeDelta,
    );
  }

  /// Restarts into a fresh cycle after death (architecture v3 §3.3):
  /// resets life to 100%, phase back to `countdown` (so the 3-2-1 replays
  /// via the same `beginPlaying()` path the real countdown already uses),
  /// rolls a fresh target, and clears the last-tap fields. `deathCount` is
  /// **not** reset — it's a lifetime counter.
  void startNewCycle() {
    final MonotonicClock clock = ref.read(clockProvider);
    state = RunState(
      lifePct: _startingLifePct,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
      phase: RunPhase.countdown,
      deathCount: state.deathCount,
    );
  }
}
