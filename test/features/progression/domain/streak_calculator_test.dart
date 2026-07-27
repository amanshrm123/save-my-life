import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/progression/domain/streak.dart';
import 'package:timing_tap/features/progression/domain/streak_calculator.dart';

/// Exhaustive coverage for `StreakCalculator` (architecture v3 §2/§11 risk
/// 5) — pure Dart, no Flutter, cheap and high-value: daily-boundary math,
/// same-day idempotency, broken-streak restart, and `isBrokenAtOpen`
/// including the never-played (-1) case.
void main() {
  const calculator = StreakCalculator();

  group('today()', () {
    test('two calls on the same calendar date (different times) return the '
        'same epoch-day value', () {
      final morning = DateTime(2026, 3, 10, 0, 30);
      final night = DateTime(2026, 3, 10, 23, 59);

      expect(calculator.today(now: morning), calculator.today(now: night));
    });

    test('consecutive calendar dates return consecutive epoch-day values', () {
      final day1 = calculator.today(now: DateTime(2026, 3, 10, 12));
      final day2 = calculator.today(now: DateTime(2026, 3, 11, 0, 1));

      expect(day2, day1 + 1);
    });

    test('epoch-day math is based on local y/m/d, not the wall-clock '
        'duration since epoch (a date far in the future still produces a '
        'plain, small integer day count consistent with calendar days)', () {
      final epoch = calculator.today(now: DateTime(1970, 1, 1, 12));
      expect(epoch, 0);
    });
  });

  group('registerPlay() — firstEver', () {
    test('a DailyStreak.initial (-1) first play sets count=1, best=1, '
        'lastPlayDay=today, transition=firstEver', () {
      final result = calculator.registerPlay(DailyStreak.initial, 100);

      expect(result.transition, StreakTransition.firstEver);
      expect(result.streak.count, 1);
      expect(result.streak.best, 1);
      expect(result.streak.lastPlayDay, 100);
    });

    test('firstEver preserves a pre-existing best that is already >= 1 '
        '(defensive: a corrupted/edited best should never be lowered)', () {
      const prev = DailyStreak(count: 0, best: 9, lastPlayDay: -1);

      final result = calculator.registerPlay(prev, 50);

      expect(result.transition, StreakTransition.firstEver);
      expect(result.streak.best, 9);
    });
  });

  group('registerPlay() — sameDay idempotency', () {
    test('a second play on the same epoch-day does not increment count '
        'and returns the previous streak object unchanged', () {
      const prev = DailyStreak(count: 4, best: 7, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 100);

      expect(result.transition, StreakTransition.sameDay);
      expect(result.streak.count, 4);
      expect(result.streak.best, 7);
      expect(result.streak.lastPlayDay, 100);
    });

    test('calling registerPlay repeatedly on the same day is fully '
        'idempotent (3 calls in a row = same result as 1 call)', () {
      const prev = DailyStreak(count: 1, best: 1, lastPlayDay: 100);

      var result = calculator.registerPlay(prev, 100);
      result = calculator.registerPlay(result.streak, 100);
      result = calculator.registerPlay(result.streak, 100);

      expect(result.streak.count, 1);
      expect(result.transition, StreakTransition.sameDay);
    });
  });

  group('registerPlay() — advanced (gap == 1)', () {
    test('playing on the very next calendar day increments count and '
        'transition is advanced', () {
      const prev = DailyStreak(count: 4, best: 4, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 101);

      expect(result.transition, StreakTransition.advanced);
      expect(result.streak.count, 5);
      expect(result.streak.lastPlayDay, 101);
    });

    test('best is bumped when the new count exceeds the previous best', () {
      const prev = DailyStreak(count: 4, best: 4, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 101);

      expect(result.streak.best, 5);
    });

    test('best is NOT bumped when a lower historical best is still >= the '
        'new (restarted, smaller) streak count', () {
      const prev = DailyStreak(count: 2, best: 10, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 101);

      expect(result.streak.count, 3);
      expect(result.streak.best, 10, reason: 'a smaller current streak must not clobber a higher best');
    });
  });

  group('registerPlay() — brokenRestarted (gap > 1, or negative)', () {
    test('a 2-day gap breaks the streak and restarts at count=1', () {
      const prev = DailyStreak(count: 6, best: 6, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 103);

      expect(result.transition, StreakTransition.brokenRestarted);
      expect(result.streak.count, 1);
      expect(result.streak.lastPlayDay, 103);
    });

    test('the previous best survives a broken streak unchanged', () {
      const prev = DailyStreak(count: 6, best: 6, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 103);

      expect(result.streak.best, 6);
    });

    test('a negative gap (clock rolled backward) is also treated as a '
        'broken restart, not a crash or an advance', () {
      const prev = DailyStreak(count: 5, best: 5, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 90);

      expect(result.transition, StreakTransition.brokenRestarted);
      expect(result.streak.count, 1);
      expect(result.streak.lastPlayDay, 90);
    });

    test('a broken restart from a zero/absent best still yields best=1, '
        'not 0', () {
      const prev = DailyStreak(count: 3, best: 0, lastPlayDay: 100);

      final result = calculator.registerPlay(prev, 200);

      expect(result.streak.best, 1);
    });
  });

  group('isBrokenAtOpen()', () {
    test('never-played (lastPlayDay == -1) is never "broken" — there is no '
        'streak yet to break', () {
      expect(calculator.isBrokenAtOpen(DailyStreak.initial, 500), isFalse);
    });

    test('already played today (lastPlayDay == today) is not broken', () {
      const streak = DailyStreak(count: 3, best: 3, lastPlayDay: 100);
      expect(calculator.isBrokenAtOpen(streak, 100), isFalse);
    });

    test('exactly a 1-day gap (played yesterday, not yet today) is NOT '
        'broken — the player still has today to keep it alive', () {
      const streak = DailyStreak(count: 3, best: 3, lastPlayDay: 100);
      expect(calculator.isBrokenAtOpen(streak, 101), isFalse);
    });

    test('a gap of more than 1 day is broken', () {
      const streak = DailyStreak(count: 3, best: 3, lastPlayDay: 100);
      expect(calculator.isBrokenAtOpen(streak, 102), isTrue);
      expect(calculator.isBrokenAtOpen(streak, 200), isTrue);
    });

    test('a negative "gap" (today somehow before lastPlayDay) is not '
        'reported as broken (only a genuine >1 forward gap counts)', () {
      const streak = DailyStreak(count: 3, best: 3, lastPlayDay: 100);
      expect(calculator.isBrokenAtOpen(streak, 90), isFalse);
    });
  });
}
