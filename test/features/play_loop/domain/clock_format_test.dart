import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/clock_format.dart';

/// Architecture v2 §2/§Flag 2 (founder-resolved, re-resolved after the
/// `MM:SS`/0-5min range proved boring in practice and exposed a reroll
/// exploit) — `SS:CC` (seconds:hundredths), e.g. `3:47` == 3.47s. The
/// seconds digit is NOT zero-padded; only the centiseconds digit is (always
/// exactly 2 digits).
void main() {
  test('zero duration -> "0:00"', () {
    expect(formatClock(Duration.zero), '0:00');
  });

  test('sub-second value -> "0:25" for 250ms', () {
    expect(formatClock(const Duration(milliseconds: 250)), '0:25');
  });

  test('exactly 1 second -> "1:00"', () {
    expect(formatClock(const Duration(seconds: 1)), '1:00');
  });

  test('a single-digit centisecond value is still zero-padded to 2 digits '
      '-> "3:05" for 3.05s', () {
    expect(formatClock(const Duration(milliseconds: 3050)), '3:05');
  });

  test('the seconds digit itself is NOT zero-padded, only centiseconds are '
      '-> "2:00", not "02:00"', () {
    expect(formatClock(const Duration(seconds: 2)), '2:00');
  });

  test('the new target-range floor, 2.00s -> "2:00"', () {
    expect(formatClock(const Duration(milliseconds: 2000)), '2:00');
  });

  test('the new target-range ceiling, 6.00s -> "6:00"', () {
    expect(formatClock(const Duration(milliseconds: 6000)), '6:00');
  });

  test('multi-digit seconds format plainly, with no minute rollover -> '
      '"12:34" for 12.34s', () {
    expect(formatClock(const Duration(milliseconds: 12340)), '12:34');
  });

  test('durations well beyond a minute still format as plain seconds:'
      'centiseconds, never MM:SS -> "75:00" for 75s', () {
    expect(formatClock(const Duration(seconds: 75)), '75:00');
  });

  test('sub-centisecond precision is truncated, not rounded: 1999ms -> '
      '"1:99", not "2:00"', () {
    expect(formatClock(const Duration(milliseconds: 1999)), '1:99');
  });

  test('a Duration carrying microsecond precision from the scoring engine '
      'is truncated at the centisecond, not rounded: 3.047999s -> "3:04"', () {
    expect(
      formatClock(const Duration(seconds: 3, milliseconds: 47, microseconds: 999)),
      '3:04',
    );
  });
}
