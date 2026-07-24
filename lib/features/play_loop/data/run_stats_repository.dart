import '../../../core/persistence/preferences_service.dart';

/// Lifetime Run/Deaths totals via [PreferencesService] — founder-decided
/// (architecture v2 §6, revised): these are genuine cross-session lifetime
/// counts, not session-only. A run's completion (any outcome) increments the
/// runs-played total; a `death` outcome additionally increments the deaths
/// total. "Restart run" does not call [recordRunCompleted] — abandoning a
/// run's progress is not a completion.
class RunStatsRepository {
  const RunStatsRepository(this._prefs);

  final PreferencesService _prefs;

  int get totalRunsPlayed => _prefs.totalRunsPlayed;

  int get totalDeaths => _prefs.totalDeaths;

  /// Terminal action: a run just ended (death/survived/eternal). Defends
  /// against a write failure the same way the rest of this app's prefs
  /// writes do — never throws into the UI; worst case a lifetime counter
  /// silently fails to persist once (architecture v1 §8.7 precedent).
  Future<void> recordRunCompleted({required bool wasDeath}) async {
    try {
      await _prefs.setTotalRunsPlayed(totalRunsPlayed + 1);
      if (wasDeath) {
        await _prefs.setTotalDeaths(totalDeaths + 1);
      }
    } catch (_) {
      // Swallow — a failed lifetime-counter write is not fatal to gameplay.
    }
  }
}
