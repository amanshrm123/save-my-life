import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../timing_engine/timing_engine.dart';

/// Run phase. `countdown` is the 3-2-1 shown before a round starts scoring;
/// `playing` is the live tap loop (docs/design/play-screen-gate1-v1.md §1).
/// There is still no outcome/end-of-run handling (that's Days 6-10's
/// `outcome_resolver.dart` per architecture v1 §2/§3) — `playing` simply
/// runs until the app is closed in this phase.
enum RunPhase { countdown, playing }

/// Immutable snapshot of run state. The Play screen reads this read-only;
/// only [RunController] mutates it.
class RunState {
  const RunState({
    required this.lifePct,
    required this.roundStartMicros,
    required this.targetDurationMicros,
    required this.phase,
    this.lastDeltaMs,
    this.lastBand,
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

  /// Last tap's delta/band, or null before the first tap of the run.
  final int? lastDeltaMs;
  final TimingBand? lastBand;

  RunState copyWith({
    double? lifePct,
    int? roundStartMicros,
    int? targetDurationMicros,
    RunPhase? phase,
    int? lastDeltaMs,
    TimingBand? lastBand,
  }) {
    return RunState(
      lifePct: lifePct ?? this.lifePct,
      roundStartMicros: roundStartMicros ?? this.roundStartMicros,
      targetDurationMicros: targetDurationMicros ?? this.targetDurationMicros,
      phase: phase ?? this.phase,
      // Zone C intentionally holds the previous value until overwritten by
      // a new tap (play-screen-skeleton-v1.md §2, State 1) — never reset to
      // null here.
      lastDeltaMs: lastDeltaMs ?? this.lastDeltaMs,
      lastBand: lastBand ?? this.lastBand,
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

const double _startingLifePct = 50.0;

/// The shared [MonotonicClock] instance used by both tap measurement
/// (`TapSurface`) and display (`IndicatorWidget`) — architecture v1 §1.2:
/// one clock instance for the whole run so display latency is a constant
/// offset, not drifting noise. Started once, on first read.
final clockProvider = Provider<MonotonicClock>((ref) {
  final clock = MonotonicClock()..start();
  ref.onDispose(clock.stop);
  return clock;
});

final runControllerProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);

/// Owns all run state for this phase: life%, the current round's target,
/// and the last tap's result. The only thing that calls
/// `timing_engine.resolve()` and mutates life. No outcome/end-of-run
/// handling in this phase.
class RunController extends Notifier<RunState> {
  final Random _random = Random();

  @override
  RunState build() {
    final MonotonicClock clock = ref.watch(clockProvider);
    return RunState(
      lifePct: _startingLifePct,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
      phase: RunPhase.countdown,
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
  void registerTap(int pressMicros) {
    final MonotonicClock clock = ref.read(clockProvider);
    final int targetMicros = state.roundStartMicros + state.targetDurationMicros;

    final TapResult result = resolve(
      targetMicros: targetMicros,
      pressMicros: pressMicros,
      lifePct: state.lifePct,
    );

    final double newLifePct = clampLifePct(state.lifePct + result.lifeDelta);

    state = state.copyWith(
      lifePct: newLifePct,
      roundStartMicros: clock.elapsedMicroseconds,
      targetDurationMicros: _rollTargetDurationMicros(),
      lastDeltaMs: result.deltaMs,
      lastBand: result.band,
    );
  }
}
