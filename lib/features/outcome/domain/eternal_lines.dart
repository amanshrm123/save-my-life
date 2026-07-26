import 'flavor.dart';

/// Seeded eternal-pool content (architecture v3 §1 item 4 / §3): 6
/// hand-authored entries, each pairing its "way" (named/anonymous flavor
/// line) with its own "sub" qualitative flex line (design v1 §2.3 — Eternal
/// has no numeric stat left to report once the catalog line states the
/// perfect count, so both fields swap together per pick rather than the
/// sub-line being derived from `RunSummary`).
EternalFlavor _e(String verbPhrase, String sub) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return EternalFlavor(named: '{name} $verbPhrase.', anonymous: '$capitalized.', sub: sub);
}

final List<EternalFlavor> eternalLines = [
  _e(
    'never even wobbled',
    'Three perfect taps from cold. Almost nobody does this.',
  ),
  _e(
    'read the clock like a mind reader',
    'A flawless start, first try. Vanishingly rare.',
  ),
  _e(
    'turned the first three taps into art',
    'No hesitation, no fear — just perfect timing, back to back.',
  ),
  _e(
    'made perfect look boring',
    'Cold open, clean sweep. Almost nobody pulls this off.',
  ),
  _e(
    'didn\'t need a warm-up',
    'Perfect from the first tap onward. This almost never happens.',
  ),
  _e(
    'beat the clock before it knew it was a fight',
    'Three for three, no margin needed. A genuine rarity.',
  ),
];
