/// Founder-resolved display format (architecture v2 §2/§Flag 2, re-resolved):
/// `SS:CC` (seconds : hundredths-of-a-second), e.g. `03:47` = 3.47s. The
/// seconds digit is NOT zero-padded (design v1 §1.3) — tabular/monospace
/// figures solve the digit-width jitter without artificially forcing "03:47".
String formatClock(Duration duration) {
  final totalCentiseconds = duration.inMilliseconds ~/ 10;
  final seconds = totalCentiseconds ~/ 100;
  final centiseconds = totalCentiseconds % 100;
  return '$seconds:${centiseconds.toString().padLeft(2, '0')}';
}
