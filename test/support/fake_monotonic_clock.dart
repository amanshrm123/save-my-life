// Test-only stand-in for `MonotonicClock` (lib/core/clock.dart).
//
// The real clock wraps a `Stopwatch` — real wall-clock elapsed time that
// cannot be fast-forwarded or rewound from a test. Since `clockProvider`
// (lib/features/run/run_controller.dart) is a plain Riverpod `Provider`,
// it can be overridden with an instance of this fake via
// `clockProvider.overrideWithValue(...)` in a `ProviderContainer`/
// `ProviderScope`, giving tests full, deterministic control over
// `elapsedMicroseconds` without waiting on real time or introducing flake.
//
// This does not touch production code — `MonotonicClock` has no virtual/
// abstract seam added for this; we simply override the one instance getter
// that matters (`elapsedMicroseconds`) via normal Dart subclassing.
import 'package:timing_tap/core/clock.dart';

class FakeMonotonicClock extends MonotonicClock {
  int _micros;

  FakeMonotonicClock([this._micros = 0]);

  @override
  int get elapsedMicroseconds => _micros;

  /// Jump directly to an absolute elapsed-microseconds value.
  void setMicros(int value) {
    _micros = value;
  }

  /// Advance by a relative number of microseconds.
  void advance(int deltaMicros) {
    _micros += deltaMicros;
  }
}
