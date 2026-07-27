/// One pooled headline+story entry (architecture v4 §1) — the headline and
/// story are bundled together, NOT independently randomized, so cross-
/// pairing them can never produce a self-contradiction (e.g. a "One tap too
/// late." headline sitting over a story about tapping *early*). The
/// headline is a compressed restatement of the story's punchline, so the
/// two are semantically welded; only the top-right icon (`story_icons.dart`)
/// is drawn independently, since it's tonally generic enough to pair safely
/// with any beat in its pool.
class StoryBeat {
  const StoryBeat({
    required this.headline,
    required this.named,
    required this.anonymous,
  });

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
}
