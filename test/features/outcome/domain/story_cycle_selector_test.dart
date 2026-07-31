import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_cycle_selector.dart';

/// Coverage for `StoryCycleSelector` (remote-story-config-implementation-spec
/// §2.3 / §9.1) — options §8.3's ID-keyed dedup-until-exhausted algorithm.
void main() {
  const selector = StoryCycleSelector();

  List<StoryBeat> poolOf(int n, {String prefix = 'beat'}) => List.generate(
    n,
    (i) => StoryBeat(
      id: '${prefix}_$i',
      headline: 'Headline $i',
      named: '{name} $i',
      anonymous: 'Anon $i',
    ),
  );

  test('fresh cycle: empty seenIds/lastShownId picks from the full pool; '
      'seenIds afterwards is exactly {chosen.id}', () {
    final pool = poolOf(6);
    final seenIds = <String>{};
    final chosen = selector.pick(pool, seenIds, '', Random(1));

    expect(chosen, isNotNull);
    expect(pool.map((b) => b.id), contains(chosen!.id));
    expect(seenIds, {chosen.id});
  });

  test('mid-cycle: the chosen ID is never in seenIds; over a run of the '
      'remaining draws, every remaining ID appears exactly once', () {
    final pool = poolOf(6);
    // 2 of 6 already seen.
    final seenIds = {'beat_0', 'beat_1'};
    final random = Random(42);

    final drawn = <String>[];
    for (var i = 0; i < 4; i++) {
      final chosen = selector.pick(pool, seenIds, '', random);
      expect(chosen, isNotNull);
      expect(
        seenIds.contains(chosen!.id) && drawn.contains(chosen.id),
        isFalse,
      );
      drawn.add(chosen.id);
    }

    expect(drawn.toSet(), {'beat_2', 'beat_3', 'beat_4', 'beat_5'});
  });

  test('exhaustion + reset: drawing pool.length times exhausts the pool '
      '(all distinct, seenIds.length == pool.length); the next draw clears '
      'and seenIds.length == 1 afterwards', () {
    final pool = poolOf(6);
    final seenIds = <String>{};
    final random = Random(7);

    final drawn = <String>[];
    for (var i = 0; i < 6; i++) {
      final chosen = selector.pick(pool, seenIds, '', random);
      drawn.add(chosen!.id);
    }
    expect(drawn.toSet().length, 6);
    expect(seenIds.length, 6);

    final lastShown = drawn.last;
    final seventh = selector.pick(pool, seenIds, lastShown, random);
    expect(seventh, isNotNull);
    expect(seenIds.length, 1);
    expect(seenIds, {seventh!.id});
  });

  test('boundary no-repeat: the 7th draw is never the 6th draw\'s beat, '
      'across many seeds', () {
    for (var seed = 0; seed < 50; seed++) {
      final pool = poolOf(6);
      final seenIds = <String>{};
      final random = Random(seed);
      String lastShown = '';
      String? sixth;
      for (var i = 0; i < 6; i++) {
        final chosen = selector.pick(pool, seenIds, lastShown, random)!;
        lastShown = chosen.id;
        sixth = chosen.id;
      }
      final seventh = selector.pick(pool, seenIds, lastShown, random)!;
      expect(
        seventh.id,
        isNot(sixth),
        reason: 'seed $seed: 7th draw repeated the 6th draw\'s beat',
      );
    }
  });

  test('boundary re-eligibility: the boundary-excluded beat is NOT seeded '
      'into the fresh seenIds and DOES reappear later in the new cycle', () {
    final pool = poolOf(6);
    final seenIds = <String>{};
    final random = Random(3);
    String lastShown = '';
    for (var i = 0; i < 6; i++) {
      lastShown = selector.pick(pool, seenIds, lastShown, random)!.id;
    }
    final boundaryId = lastShown;

    // First draw of the new cycle: excluded, but not seeded into seenIds.
    final first = selector.pick(pool, seenIds, lastShown, random)!;
    expect(first.id, isNot(boundaryId));
    expect(seenIds.contains(boundaryId), isFalse);

    // Draw through the rest of the new cycle: the boundary beat must
    // reappear before exhaustion (it's eligible for the remaining 5 draws).
    final drawnInNewCycle = <String>{first.id};
    var reappeared = false;
    for (var i = 0; i < 5; i++) {
      final chosen = selector.pick(pool, seenIds, first.id, random)!;
      drawnInNewCycle.add(chosen.id);
      if (chosen.id == boundaryId) reappeared = true;
    }
    expect(
      reappeared,
      isTrue,
      reason: 'boundary beat never reappeared in the new cycle',
    );
  });

  test(
    'pool of exactly 1: returns the single beat repeatedly, never throws',
    () {
      final pool = poolOf(1);
      final seenIds = <String>{};
      final random = Random(5);
      String lastShown = '';
      for (var i = 0; i < 10; i++) {
        final chosen = selector.pick(pool, seenIds, lastShown, random);
        expect(chosen, isNotNull);
        expect(chosen!.id, 'beat_0');
        lastShown = chosen.id;
      }
    },
  );

  test('empty pool: returns null, never throws', () {
    final seenIds = <String>{};
    expect(
      () => selector.pick(const [], seenIds, '', Random(1)),
      returnsNormally,
    );
    expect(selector.pick(const [], seenIds, '', Random(1)), isNull);
  });

  test('story added mid-cycle: with 5/6 seen, adding a new beat means the '
      'next pick is the new beat or the one unseen one, never a seen one', () {
    final pool = poolOf(6);
    final seenIds = {'beat_0', 'beat_1', 'beat_2', 'beat_3', 'beat_4'};
    final grownPool = [
      ...pool,
      StoryBeat(id: 'beat_new', headline: 'H', named: '{name}', anonymous: 'A'),
    ];

    final chosen = selector.pick(grownPool, seenIds, '', Random(11))!;
    expect(chosen.id, anyOf('beat_5', 'beat_new'));
  });

  test('story removed mid-cycle: seenIds referencing a removed beat never '
      'deadlocks the cycle — drawing 2x pool length completes without '
      'hanging or throwing', () {
    final pool = poolOf(6);
    // Simulate a beat that used to exist but was removed from the live pool.
    final seenIds = {'beat_0', 'beat_1', 'removed_beat'};
    final random = Random(13);
    String lastShown = '';

    for (var i = 0; i < 12; i++) {
      final chosen = selector.pick(pool, seenIds, lastShown, random);
      expect(chosen, isNotNull);
      lastShown = chosen!.id;
    }
  });
}
