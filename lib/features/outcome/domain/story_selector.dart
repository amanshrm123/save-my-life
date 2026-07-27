import 'dart:math';

/// Pure (no Flutter) content-pool selection (architecture v4 §1/§3, renamed
/// from `FlavorSelector` — same technique, now shared by both the beat pools
/// and the icon pools). Selection is uniform-random from the seeded pool,
/// with one refinement: the immediately-previous pick (if any, tracked by
/// the caller and passed as `avoidIndex`) is excluded, so a single session
/// can't show the exact same beat — or the exact same icon — twice in a
/// row. Deliberately lightweight: no persisted history, no full
/// non-repeat-until-exhausted guarantee, just closing the most jarring case
/// a player actually notices.
class StorySelector {
  const StorySelector();

  /// Uniform-random pick from `pool` using the supplied `random` (injectable
  /// for deterministic tests; callers pass a real `Random()` in production).
  /// Returns the entry plus its index so the caller can pass that index back
  /// in as `avoidIndex` on the next pick from the same pool. If the random
  /// draw lands on `avoidIndex`, it's shifted to the next slot (wrapping)
  /// rather than re-rolled, so this is O(1) and never loops — and degrades
  /// gracefully when `pool.length == 1`.
  (T entry, int index) pick<T>(List<T> pool, Random random, {int? avoidIndex}) {
    var index = random.nextInt(pool.length);
    if (pool.length > 1 && index == avoidIndex) {
      index = (index + 1) % pool.length;
    }
    return (pool[index], index);
  }
}
