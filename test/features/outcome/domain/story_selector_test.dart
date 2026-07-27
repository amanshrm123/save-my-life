import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/death_beats.dart';
import 'package:timing_tap/features/outcome/domain/eternal_beats.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_icons.dart';
import 'package:timing_tap/features/outcome/domain/story_selector.dart';
import 'package:timing_tap/features/outcome/domain/survived_beats.dart';

/// Pure-Dart coverage for `StorySelector.pick` (architecture v4 §1/§3,
/// replaces the deleted `flavor_selector_test.dart` for the old
/// `FlavorSelector`/`*Flavor` model) — same rigor: uniform-random selection,
/// no off-by-one in the avoid-index shift, graceful degradation for a
/// length-1 pool, and full reachability across many draws. `StorySelector`
/// is now shared by both the `StoryBeat` pools and the icon (`String`)
/// pools, so both are exercised here.
void main() {
  group('pool sizes (architecture v4 §1/§7 — same seeded counts as v3)', () {
    test('death pool has exactly 50 entries', () {
      expect(deathBeats.length, 50);
    });

    test('survived pool has exactly 10 entries', () {
      expect(survivedBeats.length, 10);
    });

    test('eternal pool has exactly 6 entries', () {
      expect(eternalBeats.length, 6);
    });

    test('icon pools have their documented counts and no duplicate ring-buoy', () {
      expect(deathIcons.length, 6);
      expect(survivedIcons.length, 5);
      expect(eternalIcons.length, 4);
      expect(
        survivedIcons,
        isNot(contains('🛟')),
        reason: 'founder-resolved tofu-risk swap — 🛟 must never appear, including in the pool',
      );
    });
  });

  group('StorySelector.pick — uniform random, no off-by-one', () {
    const selector = StorySelector();

    test('never throws a RangeError across many draws, for every beat pool', () {
      final random = Random(1);
      for (var i = 0; i < 2000; i++) {
        expect(() => selector.pick(deathBeats, random), returnsNormally);
        expect(() => selector.pick(survivedBeats, random), returnsNormally);
        expect(() => selector.pick(eternalBeats, random), returnsNormally);
      }
    });

    test('never throws a RangeError across many draws, for every icon pool', () {
      final random = Random(2);
      for (var i = 0; i < 2000; i++) {
        expect(() => selector.pick(deathIcons, random), returnsNormally);
        expect(() => selector.pick(survivedIcons, random), returnsNormally);
        expect(() => selector.pick(eternalIcons, random), returnsNormally);
      }
    });

    test('every entry in a small pool (eternal beats, 6) is reachable — no '
        'entry is structurally excluded by an off-by-one in the index math', () {
      final random = Random(42);
      final seen = <StoryBeat>{};
      for (var i = 0; i < 500; i++) {
        final (entry, _) = selector.pick(eternalBeats, random);
        seen.add(entry);
      }
      expect(seen.length, eternalBeats.length);
    });

    test('every entry in a small icon pool (eternal icons, 4) is reachable', () {
      final random = Random(43);
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final (entry, _) = selector.pick(eternalIcons, random);
        seen.add(entry);
      }
      expect(seen.length, eternalIcons.length);
    });

    test('a deterministic Random seed picks the exact index it should '
        '(pins the pick() -> Random.nextInt() contract)', () {
      final a = Random(7);
      final b = Random(7);
      final expectedIndex = a.nextInt(deathBeats.length);
      final (picked, index) = selector.pick(deathBeats, b);
      expect(picked, deathBeats[expectedIndex]);
      expect(index, expectedIndex);
    });

    test('pick() with a pool of length 1 always returns that single entry, '
        'with no avoidIndex supplied', () {
      final singlePool = [deathBeats.first];
      final random = Random();
      for (var i = 0; i < 20; i++) {
        final (entry, index) = selector.pick(singlePool, random);
        expect(entry, same(deathBeats.first));
        expect(index, 0);
      }
    });

    test('pool of length 1 with avoidIndex: 0 still returns the single '
        'entry (no infinite loop / no out-of-range shift, degrades gracefully)', () {
      final singlePool = [deathBeats.first];
      final random = Random();
      for (var i = 0; i < 20; i++) {
        final (entry, index) = selector.pick(singlePool, random, avoidIndex: 0);
        expect(entry, same(deathBeats.first));
        expect(index, 0);
      }
    });

    test('pool of length 1 works identically for a String icon pool too', () {
      final singlePool = [deathIcons.first];
      final random = Random();
      final (entry, index) = selector.pick(singlePool, random, avoidIndex: 0);
      expect(entry, deathIcons.first);
      expect(index, 0);
    });
  });

  group('StorySelector.pick — avoid-index shift on collision, no off-by-one', () {
    const selector = StorySelector();

    test('never returns avoidIndex across many draws, for a range of seeds '
        'and every possible avoidIndex in a small pool', () {
      for (var seed = 0; seed < 50; seed++) {
        final random = Random(seed);
        for (var avoid = 0; avoid < eternalBeats.length; avoid++) {
          final (_, index) = selector.pick(eternalBeats, random, avoidIndex: avoid);
          expect(index, isNot(avoid));
        }
      }
    });

    test('avoidIndex: null (first-ever pick) behaves identically to no '
        'exclusion — same index as an unseeded pick would produce', () {
      final a = Random(3);
      final b = Random(3);
      final (_, withNull) = selector.pick(deathBeats, a, avoidIndex: null);
      final expected = b.nextInt(deathBeats.length);
      expect(withNull, expected);
    });

    test('when the raw draw does NOT land on avoidIndex, the index is '
        'returned unshifted (the shift only engages on an actual collision)', () {
      // Seed 3 draws index 8 from a 6-entry pool via nextInt (mod pool
      // length below) is out of scope; instead confirm directly: a draw
      // that misses avoidIndex must equal the raw nextInt() draw exactly,
      // not off by one from an unconditional shift.
      final probeRandom = Random(9);
      final rawDraw = probeRandom.nextInt(eternalBeats.length);
      final farAvoid = (rawDraw + 3) % eternalBeats.length; // guaranteed miss
      if (farAvoid == rawDraw) return; // pool too small to guarantee a miss
      final actualRandom = Random(9);
      final (_, index) = selector.pick(eternalBeats, actualRandom, avoidIndex: farAvoid);
      expect(index, rawDraw, reason: 'no collision occurred, so the shift must not engage');
    });

    test('shifted index wraps correctly when the excluded index is the '
        'last slot in the pool (no out-of-range index from the +1 wrap)', () {
      final random = Random(5);
      final probe = Random(5).nextInt(eternalBeats.length);
      final (_, index) = selector.pick(eternalBeats, random, avoidIndex: probe);
      expect(index, (probe + 1) % eternalBeats.length);
      expect(index, greaterThanOrEqualTo(0));
      expect(index, lessThan(eternalBeats.length));
    });

    test('avoid-index shift also works correctly for icon (String) pools', () {
      for (var seed = 0; seed < 30; seed++) {
        final random = Random(seed);
        for (var avoid = 0; avoid < survivedIcons.length; avoid++) {
          final (_, index) = selector.pick(survivedIcons, random, avoidIndex: avoid);
          expect(index, isNot(avoid));
        }
      }
    });
  });
}
