import 'dart:math';

import 'flavor.dart';

/// Pure (no Flutter) content-pool selection (architecture v3 §3, revised).
/// Selection is uniform-random from the seeded pool, with one refinement:
/// the immediately-previous pick (if any, tracked by the caller and passed
/// as `avoidIndex`) is excluded, so a single session can't show the exact
/// same death/survived/eternal line twice in a row. This is deliberately
/// lightweight — no persisted history, no full non-repeat-until-exhausted
/// guarantee — just closing the most jarring case a player actually
/// notices. Full dedupe/discovery-tracking arrives with the collection
/// gallery (out of scope, architecture §1 item 7).
class FlavorSelector {
  const FlavorSelector();

  /// Uniform-random pick from `pool` using the supplied `random` (injectable
  /// for deterministic tests; callers pass a real `Random()` in production).
  /// Returns the entry plus its index so the caller can pass that index back
  /// in as `avoidIndex` on the next pick from the same pool. If the random
  /// draw lands on `avoidIndex`, it's shifted to the next slot (wrapping)
  /// rather than re-rolled, so this is O(1) and never loops.
  (T entry, int index) pick<T>(List<T> pool, Random random, {int? avoidIndex}) {
    var index = random.nextInt(pool.length);
    if (pool.length > 1 && index == avoidIndex) {
      index = (index + 1) % pool.length;
    }
    return (pool[index], index);
  }

  /// Renders `entry` for `name` — the anonymous fallback when `name` is
  /// empty (architecture v3 §3, design v1 §3.4's "not a fourth content
  /// pool" resolution, applied generically to all three tiers), otherwise
  /// the named template with its literal `{name}` placeholder substituted.
  String render(NamedFlavor entry, String name) {
    if (name.isEmpty) return entry.anonymous;
    return entry.named.replaceAll('{name}', name);
  }
}
