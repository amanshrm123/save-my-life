/// The only clock allowed in the timing path.
///
/// Wraps a Dart [Stopwatch] to expose monotonic, microsecond-resolution
/// elapsed time. `DateTime.now()` (wall clock) must never be used for
/// timing-engine measurement — it can jump on clock sync and corrupt
/// deltas (see docs/discovery/TimingTap_Discovery_v1.md §3a, rule 1).
///
/// A single instance of this class is shared by the tap-measurement path
/// (`tap_surface.dart`) and `RunController` (round timing/re-rolling) so
/// every reader agrees on the same zero point — no drifting noise between
/// independent clocks. (There was previously also a display path here,
/// `indicator_painter.dart`'s moving progress lane — removed in the
/// play-loop-v2.md exact-fidelity pass since the mockup has no equivalent
/// and nothing else depended on it being mounted.)
class MonotonicClock {
  final Stopwatch _stopwatch = Stopwatch();

  /// Starts the clock. Call once when a run begins.
  void start() {
    _stopwatch.start();
  }

  /// Stops the clock. The elapsed time is preserved and can still be read.
  void stop() {
    _stopwatch.stop();
  }

  /// Resets elapsed time to zero. Does not affect running/stopped state.
  void reset() {
    _stopwatch.reset();
  }

  /// Microsecond-resolution elapsed time since [start] was called.
  int get elapsedMicroseconds => _stopwatch.elapsedMicroseconds;

  bool get isRunning => _stopwatch.isRunning;
}
