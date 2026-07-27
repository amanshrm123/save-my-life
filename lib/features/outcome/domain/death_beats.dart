import 'story_beat.dart';

/// Seeded death-pool content (architecture v4 §1/§7): 50 hand-authored
/// entries, same seeded count as the pre-redesign `deathLines` (architecture
/// v3 §1 item 4) — each existing line's "way it happened" verb phrase gains
/// a punchy, semantically-matched headline (architecture v4 §1's "headline
/// is a compressed restatement of the story's punchline" rule: never author
/// a headline that could contradict its own story's timing, e.g. "late"
/// over an "early" story). No `catalogNo` — the old "Death #N of 1000"
/// catalog line is dropped entirely (founder-resolved).
StoryBeat _d(String headline, String verbPhrase) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return StoryBeat(
    headline: headline,
    named: '{name} $verbPhrase.',
    anonymous: '$capitalized.',
  );
}

final List<StoryBeat> deathBeats = List.unmodifiable([
  _d('Blinked. Gone.', 'blinked at the exact wrong moment'),
  _d('A gut feeling lied.', 'trusted a gut feeling that lied'),
  _d('One heartbeat too soon.', 'flinched a heartbeat too soon'),
  _d('One Mississippi too many.', 'counted one Mississippi too many'),
  _d("Watched. Didn't feel it.", 'watched the clock instead of feeling it'),
  _d('Wanted one more perfect.', 'got greedy for one more perfect'),
  _d('The thumb wandered.', 'let the thumb wander'),
  _d('Doubted a clean read.', 'second-guessed a clean read'),
  _d('Chased it past the peak.', 'chased the number past the peak'),
  _d('Froze. That was it.', 'froze for half a beat'),
  _d('Jumped the gun.', 'jumped the gun by a hair'),
  _d('One breath behind.', 'lagged behind by a breath'),
  _d('Cocky after three perfects.', 'got cocky after three perfects'),
  _d('A notification stole it.', 'let a notification steal the moment'),
  _d('Sneezed. Terrible timing.', 'sneezed at the worst possible time'),
  _d('Overcorrected. Fatal.', 'overcorrected after a miss'),
  _d('Tapped in a panic.', 'tapped like the room was on fire'),
  _d('Waited for a sign.', 'waited for a sign that never came'),
  _d('Mistimed the exhale.', 'mistimed the exhale'),
  _d('Hypnotized by the numbers.', 'got hypnotized by the numbers'),
  _d('Panicked in the final band.', 'panicked in the final band'),
  _d('Tried to outsmart the clock.', 'tried to outsmart the clock'),
  _d(
    'Confidence wrote a bad check.',
    "let confidence write a check the thumb couldn't cash",
  ),
  _d('A fraction of a second late.', 'drifted a fraction of a second late'),
  _d('Rushed the finish.', 'rushed the last stretch'),
  _d('Misjudged the rhythm.', 'misjudged the rhythm'),
  _d('Blinked twice. No luck.', 'blinked twice for good luck'),
  _d('Distracted for one second.', 'got distracted by a passing thought'),
  _d('Pushed too hard, too late.', 'pushed too hard, too late'),
  _d('Eased off too soon.', 'eased off right before the mark'),
  _d('Muscle memory betrayed them.', 'trusted muscle memory that betrayed them'),
  _d('Stared too long.', 'stared too long and forgot to move'),
  _d('The pressure won.', 'let the pressure win'),
  _d('Reflex, not instinct.', 'tapped on reflex instead of instinct'),
  _d('Miscounted the beat.', 'miscounted the beat'),
  _d('Chased perfection. Missed.', 'chased perfection into a miss'),
  _d('Twitchy under the red bar.', 'got twitchy under the red bar'),
  _d('Held on too long.', 'held on a fraction too long'),
  _d('A shaky hand decided.', 'let a shaky hand decide'),
  _d('Tried to feel it.', 'tried to feel it instead of watching it'),
  _d('A coin-flip guess. Wrong.', 'mistimed a coin-flip guess'),
  _d('Ran out of nerve.', 'ran out of nerve at the edge'),
  _d('Broke rhythm at sudden death.', 'broke rhythm on the sudden-death tap'),
  _d('The silence got too loud.', 'let the silence get too loud'),
  _d('Tapped before thinking.', 'tapped before the brain caught up'),
  _d('Lost the beat chasing a comeback.', 'lost the beat chasing a comeback'),
  _d('Too much respect for the clock.', 'gave the clock too much respect'),
  _d('Too little respect for the clock.', 'gave the clock too little respect'),
  _d('Flinched at the silence.', 'flinched when the room went quiet'),
  _d('Ran the streak into a wall.', 'ran the streak straight into the wall'),
]);
