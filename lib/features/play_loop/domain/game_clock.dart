/// Monotonic run clock (architecture v2 G1 / §2, §9.10).
///
/// Wraps a single `Stopwatch` — **never** `DateTime.now()` — so elapsed time
/// can't be corrupted by wall-clock adjustments (timezone/NTP changes, user
/// changing the device clock mid-run, etc). Exactly one instance is owned by
/// `RunController`; it is never instantiated inside a widget.
class GameClock {
  final Stopwatch _stopwatch = Stopwatch();

  /// Starts (or resumes) the underlying stopwatch.
  void start() => _stopwatch.start();

  /// Stops the stopwatch and returns the elapsed [Duration] at the instant
  /// of the call. This is the literal "stop-time" fed into scoring.
  Duration stop() {
    _stopwatch.stop();
    return _stopwatch.elapsed;
  }

  /// Resets the stopwatch back to zero (does not start it).
  void reset() => _stopwatch.reset();

  /// Microsecond-precision elapsed time since the last [reset]/[start].
  /// All scoring math reads this (or a captured snapshot of it) — never a
  /// wall-clock timestamp.
  Duration get elapsed => _stopwatch.elapsed;

  bool get isRunning => _stopwatch.isRunning;
}
