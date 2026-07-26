import 'streak.dart';

/// A RAM snapshot of everything Home/Stats read from `RunStatsRepository`
/// (architecture v3 §6) — read once into `statsProvider`, refreshed after a
/// run completes (`StatsController.registerRunCompletion`) and after a reset
/// (`ref.invalidate(statsProvider)`, architecture §11 risk 4).
class StatsSnapshot {
  const StatsSnapshot({
    required this.totalRunsPlayed,
    required this.totalDeaths,
    required this.totalSurvives,
    required this.totalEternal,
    required this.bestLifePercent,
    required this.streak,
    this.justAdvanced = false,
  });

  final int totalRunsPlayed;
  final int totalDeaths;
  final int totalSurvives;
  final int totalEternal;
  final int bestLifePercent;
  final DailyStreak streak;

  /// Transient: true for exactly one Home build after `registerPlay`
  /// returned `advanced` — cleared on display (architecture §6.2). Not
  /// persisted; lives only in this in-RAM snapshot.
  final bool justAdvanced;

  StatsSnapshot copyWith({
    int? totalRunsPlayed,
    int? totalDeaths,
    int? totalSurvives,
    int? totalEternal,
    int? bestLifePercent,
    DailyStreak? streak,
    bool? justAdvanced,
  }) {
    return StatsSnapshot(
      totalRunsPlayed: totalRunsPlayed ?? this.totalRunsPlayed,
      totalDeaths: totalDeaths ?? this.totalDeaths,
      totalSurvives: totalSurvives ?? this.totalSurvives,
      totalEternal: totalEternal ?? this.totalEternal,
      bestLifePercent: bestLifePercent ?? this.bestLifePercent,
      streak: streak ?? this.streak,
      justAdvanced: justAdvanced ?? this.justAdvanced,
    );
  }
}
