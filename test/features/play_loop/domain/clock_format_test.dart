import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/clock_format.dart';

/// Architecture v6 D10/§2.2 — `M:SS.CC` (e.g. `0:04.70` = 4.70s), replacing
/// the retired `SS:CC` format (architecture v2 §2/§Flag 2), whose readout
/// (`4:70`) was not a valid clock reading in any format. Minutes is NOT
/// zero-padded (carrying forward the existing convention that the leading
/// field is never padded); seconds and hundredths are always zero-padded to
/// 2 digits each. Real time and the existing short target range
/// (`2.00s`-`4.90s`) are unchanged — only the readout gained a real minutes
/// field and a decimal separator.
void main() {
  group('formatClock — the full architecture v6 §2.2 vector table', () {
    test('Duration.zero -> "0:00.00"', () {
      expect(formatClock(Duration.zero), '0:00.00');
    });

    test('200ms -> "0:00.20"', () {
      expect(formatClock(const Duration(milliseconds: 200)), '0:00.20');
    });

    test('2000ms -> "0:02.00"', () {
      expect(formatClock(const Duration(milliseconds: 2000)), '0:02.00');
    });

    test('4700ms -> "0:04.70"', () {
      expect(formatClock(const Duration(milliseconds: 4700)), '0:04.70');
    });

    test('4900ms -> "0:04.90"', () {
      expect(formatClock(const Duration(milliseconds: 4900)), '0:04.90');
    });

    test('59_990ms -> "0:59.99"', () {
      expect(formatClock(const Duration(milliseconds: 59990)), '0:59.99');
    });

    test('65_430ms -> "1:05.43" (the minute rollover pair)', () {
      expect(formatClock(const Duration(milliseconds: 65430)), '1:05.43');
    });

    test('3_600_000ms -> "60:00.00" (minutes is not zero-padded/capped)', () {
      expect(formatClock(const Duration(milliseconds: 3600000)), '60:00.00');
    });
  });

  group('formatClock — supplementary boundary checks', () {
    test('seconds and hundredths are always zero-padded to 2 digits, even '
        'for single-digit values', () {
      expect(formatClock(const Duration(milliseconds: 3050)), '0:03.05');
    });

    test('minutes is never zero-padded (the leading field convention)', () {
      expect(formatClock(const Duration(seconds: 65)), '1:05.00');
    });

    test('centisecond truncation, not rounding: 1999ms -> "0:01.99", not '
        '"0:02.00"', () {
      expect(formatClock(const Duration(milliseconds: 1999)), '0:01.99');
    });

    test('a Duration carrying microsecond precision from the scoring engine '
        'is truncated at the centisecond, not rounded: 3.047999s -> '
        '"0:03.04"', () {
      expect(
        formatClock(
          const Duration(seconds: 3, milliseconds: 47, microseconds: 999),
        ),
        '0:03.04',
      );
    });
  });
}
