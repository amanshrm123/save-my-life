import 'story_beat.dart';

/// Seeded survived-pool content (architecture v4 §1/§7): 10 hand-authored
/// entries, same seeded count as the pre-redesign `survivedLines`. Two
/// entries deliberately fold in `{min}` (`RunSummary.minLifePercent`) so the
/// stat the old "Down to N% — one perfect press back from the edge."
/// sub-line used to carry survives onto the card via authored copy instead
/// (architecture v4 §1's numeric-placeholder rule) — matching the mockup's
/// own "Saved at 3%." headline.
StoryBeat _s(String headline, String verbPhrase) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return StoryBeat(
    headline: headline,
    named: '{name} $verbPhrase.',
    anonymous: '$capitalized.',
  );
}

final List<StoryBeat> survivedBeats = List.unmodifiable([
  _s('Saved at {min}%.', 'found the exact instant with nothing left to spare'),
  _s('Out of nowhere.', 'pulled the perfect tap out of nowhere'),
  _s('Read it cold.', 'read the clock like it was standing still'),
  _s('Landed the one that mattered.', 'landed the one stop that mattered'),
  _s('Panic, then a clean hit.', 'turned panic into a clean hit'),
  _s("Didn't blink at sudden death.", "stared down sudden death and didn't blink"),
  _s('Calm, at {min}%.', 'found calm in the last possible heartbeat'),
  _s('Clutched when it counted.', 'clutched it when it counted most'),
  _s('Proved the final band wrong.', 'proved the final band wrong'),
  _s('Stuck the landing.', 'walked the tightrope and stuck the landing'),
]);
