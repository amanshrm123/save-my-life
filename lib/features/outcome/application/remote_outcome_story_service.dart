import 'dart:math';

import '../../play_loop/domain/run_state.dart';
import '../../play_loop/domain/run_summary.dart';
import '../domain/outcome_story_content.dart';
import '../domain/story_cycle_selector.dart';
import '../domain/story_pool.dart';
import '../domain/story_renderer.dart';
import '../domain/story_selector.dart';
import 'story_cycle_store.dart';
import 'story_pool_repository.dart';
import 'outcome_story_service.dart';

/// Real implementation of [OutcomeStoryService] backed by a remote-fetched,
/// cached, and bundled-fallback content pool (remote-story-config-
/// implementation-spec §2.6). Fully absorbs
/// `LocalOutcomeStoryService` — R2: keeping the old class alongside would be
/// dead code the moment the provider swap happens, and its only
/// distinguishing feature (compile-time pools) is exactly what this feature
/// removes.
class RemoteOutcomeStoryService implements OutcomeStoryService {
  RemoteOutcomeStoryService({
    required StoryPoolRepository repository,
    required StoryCycleStore cycleStore,
    Random? random,
  }) : _repository = repository,
       _cycleStore = cycleStore,
       _random = random ?? Random();

  final StoryPoolRepository _repository;
  final StoryCycleStore _cycleStore;
  final Random _random;

  final StoryCycleSelector _cycleSelector = const StoryCycleSelector();
  final StorySelector _storySelector = const StorySelector();
  final StoryRenderer _renderer = const StoryRenderer();

  /// Beat indices are gone (replaced by the ID-keyed cycle store); only the
  /// three icon avoid-indices remain, mirroring `LocalOutcomeStoryService`'s
  /// per-tier "never the same icon twice in a row" behaviour (options §8.5,
  /// unchanged).
  int? _lastDeathIcon;
  int? _lastSurvivedIcon;
  int? _lastEternalIcon;

  /// Identity marker of the last pool `_cycleStore.pruneAgainst` was run
  /// against — deliberately an `int`, not a `StoryPool` reference (memory-
  /// safety M6/M8): holding the actual old `StoryPool` object here would
  /// keep it (and its ~66 `StoryBeat`s) resident for as long as this field
  /// isn't reassigned, i.e. potentially a whole app session after a
  /// background `refreshIfStale()` swap, if the player doesn't reach
  /// another outcome card before then. `identityHashCode` (not
  /// `pool.contentVersion`) is used because `contentVersion` defaults to
  /// `0` for any payload that omits the field, so two genuinely different
  /// pool installs within one session could collide on `0` and wrongly
  /// suppress a needed re-prune; `identityHashCode` tracks the same object
  /// identity `identical()` would have, without retaining a reference to
  /// the object itself.
  int? _prunedAgainstIdentity;

  /// Toggle to exercise the N/A fallback path in dev/tests; defaults to
  /// always succeeding so the everyday flow just works. Preserved verbatim
  /// from `LocalOutcomeStoryService`.
  bool forceFailure = false;

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) async {
    // First line, before any await, so this remains fully inert: it
    // consumes no `Random` draw and mutates no cycle state.
    if (forceFailure) return OutcomeStoryContent.naFor;

    final pool =
        _repository.current ??
        await _repository.load().timeout(
          kStoryFetchTimeout,
          onTimeout: () => StoryPool.empty,
        );

    final poolIdentity = identityHashCode(pool);
    if (poolIdentity != _prunedAgainstIdentity) {
      _cycleStore.pruneAgainst(pool);
      _prunedAgainstIdentity = poolIdentity;
    }

    final tier = pool.tierFor(summary.outcome);
    if (tier.isEmpty) return OutcomeStoryContent.naFor;

    final beat = _cycleSelector.pick(
      tier.beats,
      _cycleStore.seenFor(summary.outcome),
      _cycleStore.lastShownFor(summary.outcome),
      _random,
    );
    if (beat == null) return OutcomeStoryContent.naFor;
    _cycleStore.record(summary.outcome, beat.id);

    final (icon, iconIndex) = _storySelector.pick(
      tier.icons,
      _random,
      avoidIndex: _iconAvoidFor(summary.outcome),
    );
    _setIconAvoidFor(summary.outcome, iconIndex);

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

  int? _iconAvoidFor(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return _lastDeathIcon;
      case RunOutcome.survived:
        return _lastSurvivedIcon;
      case RunOutcome.eternal:
        return _lastEternalIcon;
    }
  }

  void _setIconAvoidFor(RunOutcome outcome, int index) {
    switch (outcome) {
      case RunOutcome.death:
        _lastDeathIcon = index;
      case RunOutcome.survived:
        _lastSurvivedIcon = index;
      case RunOutcome.eternal:
        _lastEternalIcon = index;
    }
  }
}
