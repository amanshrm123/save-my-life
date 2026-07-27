import 'dart:math';

import '../../play_loop/domain/run_state.dart';
import '../../play_loop/domain/run_summary.dart';
import '../domain/death_beats.dart';
import '../domain/eternal_beats.dart';
import '../domain/outcome_story_content.dart';
import '../domain/story_beat.dart';
import '../domain/story_icons.dart';
import '../domain/story_renderer.dart';
import '../domain/story_selector.dart';
import '../domain/survived_beats.dart';
import 'outcome_story_service.dart';

/// Real (local) implementation of [OutcomeStoryService] this pass
/// (architecture v4 §2) — draws from the seeded pools, substitutes
/// `{min}`/`{peak}` via `StoryRenderer`, and resolves near-instantly (the
/// 2-second minimum loading floor is enforced one layer up, in
/// `outcomeStoryProvider`, not here).
///
/// Owns the last-shown-index bookkeeping for BOTH the beat pool and the
/// icon pool, per tier — six `int?`s total (architecture §3/§8 risk 7),
/// constant and tiny for the app session, not per-run accumulating.
///
/// Named `Local…`, not `Fake…` (architecture §2): this ships real,
/// player-visible content, unlike `FakeAdService`'s genuine no-op stub —
/// it's a real local implementation of a source that will later be remote.
///
/// `forceFailure` mirrors `FakeAdService`'s exact pattern for testability:
/// when true, `fetchStory` returns `OutcomeStoryContent.naFor` directly
/// rather than throwing, so there is exactly one code path downstream and no
/// try/catch anywhere in the UI.
class LocalOutcomeStoryService implements OutcomeStoryService {
  LocalOutcomeStoryService({Random? random}) : _random = random ?? Random();

  final Random _random;
  final StorySelector _selector = const StorySelector();
  final StoryRenderer _renderer = const StoryRenderer();

  /// Toggle to exercise the N/A fallback path in dev/tests; defaults to
  /// always succeeding so the everyday flow just works.
  bool forceFailure = false;

  int? _lastDeathBeat;
  int? _lastSurvivedBeat;
  int? _lastEternalBeat;
  int? _lastDeathIcon;
  int? _lastSurvivedIcon;
  int? _lastEternalIcon;

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) async {
    if (forceFailure) return OutcomeStoryContent.naFor;

    switch (summary.outcome) {
      case RunOutcome.death:
        return _resolve(
          deathBeats,
          deathIcons,
          summary,
          beatAvoid: _lastDeathBeat,
          iconAvoid: _lastDeathIcon,
          onBeat: (i) => _lastDeathBeat = i,
          onIcon: (i) => _lastDeathIcon = i,
        );
      case RunOutcome.survived:
        return _resolve(
          survivedBeats,
          survivedIcons,
          summary,
          beatAvoid: _lastSurvivedBeat,
          iconAvoid: _lastSurvivedIcon,
          onBeat: (i) => _lastSurvivedBeat = i,
          onIcon: (i) => _lastSurvivedIcon = i,
        );
      case RunOutcome.eternal:
        return _resolve(
          eternalBeats,
          eternalIcons,
          summary,
          beatAvoid: _lastEternalBeat,
          iconAvoid: _lastEternalIcon,
          onBeat: (i) => _lastEternalBeat = i,
          onIcon: (i) => _lastEternalIcon = i,
        );
    }
  }

  OutcomeStoryContent _resolve(
    List<StoryBeat> beats,
    List<String> icons,
    RunSummary summary, {
    required int? beatAvoid,
    required int? iconAvoid,
    required void Function(int index) onBeat,
    required void Function(int index) onIcon,
  }) {
    final (beat, beatIndex) = _selector.pick(beats, _random, avoidIndex: beatAvoid);
    onBeat(beatIndex);

    // Independently drawn from the beat above it (architecture v4 §1) — its
    // own last-shown memory, its own pool, no 1:1 pairing.
    final (icon, iconIndex) = _selector.pick(icons, _random, avoidIndex: iconAvoid);
    onIcon(iconIndex);

    final rendered = _renderer.render(
      beat,
      minLifePercent: summary.minLifePercent,
      peakLifePercent: summary.peakLifePercent,
    );

    return OutcomeStoryContent(
      headline: rendered.headline,
      storyNamed: rendered.named,
      storyAnonymous: rendered.anonymous,
      icon: icon,
      isFallback: false,
    );
  }
}
