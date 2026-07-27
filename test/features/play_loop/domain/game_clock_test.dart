import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/play_loop/domain/game_clock.dart';

/// `GameClock` (architecture v2 G1/§2/§9.10) wraps a single real `Stopwatch`
/// — no fake-clock injection point exists (by design: exactly one instance,
/// owned privately by `RunController`, architecture v2 §9 risk 10), so this
/// exercises the real monotonic clock with short, generously-bounded real
/// delays rather than asserting exact durations.
void main() {
  test('a fresh clock starts at zero elapsed and not running', () {
    final clock = GameClock();
    expect(clock.elapsed, Duration.zero);
    expect(clock.isRunning, isFalse);
  });

  test('start() begins advancing elapsed and flips isRunning', () async {
    final clock = GameClock();
    clock.start();
    expect(clock.isRunning, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      clock.elapsed,
      greaterThan(Duration.zero),
      reason: 'elapsed must advance once started',
    );
  });

  test('stop() returns the elapsed time at that instant and freezes it — '
      'further waiting does not advance elapsed after stop()', () async {
    final clock = GameClock();
    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final stopped = clock.stop();
    expect(clock.isRunning, isFalse);
    expect(stopped, clock.elapsed, reason: 'stop() returns the frozen elapsed');

    final frozenValue = clock.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      clock.elapsed,
      frozenValue,
      reason: 'a stopped Stopwatch must not keep advancing — this is the '
          'entire point of stop-before-background-jump safety (architecture '
          'v2 §9 risk 1)',
    );
  });

  test('reset() zeroes elapsed without starting it', () async {
    final clock = GameClock();
    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    clock.stop();

    clock.reset();
    expect(clock.elapsed, Duration.zero);
    expect(clock.isRunning, isFalse);
  });

  test('reset() while running zeroes elapsed but keeps it running '
      '(matches Stopwatch.reset() semantics; RunController always calls '
      'reset() then start() together, but reset() alone must not stop it)', () async {
    final clock = GameClock();
    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    clock.reset();
    // Still running, so a few microseconds may elapse between reset() and
    // this read — assert "essentially zero", not exactly zero.
    expect(clock.elapsed, lessThan(const Duration(milliseconds: 5)));
    expect(clock.isRunning, isTrue);
  });

  test('start() after stop() resumes counting up from the frozen value '
      '(Stopwatch.start() resumes, it does not reset)', () async {
    final clock = GameClock();
    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final beforeResume = clock.stop();

    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(clock.elapsed, greaterThan(beforeResume));
  });

  test('a full reset()+start() cycle (as RunController.startRunning() does) '
      'begins again from zero', () async {
    final clock = GameClock();
    clock.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    clock.stop();

    clock.reset();
    clock.start();
    // Immediately after the reset+start, elapsed should be small — nowhere
    // near the ~30ms accumulated in the previous attempt.
    expect(clock.elapsed, lessThan(const Duration(milliseconds: 20)));
  });
}
