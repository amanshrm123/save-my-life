import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/story_selector.dart';

/// Pure-Dart coverage for `StorySelector.pick` (architecture v4 §1/§3;
/// remote-story-config-implementation-spec §2.3/§9.6) — synthetic pools
/// only. Pool-count/content assertions against the real bundled asset moved
/// to `story_pool_codec_test.dart`. `StorySelector` now serves icons only
/// (beats go through `StoryCycleSelector`), so these tests exercise it
/// against plain `String` pools, which is representative of its one real
/// production use.
void main() {
  group('StorySelector.pick — uniform random, no off-by-one', () {
    const selector = StorySelector();
    final sixIcons = ['a', 'b', 'c', 'd', 'e', 'f'];
    final fourIcons = ['w', 'x', 'y', 'z'];

    test('never throws a RangeError across many draws, for a small pool', () {
      final random = Random(2);
      for (var i = 0; i < 2000; i++) {
        expect(() => selector.pick(sixIcons, random), returnsNormally);
      }
    });

    test('every entry in a small pool (4 icons) is reachable — no entry is '
        'structurally excluded by an off-by-one in the index math', () {
      final random = Random(43);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final (entry, _) = selector.pick(fourIcons, random);
        seen.add(entry);
      }
      expect(seen.length, fourIcons.length);
    });

    test('a deterministic Random seed picks the exact index it should '
        '(pins the pick() -> Random.nextInt() contract)', () {
      final a = Random(7);
      final b = Random(7);
      final expectedIndex = a.nextInt(sixIcons.length);
      final (picked, index) = selector.pick(sixIcons, b);
      expect(picked, sixIcons[expectedIndex]);
      expect(index, expectedIndex);
    });

    test('pick() with a pool of length 1 always returns that single entry, '
        'with no avoidIndex supplied', () {
      final singlePool = ['only'];
      final random = Random();
      for (var i = 0; i < 20; i++) {
        final (entry, index) = selector.pick(singlePool, random);
        expect(entry, 'only');
        expect(index, 0);
      }
    });

    test(
      'pool of length 1 with avoidIndex: 0 still returns the single '
      'entry (no infinite loop / no out-of-range shift, degrades gracefully)',
      () {
        final singlePool = ['only'];
        final random = Random();
        for (var i = 0; i < 20; i++) {
          final (entry, index) = selector.pick(
            singlePool,
            random,
            avoidIndex: 0,
          );
          expect(entry, 'only');
          expect(index, 0);
        }
      },
    );
  });

  group(
    'StorySelector.pick — avoid-index shift on collision, no off-by-one',
    () {
      const selector = StorySelector();
      final sixIcons = ['a', 'b', 'c', 'd', 'e', 'f'];

      test('never returns avoidIndex across many draws, for a range of seeds '
          'and every possible avoidIndex in a small pool', () {
        for (var seed = 0; seed < 50; seed++) {
          final random = Random(seed);
          for (var avoid = 0; avoid < sixIcons.length; avoid++) {
            final (_, index) = selector.pick(
              sixIcons,
              random,
              avoidIndex: avoid,
            );
            expect(index, isNot(avoid));
          }
        }
      });

      test('avoidIndex: null (first-ever pick) behaves identically to no '
          'exclusion — same index as an unseeded pick would produce', () {
        final a = Random(3);
        final b = Random(3);
        final (_, withNull) = selector.pick(sixIcons, a, avoidIndex: null);
        final expected = b.nextInt(sixIcons.length);
        expect(withNull, expected);
      });

      test(
        'when the raw draw does NOT land on avoidIndex, the index is '
        'returned unshifted (the shift only engages on an actual collision)',
        () {
          final probeRandom = Random(9);
          final rawDraw = probeRandom.nextInt(sixIcons.length);
          final farAvoid = (rawDraw + 3) % sixIcons.length; // guaranteed miss
          if (farAvoid == rawDraw) return; // pool too small to guarantee a miss
          final actualRandom = Random(9);
          final (_, index) = selector.pick(
            sixIcons,
            actualRandom,
            avoidIndex: farAvoid,
          );
          expect(
            index,
            rawDraw,
            reason: 'no collision occurred, so the shift must not engage',
          );
        },
      );

      test('shifted index wraps correctly when the excluded index is the '
          'last slot in the pool (no out-of-range index from the +1 wrap)', () {
        final random = Random(5);
        final probe = Random(5).nextInt(sixIcons.length);
        final (_, index) = selector.pick(sixIcons, random, avoidIndex: probe);
        expect(index, (probe + 1) % sixIcons.length);
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(sixIcons.length));
      });
    },
  );

  group('empty-pool guard (implementation spec §2.3 — defence-in-depth)', () {
    const selector = StorySelector();

    test('pick() on an empty pool throws cleanly rather than a bare '
        'RangeError from nextInt(0) — unreachable in production since '
        'RemoteOutcomeStoryService short-circuits on tier.isEmpty first', () {
      expect(
        () => selector.pick(<String>[], Random()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
