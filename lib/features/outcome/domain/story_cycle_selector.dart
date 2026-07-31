import 'dart:math';

import 'story_beat.dart';

/// Pure (no Flutter, no persistence) ID-keyed dedup-until-exhausted
/// selection over a beat pool (remote-story-config-implementation-spec
/// §2.3 / options §8.3's algorithm, verbatim). Expressed as a function of
/// mutable caller-owned state so it stays trivially testable — the caller
/// (`StoryCycleStore`) owns persistence.
class StoryCycleSelector {
  const StoryCycleSelector();

  /// Returns `null` iff [pool] is empty. Never throws.
  ///
  /// Mutates [seenIds] (adds the chosen ID; clears it first on a cycle
  /// exhaustion). The caller is responsible for persisting [seenIds] and the
  /// returned beat's ID afterwards.
  ///
  /// Two properties this deliberately preserves (easy to "simplify" away):
  /// - The boundary beat (the one shown right before a cycle reset) is
  ///   excluded from the first draw of the new cycle, but is **not** seeded
  ///   into the fresh [seenIds] — it stays eligible for the rest of that
  ///   cycle.
  /// - `seenIds.clear()` happens before the reset draw, not after, so the
  ///   newly-chosen beat is the only member of the fresh set.
  StoryBeat? pick(
    List<StoryBeat> pool,
    Set<String> seenIds,
    String lastShownId,
    Random random,
  ) {
    if (pool.isEmpty) return null;

    var candidates = pool.where((b) => !seenIds.contains(b.id)).toList();

    if (candidates.isEmpty) {
      seenIds.clear();
      candidates = pool.where((b) => b.id != lastShownId).toList();
    }

    if (candidates.isEmpty) {
      // Pool of exactly 1: the only beat is also `lastShownId`.
      candidates = pool;
    }

    final chosen = candidates[random.nextInt(candidates.length)];
    seenIds.add(chosen.id);
    return chosen;
  }
}
