import 'story_beat.dart';

/// Seeded eternal-pool content (architecture v4 §1/§7): 6 hand-authored
/// entries, same seeded count as the pre-redesign `eternalLines` — but
/// `EternalFlavor.sub` is dropped entirely: "✨ Eternal · Top 0.3%" is now
/// static chip copy (founder-resolved, restored as unverified flavor, not a
/// per-entry qualitative flex line paired with each pick).
StoryBeat _e(String headline, String verbPhrase) {
  final capitalized = verbPhrase[0].toUpperCase() + verbPhrase.substring(1);
  return StoryBeat(
    headline: headline,
    named: '{name} $verbPhrase.',
    anonymous: '$capitalized.',
  );
}

final List<StoryBeat> eternalBeats = List.unmodifiable([
  _e('Never wobbled once.', 'never even wobbled'),
  _e("Read the clock's mind.", 'read the clock like a mind reader'),
  _e('Three taps of pure art.', 'turned the first three taps into art'),
  _e('Made perfect look boring.', 'made perfect look boring'),
  _e('No warm-up needed.', "didn't need a warm-up"),
  _e('Beat the clock before it knew.', 'beat the clock before it knew it was a fight'),
]);
