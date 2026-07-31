import 'story_pool_codec.dart';

/// One pooled headline+story entry (architecture v4 §1) — the headline and
/// story are bundled together, NOT independently randomized, so cross-
/// pairing them can never produce a self-contradiction (e.g. a "One tap too
/// late." headline sitting over a story about tapping *early*). The
/// headline is a compressed restatement of the story's punchline, so the
/// two are semantically welded; only the top-right icon (the pool's `icons`
/// list) is drawn independently, since it's tonally generic enough to pair
/// safely with any beat in its pool.
class StoryBeat {
  const StoryBeat({
    required this.id,
    required this.headline,
    required this.named,
    required this.anonymous,
  });

  /// Stable, immutable, never-recycled content ID (`death_017`) — the key the
  /// dedup cycle is stored against. Assigned in the content file, never
  /// derived from position, never regenerated on reword. See
  /// remote-story-config-options.md §8.1 for the three ID rules.
  final String id;

  /// NOT name-templated; may contain `{min}`/`{peak}` placeholders,
  /// substituted by `StoryRenderer`.
  final String headline;

  /// The story, containing a literal `{name}` placeholder — deliberately
  /// left unsubstituted by `StoryRenderer` so the widget layer can color
  /// just the name span. May also contain `{min}`/`{peak}` placeholders.
  final String named;

  /// Name-free rewrite of [named] for the anonymous-player card variant
  /// (design v1 §4.4's "not a fourth content pool" resolution, applied
  /// generically across all three tiers).
  final String anonymous;

  /// Throws [StoryPoolFormatException] on any missing/blank/non-String field.
  /// Unknown keys are ignored (forward-compatibility with a richer future
  /// schema published to already-shipped clients).
  factory StoryBeat.fromJson(Map<String, dynamic> json) {
    String requireNonBlankString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw StoryPoolFormatException('beat field "$key" missing or blank');
      }
      return value;
    }

    return StoryBeat(
      id: requireNonBlankString('id'),
      headline: requireNonBlankString('headline'),
      named: requireNonBlankString('named'),
      anonymous: requireNonBlankString('anonymous'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'headline': headline,
    'named': named,
    'anonymous': anonymous,
  };
}
