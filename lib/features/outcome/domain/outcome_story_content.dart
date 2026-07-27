/// Fully-resolved, ready-to-render card content for one `RunSummary`
/// (architecture v4 §1) — the three "configurable" slots (`headline`,
/// story, `icon`) that vary run to run, as opposed to the static per-tier
/// chip/palette/tagline/wordmark/store-badges the widget layer owns
/// directly.
class OutcomeStoryContent {
  const OutcomeStoryContent({
    required this.headline,
    required this.storyNamed,
    required this.storyAnonymous,
    required this.icon,
    required this.isFallback,
  });

  /// Already `{min}`/`{peak}`-substituted by `StoryRenderer`.
  final String headline;

  /// Still contains the literal `{name}` placeholder — the widget layer
  /// splits on it to color just the name span, per each tier's own
  /// name-span color (design v1 §1.1).
  final String storyNamed;

  final String storyAnonymous;

  /// Independently-drawn top-right icon glyph (architecture v4 §1) — a
  /// plain `String`, not paired 1:1 with the beat above.
  final String icon;

  /// True only on the simulated-fetch-failure path (architecture v4 §2) —
  /// every field above is the literal `'N/A'` in that case. The UI never
  /// branches on this directly (there is no error UI path); it exists so a
  /// future analytics hook could distinguish a real card from the fallback
  /// without inspecting string contents.
  final bool isFallback;

  /// The literal "N/A on every field" fallback (architecture v4 §1/§2) —
  /// returned directly by `LocalOutcomeStoryService.fetchStory` when
  /// `forceFailure` is set, and reused by the screen's defence-in-depth
  /// `error:` branch even though that branch is unreachable by construction.
  static const OutcomeStoryContent naFor = OutcomeStoryContent(
    headline: 'N/A',
    storyNamed: 'N/A',
    storyAnonymous: 'N/A',
    icon: 'N/A',
    isFallback: true,
  );
}
