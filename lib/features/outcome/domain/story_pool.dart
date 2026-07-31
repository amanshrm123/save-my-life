import '../../play_loop/domain/run_state.dart';
import 'story_beat.dart';

/// One outcome tier's content — a beat pool and an icon pool, each drawn
/// independently (architecture v4 §1; see `story_beat.dart`'s doc comment).
class StoryTierPool {
  const StoryTierPool({required this.beats, required this.icons});

  /// `List.unmodifiable` — exactly one pool instance is resident at a time
  /// (memory-safety M6).
  final List<StoryBeat> beats;

  /// `List.unmodifiable`.
  final List<String> icons;

  /// True if either list is empty — a tier with no beats or no icons cannot
  /// render a card and must degrade to `OutcomeStoryContent.naFor`.
  bool get isEmpty => beats.isEmpty || icons.isEmpty;
}

/// The full, immutable, parsed content pool for one installed payload —
/// either the bundled fallback asset or a successfully-decoded remote
/// fetch. Always goes through `StoryPoolCodec.decode` (§2.2); there is no
/// other way to construct a non-empty instance in production code.
class StoryPool {
  const StoryPool({
    required this.contentVersion,
    required this.death,
    required this.survived,
    required this.eternal,
  });

  /// Defaults to `0` when absent from the payload (`StoryPoolCodec`). Used
  /// only for `StoryPoolRepository.refreshIfStale`'s "don't bother
  /// re-installing" short-circuit — `0` is treated as "unknown", never
  /// short-circuited against.
  final int contentVersion;

  final StoryTierPool death;
  final StoryTierPool survived;
  final StoryTierPool eternal;

  /// Exhaustive switch, no default — a new `RunOutcome` value must be a
  /// compile error here, not a silent fallthrough.
  StoryTierPool tierFor(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return death;
      case RunOutcome.survived:
        return survived;
      case RunOutcome.eternal:
        return eternal;
    }
  }

  /// Every tier empty. The terminal state of the fallback chain — a service
  /// holding this returns `OutcomeStoryContent.naFor` for every tier.
  static const StoryPool empty = StoryPool(
    contentVersion: 0,
    death: StoryTierPool(beats: [], icons: []),
    survived: StoryTierPool(beats: [], icons: []),
    eternal: StoryTierPool(beats: [], icons: []),
  );
}
