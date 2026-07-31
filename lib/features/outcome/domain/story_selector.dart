import 'dart:math';

/// Pure (no Flutter) content-pool selection (architecture v4 §1/§3, renamed
/// from `FlavorSelector` — same technique). Selection is uniform-random from
/// the seeded pool, with one refinement: the immediately-previous pick (if
/// any, tracked by the caller and passed as `avoidIndex`) is excluded, so a
/// single session can't show the exact same icon twice in a row.
/// Deliberately lightweight: no persisted history, no full
/// non-repeat-until-exhausted guarantee, just closing the most jarring case
/// a player actually notices.
///
/// As of the remote-story-config feature this serves **icons only** — beat
/// selection (dedup-until-exhausted, ID-keyed) moved to
/// `StoryCycleSelector`, which this class knows nothing about.
class StorySelector {
  const StorySelector();

  /// Uniform-random pick from `pool` using the supplied `random` (injectable
  /// for deterministic tests; callers pass a real `Random()` in production).
  /// Returns the entry plus its index so the caller can pass that index back
  /// in as `avoidIndex` on the next pick from the same pool. If the random
  /// draw lands on `avoidIndex`, it's shifted to the next slot (wrapping)
  /// rather than re-rolled, so this is O(1) and never loops — and degrades
  /// gracefully when `pool.length == 1`.
  ///
  /// Defence-in-depth only (remote-story-config-implementation-spec §2.3's
  /// "empty-pool rule"): throws a clear `ArgumentError` for an empty `pool`
  /// rather than letting `random.nextInt(0)` reach an ambiguous
  /// `RangeError`. The real caller (`RemoteOutcomeStoryService`) already
  /// checks `tier.isEmpty` first and short-circuits to
  /// `OutcomeStoryContent.naFor` before this is ever reached with an empty
  /// pool — this guard exists purely so that invariant has a named failure
  /// mode if it's ever violated, in both debug and release builds.
  (T entry, int index) pick<T>(List<T> pool, Random random, {int? avoidIndex}) {
    if (pool.isEmpty) {
      throw ArgumentError.value(pool, 'pool', 'must not be empty');
    }
    var index = random.nextInt(pool.length);
    if (pool.length > 1 && index == avoidIndex) {
      index = (index + 1) % pool.length;
    }
    return (pool[index], index);
  }
}
