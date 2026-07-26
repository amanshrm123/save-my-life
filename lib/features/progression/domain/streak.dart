/// Persisted daily-streak state (architecture v3 §2). `lastPlayDay` is a
/// local-epoch-day index (days since epoch, local calendar date truncated,
/// see `StreakCalculator.today`) — `-1` means "never played."
class DailyStreak {
  const DailyStreak({
    required this.count,
    required this.best,
    required this.lastPlayDay,
  });

  final int count;
  final int best;
  final int lastPlayDay;

  static const DailyStreak initial = DailyStreak(count: 0, best: 0, lastPlayDay: -1);

  DailyStreak copyWith({int? count, int? best, int? lastPlayDay}) {
    return DailyStreak(
      count: count ?? this.count,
      best: best ?? this.best,
      lastPlayDay: lastPlayDay ?? this.lastPlayDay,
    );
  }

  @override
  String toString() => 'DailyStreak(count: $count, best: $best, lastPlayDay: $lastPlayDay)';
}

/// Which transition a `registerPlay` call resulted in (architecture v3 §2) —
/// `advanced` is what surfaces the 6.2 celebration on Home.
enum StreakTransition { firstEver, sameDay, advanced, brokenRestarted }

/// `registerPlay`'s result: the transition plus the streak state after it's
/// applied.
class StreakResult {
  const StreakResult({required this.transition, required this.streak});

  final StreakTransition transition;
  final DailyStreak streak;
}
