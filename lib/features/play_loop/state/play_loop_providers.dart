import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider, playerProfileProvider;
import '../../progression/state/stats_providers.dart';
import '../data/run_stats_repository.dart';
import '../domain/game_clock.dart';
import '../domain/run_config.dart';
import '../domain/run_state.dart';
import '../domain/run_summary.dart';
import '../domain/scoring.dart';

/// Lifetime Run/Deaths totals live in prefs, not session state (architecture
/// v2 §6, revised per founder decision) — reused across every fresh
/// `RunController` instance the same way `playerProfileRepositoryProvider`
/// is reused across onboarding.
final Provider<RunStatsRepository> runStatsRepositoryProvider =
    Provider<RunStatsRepository>((ref) {
      return RunStatsRepository(ref.watch(preferencesServiceProvider));
    });

/// What to do once the post-stop flash dwell (`RunConfig.flashDwellMs`)
/// elapses. Computed synchronously at evaluate-time inside [registerStop]
/// (architecture v2 §5's "stopped -> evaluate" arrow); only the *timing* of
/// applying it is a screen-owned dwell timer (§5, last line), not the
/// decision itself — that decision is domain logic and stays in here.
enum _PendingAdvance { rearm, finalBandArm, endDeath, endEternal, endSurvived }

/// Owns the single [GameClock] for a run and exposes the intent methods
/// named by architecture v2 §1/§5: `startCountdown`, `arm`, `startRunning`,
/// `registerStop`, `pause`, `resume`, `restartRun`, `enterFinalBand`.
///
/// Synchronous `Notifier` (not Async) — the *run* itself is pure in-RAM game
/// state (architecture v2 §1). The lifetime Run/Deaths totals it seeds from
/// are a synchronous read off the already-resolved `PreferencesService`
/// (same pattern as `PlayerProfileRepository`), so this doesn't need to
/// become an `AsyncNotifier`.
class RunController extends Notifier<RunState> {
  final GameClock _clock = GameClock();
  final Random _random = Random();

  RunConfig get config => RunConfig.defaults;

  _PendingAdvance? _pending;

  /// Belt-and-braces latch against a second `registerStop()` firing before
  /// the phase guard has propagated (architecture v2 §9 risk 3). Reset only
  /// on re-arm (`arm()`/`startRunning()`/`enterFinalBand()`).
  bool _stopConsumed = false;

  /// Auto-miss timeout (design spec v2 §4, new `RunConfig.autoMissGraceMs`):
  /// scheduled the instant an attempt goes live (`startRunning()`), fires a
  /// genuine `registerStop()` once the attempt becomes numerically
  /// unavoidable-Miss-plus-grace-period, so a stalled/never-arriving tap
  /// can't strand an attempt (or the run) forever. Memory-safety-critical:
  /// every place that ends/interrupts a live attempt must cancel this timer
  /// (`_cancelAutoMiss()`) so a stale instance can never fire against
  /// disposed/wrong state — see the cancel-call-sites cross-referenced in
  /// this class's doc comments below.
  Timer? _autoMissTimer;

  @override
  RunState build() {
    ref.onDispose(() {
      // architecture v2 §9 risk 9/10: tear the clock down with the
      // controller so a stale run/Stopwatch can never survive a
      // Home<->Play cycle (this provider is `.autoDispose`).
      _clock.stop();
      _clock.reset();
      _cancelAutoMiss();
    });
    return _freshRunState();
  }

  /// Schedules a fresh auto-miss `Timer` for the attempt that just went live,
  /// firing a genuine `registerStop()` (design spec v2 §4) — never a
  /// synthesized elapsed value; the real `_clock.elapsed` is read at fire
  /// time, exactly as a manual tap would. Cancels any existing timer first
  /// (defensive against a double-call).
  void _scheduleAutoMiss() {
    _cancelAutoMiss();
    _autoMissTimer = Timer(
      Duration(
        milliseconds:
            state.target.inMilliseconds + config.hitBandMs + config.autoMissGraceMs,
      ),
      registerStop,
    );
  }

  /// Idempotent: cancels and nulls the auto-miss timer if one is pending.
  /// Called from every point a live attempt can end or be pre-empted
  /// (manual stop, pause, restart, re-arm, dispose) so a stale timer can
  /// never fire against state it no longer applies to.
  void _cancelAutoMiss() {
    _autoMissTimer?.cancel();
    _autoMissTimer = null;
  }

  /// Read-only live elapsed time for the screen's display `Ticker` — the
  /// only thing exposed from the clock outside this controller (architecture
  /// v2 §9 risk 10: single ownership, no widget ever touches `GameClock`
  /// itself).
  Duration get liveElapsed => _clock.elapsed;

  /// Random target at centisecond granularity within `[targetMinMs,
  /// targetMaxMs]` — matches the `SS:CC` display precision (architecture v2
  /// §2/§7, re-resolved) so the "STOP AT" plate always shows a clean value.
  Duration _randomTarget() {
    const centisecondMs = 10;
    final minCenti = config.targetMinMs ~/ centisecondMs;
    final maxCenti = config.targetMaxMs ~/ centisecondMs;
    final centi = minCenti + _random.nextInt(maxCenti - minCenti + 1);
    return Duration(milliseconds: centi * centisecondMs);
  }

  /// Seeds `runNumber`/`deaths` from the lifetime totals persisted so far
  /// (architecture v2 §6, revised): this fresh run is the *next* one, so
  /// `runNumber` is the persisted count plus one; `deaths` is the persisted
  /// total as-is (this run hasn't ended yet).
  RunState _freshRunState() {
    final repo = ref.read(runStatsRepositoryProvider);
    return RunState.initial.copyWith(
      target: _randomTarget(),
      runNumber: repo.totalRunsPlayed + 1,
      deaths: repo.totalDeaths,
    );
  }

  /// countdown -> armed (countdown timer complete), and re-arm: stopped ->
  /// armed with a fresh target (the "continue" branch of stopped -> evaluate).
  void arm() {
    _cancelAutoMiss();
    if (state.phase == RunPhase.countdown) {
      _stopConsumed = false;
      state = state.copyWith(phase: RunPhase.armed);
    } else if (state.phase == RunPhase.stopped) {
      _stopConsumed = false;
      state = state.copyWith(phase: RunPhase.armed, target: _randomTarget());
    }
  }

  /// stopped -> finalBandArmed (the other non-terminal branch of stopped ->
  /// evaluate, when life has dropped into the final band).
  void enterFinalBand() {
    _cancelAutoMiss();
    if (state.phase != RunPhase.stopped) return;
    _stopConsumed = false;
    state = state.copyWith(
      phase: RunPhase.finalBandArmed,
      target: _randomTarget(),
    );
  }

  /// armed -> running, or finalBandArmed -> finalBandRunning (the center
  /// "STOP AT" plate tap). Guarded against double-tap per architecture v2
  /// §9 risk 4.
  void startRunning() {
    // Defensive cancel-before-schedule (in case of a double-call) — the
    // real schedule happens again, correctly, in whichever branch below
    // actually transitions the phase.
    _cancelAutoMiss();
    if (state.phase == RunPhase.armed) {
      _stopConsumed = false;
      _clock.reset();
      _clock.start();
      state = state.copyWith(phase: RunPhase.running);
      _scheduleAutoMiss();
    } else if (state.phase == RunPhase.finalBandArmed) {
      _stopConsumed = false;
      _clock.reset();
      _clock.start();
      state = state.copyWith(phase: RunPhase.finalBandRunning);
      _scheduleAutoMiss();
    }
  }

  /// The merged bottom button's single entry point (design spec v2 §3;
  /// architecture G2, preserved through the two-button merge). The
  /// **literal first statement** reads `_clock.elapsed` — before any guard,
  /// branch, provider read, or state mutation — so merging the old
  /// `TargetArmButton`/`StopButton` taps into one widget can never introduce
  /// gesture-arena/build latency into the STOP-tap-to-clock-read chain.
  /// Only after that capture does it switch on `state.phase`: a live phase
  /// resolves as a stop (delegating to [_resolveStop], the exact same path
  /// a manual/auto-miss stop uses); an armed phase starts the run; anything
  /// else is a no-op.
  void handlePrimaryPointerDown() {
    final captured = _clock.elapsed;

    switch (state.phase) {
      case RunPhase.running:
      case RunPhase.finalBandRunning:
        _resolveStop(captured);
      case RunPhase.armed:
      case RunPhase.finalBandArmed:
        startRunning();
      case RunPhase.countdown:
      case RunPhase.stopped:
      case RunPhase.paused:
      case RunPhase.ended:
        break; // no-op — nothing to start or stop from these phases.
    }
  }

  /// The load-bearing capture path (architecture v2 G2). The **literal
  /// first line** reads `_clock.elapsed` — a direct synchronous read, one
  /// call hop from the raw `Listener.onPointerDown` — before any guard,
  /// branch, or state mutation, so gesture-arena/build latency can never
  /// pollute the measured instant. Delegates everything after the capture
  /// to [_resolveStop] — kept as a thin public entry point since
  /// `run_controller_test.dart` calls it directly, and since the auto-miss
  /// timer (`_scheduleAutoMiss`) also fires this exact method.
  void registerStop() {
    final stopped = _clock.elapsed;
    _resolveStop(stopped);
  }

  /// Everything that happens once a stop-time has already been captured
  /// (by either [registerStop] or [handlePrimaryPointerDown]) — guards,
  /// classification, and the resulting state transition. Not itself
  /// latency-sensitive: by the time this runs, the clock read is already
  /// done.
  void _resolveStop(Duration stopped) {
    if (_stopConsumed) return;
    if (state.phase != RunPhase.running &&
        state.phase != RunPhase.finalBandRunning) {
      return;
    }
    // Fast-double-tap guard (`RunConfig.minStopElapsedMs`): the merged
    // button means a second tap can land on the very same widget
    // near-instantly after the start tap, with no widget-hunt in between.
    // Below this threshold the tap is fully inert — not consumed, no phase
    // change, no attempt advanced — as if it never happened. Comfortably
    // below `targetMinMs` (2000ms), so a genuine stop is never suppressed.
    if (stopped.inMilliseconds < config.minStopElapsedMs) return;
    _stopConsumed = true;
    _clock.stop();
    // A genuine, accepted stop pre-empts whatever auto-miss was pending for
    // this same attempt (manual stop or the auto-miss timer's own fire both
    // land here).
    _cancelAutoMiss();

    final tier = classifyStop(target: state.target, stopped: stopped, config: config);

    if (state.phase == RunPhase.finalBandRunning) {
      // Sudden death: no incremental life delta, terminal either way.
      final survived = survivesFinalBand(tier);
      _pending = survived ? _PendingAdvance.endSurvived : _PendingAdvance.endDeath;
      state = state.copyWith(
        phase: RunPhase.stopped,
        lastTier: tier,
        lastStopElapsed: stopped,
        lastStopWasFinalBand: true,
        attemptIndex: state.attemptIndex + 1,
      );
      return;
    }

    // Normal (non-final-band) attempt.
    final delta = lifeDeltaForTier(tier, config);
    final newLife = (state.lifePercent + delta).clamp(0, 100);
    final newPeak = newLife > state.peakLifePercent ? newLife : state.peakLifePercent;
    final newMin = newLife < state.minLifePercent ? newLife : state.minLifePercent;
    final newAttemptIndex = state.attemptIndex + 1;
    final streakIntact = state.perfectStreakIntact && tier == StopTier.perfect;
    final eternalReached =
        streakIntact && newAttemptIndex >= config.eternalPerfectCount;

    if (newLife <= 0) {
      _pending = _PendingAdvance.endDeath;
    } else if (eternalReached) {
      _pending = _PendingAdvance.endEternal;
    } else if (newLife <= config.finalBandThresholdPercent) {
      _pending = _PendingAdvance.finalBandArm;
    } else {
      _pending = _PendingAdvance.rearm;
    }

    state = state.copyWith(
      phase: RunPhase.stopped,
      lifePercent: newLife,
      peakLifePercent: newPeak,
      minLifePercent: newMin,
      lastTier: tier,
      lastStopElapsed: stopped,
      lastStopWasFinalBand: false,
      attemptIndex: newAttemptIndex,
      perfectStreakIntact: streakIntact,
    );
  }

  /// Applies whichever transition [registerStop] resolved, once the
  /// screen's flash-dwell timer (`mounted`-guarded, architecture v2 §5 last
  /// line) has elapsed. The decision was already made synchronously above;
  /// this method only performs it.
  void advanceAfterDwell() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    switch (pending) {
      case _PendingAdvance.rearm:
        arm();
      case _PendingAdvance.finalBandArm:
        enterFinalBand();
      case _PendingAdvance.endDeath:
        state = state.copyWith(
          phase: RunPhase.ended,
          outcome: RunOutcome.death,
          deaths: state.deaths + 1,
        );
        _persistRunCompleted();
      case _PendingAdvance.endEternal:
        state = state.copyWith(phase: RunPhase.ended, outcome: RunOutcome.eternal);
        _persistRunCompleted();
      case _PendingAdvance.endSurvived:
        state = state.copyWith(phase: RunPhase.ended, outcome: RunOutcome.survived);
        _persistRunCompleted();
    }
  }

  /// Fire-and-forget: the lifetime totals + daily streak are a durability
  /// backup, not something navigation gates on (architecture v2 §6,
  /// revised; v3 §2). `RunStatsRepository`/`StatsController` swallow their
  /// own write failures.
  void _persistRunCompleted() {
    unawaited(
      ref.read(statsProvider.notifier).registerRunCompletion(buildSummary()),
    );
  }

  /// Builds the `RunSummary` the outcome screen needs (architecture v3 §2/§3)
  /// — called by the screen at the moment `phase == ended` is observed, from
  /// the freshly-ended `state`.
  RunSummary buildSummary() {
    final profile = ref.read(playerProfileProvider).value;
    final name = (profile == null || profile.isAnonymous) ? '' : profile.name;
    return RunSummary(
      outcome: state.outcome ?? RunOutcome.death,
      runNumber: state.runNumber,
      lifetimeDeaths: state.deaths,
      peakLifePercent: state.peakLifePercent,
      minLifePercent: state.minLifePercent,
      perfectCount: state.attemptIndex,
      playerName: name,
    );
  }

  /// Any live phase -> paused. Manual pause is treated exactly like the
  /// backgrounding auto-pause (architecture v2 §9 risk 1/8): an in-flight
  /// RUNNING attempt is discarded (clock stopped, no score taken) rather
  /// than resumed mid-flight, closing the "pause just before the target,
  /// resume, tap" exploit.
  void pause() {
    RunPhase restorePhase;
    switch (state.phase) {
      case RunPhase.armed:
        restorePhase = RunPhase.armed;
      case RunPhase.finalBandArmed:
        restorePhase = RunPhase.finalBandArmed;
      case RunPhase.running:
        _clock.stop();
        _cancelAutoMiss();
        restorePhase = RunPhase.armed;
      case RunPhase.finalBandRunning:
        _clock.stop();
        _cancelAutoMiss();
        restorePhase = RunPhase.finalBandArmed;
      default:
        return; // not a pausable phase (countdown/stopped/paused/ended).
    }
    _stopConsumed = false;
    state = state.copyWith(phase: RunPhase.paused, phaseBeforePause: restorePhase);
  }

  void resume() {
    if (state.phase != RunPhase.paused) return;
    final restorePhase = state.phaseBeforePause ?? RunPhase.armed;
    state = state.copyWith(phase: restorePhase, phaseBeforePause: null);
  }

  /// Full reset: life -> `RunConfig.startLifePercent`, fresh target, this
  /// run's progress abandoned.
  /// Per architecture v2 §10 flag 7, restart does **not** increment the Run
  /// counter — and by the same logic must not reset the session's Deaths
  /// count either, since that's not part of "this run's progress" — only
  /// `runNumber` and `deaths` are carried over unchanged.
  void restartRun() {
    _pending = null;
    _stopConsumed = false;
    _clock.stop();
    _clock.reset();
    _cancelAutoMiss();
    state = RunState.initial.copyWith(
      phase: RunPhase.armed,
      target: _randomTarget(),
      runNumber: state.runNumber,
      deaths: state.deaths,
    );
  }
}

final NotifierProvider<RunController, RunState> runControllerProvider =
    NotifierProvider.autoDispose<RunController, RunState>(RunController.new);
