import 'story_beat.dart';

/// `{min}`/`{peak}` substitution (architecture v4 §1) — a two-argument
/// extension of the old `FlavorSelector.render()`'s single `{name}`
/// substitution. `{name}` is deliberately left untouched here: it survives
/// into `OutcomeStoryContent.storyNamed` so the widget layer can color just
/// the name span with its own tier color. `{min}`/`{peak}` need no per-run
/// styling, so they're substituted once, at this layer, from
/// `RunSummary.minLifePercent`/`peakLifePercent`.
///
/// `{peak}` is currently unused by any of the pooled beats (only `{min}`,
/// in two `survivedBeats` entries) — kept wired up here deliberately for
/// forward-compatibility rather than trimmed, since a future beat authored
/// around a run's peak life percent is a reasonable, low-cost thing to
/// want without touching this renderer again.
class StoryRenderer {
  const StoryRenderer();

  /// Renders [beat] against one run's stats, returning a new `StoryBeat`
  /// with `{min}`/`{peak}` substituted in `headline`, `named`, and
  /// `anonymous` alike (a beat's headline may carry either placeholder, and
  /// so may either story variant) — `{name}` in `named` is left as-is.
  StoryBeat render(
    StoryBeat beat, {
    required int minLifePercent,
    required int peakLifePercent,
  }) {
    String substitute(String text) => text
        .replaceAll('{min}', '$minLifePercent')
        .replaceAll('{peak}', '$peakLifePercent');

    return StoryBeat(
      headline: substitute(beat.headline),
      named: substitute(beat.named),
      anonymous: substitute(beat.anonymous),
    );
  }
}
