import 'streak.dart';

/// Pure, no-Flutter daily-streak math (architecture v3 §2/§11 risk 5). All
/// date math happens on **local** calendar epoch-days — never UTC, never
/// wall-clock durations — so a streak's "day" always matches what the
/// player's clock shows them, at the cost of the usual DST/clock-change
/// coarseness (flagged, accepted).
class StreakCalculator {
  const StreakCalculator();

  /// Local calendar epoch-day: truncates `now` to y/m/d in local time, then
  /// counts days since the Unix epoch. Two calls on the same calendar date
  /// always return the same value regardless of time-of-day.
  int today({DateTime? now}) {
    final n = now ?? DateTime.now();
    final localMidnight = DateTime(n.year, n.month, n.day);
    return localMidnight.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// Applies "a run completed today" to `prev`, returning the transition and
  /// the updated streak. Idempotent for repeated same-day plays (architecture
  /// §11 risk 5) — playing twice in one day does not double-increment.
  StreakResult registerPlay(DailyStreak prev, int today) {
    if (prev.lastPlayDay == -1) {
      final streak = DailyStreak(count: 1, best: prev.best < 1 ? 1 : prev.best, lastPlayDay: today);
      return StreakResult(transition: StreakTransition.firstEver, streak: streak);
    }

    final gap = today - prev.lastPlayDay;
    if (gap == 0) {
      return StreakResult(transition: StreakTransition.sameDay, streak: prev);
    }

    if (gap == 1) {
      final newCount = prev.count + 1;
      final streak = DailyStreak(
        count: newCount,
        best: newCount > prev.best ? newCount : prev.best,
        lastPlayDay: today,
      );
      return StreakResult(transition: StreakTransition.advanced, streak: streak);
    }

    // gap > 1 (or negative, e.g. a clock change) -> streak broken, restart at 1.
    final streak = DailyStreak(
      count: 1,
      best: prev.best < 1 ? 1 : prev.best,
      lastPlayDay: today,
    );
    return StreakResult(transition: StreakTransition.brokenRestarted, streak: streak);
  }

  /// True when the player hasn't played today AND more than one calendar day
  /// has elapsed since their last play — used by Home to show 6.3 before
  /// they've played today (architecture §2/§6).
  bool isBrokenAtOpen(DailyStreak streak, int today) {
    if (streak.lastPlayDay == -1) return false;
    if (streak.lastPlayDay == today) return false;
    return today - streak.lastPlayDay > 1;
  }
}
