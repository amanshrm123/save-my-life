import 'flavor.dart';

/// Seeded death-pool content (architecture v3 §1 item 4 / §3): 50 hand-
/// authored entries, `catalogNo` 1-50, of the aspirational 1000 the catalog
/// line honestly still reads. Append more entries here later — no schema or
/// code change needed elsewhere.
DeathFlavor _d(int catalogNo, String verbPhrase) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return DeathFlavor(
    catalogNo: catalogNo,
    named: '{name} $verbPhrase.',
    anonymous: '$capitalized.',
  );
}

final List<DeathFlavor> deathLines = [
  _d(1, 'blinked at the exact wrong moment'),
  _d(2, 'trusted a gut feeling that lied'),
  _d(3, 'flinched a heartbeat too soon'),
  _d(4, 'counted one Mississippi too many'),
  _d(5, 'watched the clock instead of feeling it'),
  _d(6, 'got greedy for one more perfect'),
  _d(7, 'let the thumb wander'),
  _d(8, 'second-guessed a clean read'),
  _d(9, 'chased the number past the peak'),
  _d(10, 'froze for half a beat'),
  _d(11, 'jumped the gun by a hair'),
  _d(12, 'lagged behind by a breath'),
  _d(13, 'got cocky after three perfects'),
  _d(14, 'let a notification steal the moment'),
  _d(15, 'sneezed at the worst possible time'),
  _d(16, 'overcorrected after a miss'),
  _d(17, 'tapped like the room was on fire'),
  _d(18, 'waited for a sign that never came'),
  _d(19, 'mistimed the exhale'),
  _d(20, 'got hypnotized by the numbers'),
  _d(21, 'panicked in the final band'),
  _d(22, 'tried to outsmart the clock'),
  _d(23, "let confidence write a check the thumb couldn't cash"),
  _d(24, 'drifted a fraction of a second late'),
  _d(25, 'rushed the last stretch'),
  _d(26, 'misjudged the rhythm'),
  _d(27, 'blinked twice for good luck'),
  _d(28, 'got distracted by a passing thought'),
  _d(29, 'pushed too hard, too late'),
  _d(30, 'eased off right before the mark'),
  _d(31, 'trusted muscle memory that betrayed them'),
  _d(32, 'stared too long and forgot to move'),
  _d(33, 'let the pressure win'),
  _d(34, 'tapped on reflex instead of instinct'),
  _d(35, 'miscounted the beat'),
  _d(36, 'chased perfection into a miss'),
  _d(37, 'got twitchy under the red bar'),
  _d(38, 'held on a fraction too long'),
  _d(39, 'let a shaky hand decide'),
  _d(40, 'tried to feel it instead of watching it'),
  _d(41, 'mistimed a coin-flip guess'),
  _d(42, 'ran out of nerve at the edge'),
  _d(43, 'broke rhythm on the sudden-death tap'),
  _d(44, 'let the silence get too loud'),
  _d(45, 'tapped before the brain caught up'),
  _d(46, 'lost the beat chasing a comeback'),
  _d(47, 'gave the clock too much respect'),
  _d(48, 'gave the clock too little respect'),
  _d(49, 'flinched when the room went quiet'),
  _d(50, 'ran the streak straight into the wall'),
];
