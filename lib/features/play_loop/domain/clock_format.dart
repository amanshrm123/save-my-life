/// Display format `M:SS.CC` (architecture v6 D10/§2.2), e.g. `0:04.70` =
/// 4.70s. Minutes is NOT zero-padded (carrying forward the existing
/// convention that the leading field is never padded); seconds and
/// hundredths are always zero-padded to 2 digits.
///
/// Replaces the retired `SS:CC` format (architecture v2 §2/§Flag 2), whose
/// readout (`4:70`) was not a valid clock reading in any format. Real time
/// and the existing short target range (`2.00s`-`4.90s`) are unchanged —
/// only the readout gained a real minutes field and a decimal separator.
///
/// Per architecture v6 §10.1 (memory-safety, load-bearing): this is called
/// every frame at 60fps from `StopwatchPlate`'s `ValueListenableBuilder`.
/// Implementation MUST stay a single string interpolation over integer
/// arithmetic — no `intl`/`DateFormat` (heavier, drags a dependency into a
/// hot path), no intermediate `List`s or `RegExp`, and no memoization/cache
/// keyed on `Duration` (would be unbounded across a run — a genuine leak,
/// not an optimization).
String formatClock(Duration duration) {
  final totalCentis = duration.inMilliseconds ~/ 10;
  final minutes = totalCentis ~/ 6000;
  final seconds = (totalCentis ~/ 100) % 60;
  final centis = totalCentis % 100;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
}
