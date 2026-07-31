import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';

/// Architecture v6 §4.3/D6 — `finalBandThresholdPercent == -missDelta` is a
/// load-bearing invariant, not an arbitrary pair of numbers: without it the
/// final band never arms and `RunOutcome.survived` becomes numerically
/// unreachable (a silent one-third loss of the game's output). `RunConfig`'s
/// constructor already asserts this defensively; these tests document the
/// invariant at the config-value level (§12 tester flag 6) rather than
/// duplicate the constructor assert itself.
void main() {
  group('RunConfig — the finalBandThresholdPercent == -missDelta invariant', () {
    test('defaults satisfy the invariant: finalBandThresholdPercent (10) == '
        '-missDelta (10)', () {
      const config = RunConfig.defaults;
      expect(config.finalBandThresholdPercent, -config.missDelta);
      expect(config.finalBandThresholdPercent, 10);
      expect(config.missDelta, -10);
    });

    test('a mismatched pair throws (constructor assert catches a future '
        'missDelta retune that forgets to update the final band too)', () {
      // Deliberately NOT `const` here: a const-constructed mismatch is a
      // *compile-time* constant-evaluation error (caught above, in effect,
      // by every other `const RunConfig(...)` in this suite failing to
      // compile if it violated the invariant) rather than a runtime
      // `AssertionError` — this test wants to observe the runtime throw.
      RunConfig buildMismatched() =>
          RunConfig(missDelta: -20, finalBandThresholdPercent: 10);
      expect(buildMismatched, throwsA(isA<AssertionError>()));
    });

    test('eternalHitCount stays >= 1 by default, guarding the run\'s only '
        'upper terminator (architecture v6 §5.1/§10 risk 3)', () {
      const config = RunConfig.defaults;
      expect(config.eternalHitCount, greaterThanOrEqualTo(1));
      expect(config.eternalHitCount, 12);
    });
  });
}
