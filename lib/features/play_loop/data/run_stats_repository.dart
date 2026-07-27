import '../../../core/persistence/preferences_service.dart';
import '../../progression/domain/streak.dart';
import '../../progression/domain/streak_calculator.dart';
import '../domain/run_state.dart';
import '../domain/run_summary.dart';

/// Lifetime Run/Deaths/Survives/Eternal/best-life totals, plus the daily
/// streak, all via [PreferencesService] (architecture v3 §2, extending
/// architecture v2 §6 rather than duplicating it — this stays the single
/// run-completion writer). "Restart run" does not call [recordRunCompleted]
/// — abandoning a run's progress is not a completion.
class RunStatsRepository {
  const RunStatsRepository(this._prefs, {this.streakCalculator = const StreakCalculator()});

  final PreferencesService _prefs;
  final StreakCalculator streakCalculator;

  int get totalRunsPlayed => _prefs.totalRunsPlayed;

  int get totalDeaths => _prefs.totalDeaths;

  int get totalSurvives => _prefs.totalSurvives;

  int get totalEternal => _prefs.totalEternal;

  int get bestLifePercent => _prefs.bestLifePercent;

  DailyStreak get streak => DailyStreak(
    count: _prefs.streakCurrent,
    best: _prefs.streakBest,
    lastPlayDay: _prefs.streakLastPlayDay,
  );

  /// Terminal action: a run just ended (death/survived/eternal). Defends
  /// against a write failure the same way the rest of this app's prefs
  /// writes do — never throws into the UI; worst case a lifetime counter
  /// silently fails to persist once (architecture v1 §8.7 precedent).
  Future<void> recordRunCompleted(RunSummary summary) async {
    try {
      await _prefs.setTotalRunsPlayed(totalRunsPlayed + 1);
      switch (summary.outcome) {
        case RunOutcome.death:
          await _prefs.setTotalDeaths(totalDeaths + 1);
        case RunOutcome.survived:
          await _prefs.setTotalSurvives(totalSurvives + 1);
        case RunOutcome.eternal:
          await _prefs.setTotalEternal(totalEternal + 1);
      }
      if (summary.peakLifePercent > bestLifePercent) {
        await _prefs.setBestLifePercent(summary.peakLifePercent);
      }
    } catch (_) {
      // Swallow — a failed lifetime-counter write is not fatal to gameplay.
    }
  }

  /// A run completed *today* — advances the daily streak (architecture v3
  /// §2). Called once per completed run, never on mere app open. Idempotent
  /// for repeated same-day plays via `StreakCalculator.registerPlay`.
  Future<StreakResult> registerPlayDay(int today) async {
    final result = streakCalculator.registerPlay(streak, today);
    try {
      await _prefs.setStreakCurrent(result.streak.count);
      await _prefs.setStreakBest(result.streak.best);
      await _prefs.setStreakLastPlayDay(result.streak.lastPlayDay);
    } catch (_) {
      // Swallow — a failed streak write is not fatal to gameplay.
    }
    return result;
  }
}
