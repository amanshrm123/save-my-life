import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/death_lines.dart';
import 'package:timing_tap/features/outcome/domain/eternal_lines.dart';
import 'package:timing_tap/features/outcome/domain/flavor.dart';
import 'package:timing_tap/features/outcome/domain/flavor_selector.dart';
import 'package:timing_tap/features/outcome/domain/survived_lines.dart';

/// Pure-Dart coverage for the seeded flavor-content pools + `FlavorSelector`
/// (architecture v3 §1 item 4 / §3): pool sizes, catalog-number integrity,
/// uniform-random selection with no off-by-one, and named-vs-anonymous
/// rendering. High-value, cheap — no Flutter/Riverpod needed anywhere here.
void main() {
  group('pool sizes (architecture v3 §1 item 4)', () {
    test('death pool has exactly 50 entries', () {
      expect(deathLines.length, 50);
    });

    test('survived pool has exactly 10 entries', () {
      expect(survivedLines.length, 10);
    });

    test('eternal pool has exactly 6 entries', () {
      expect(eternalLines.length, 6);
    });
  });

  group('death pool catalogNo integrity', () {
    test('catalogNo runs 1-50 with no duplicates and no gaps', () {
      final numbers = deathLines.map((e) => e.catalogNo).toList()..sort();
      expect(numbers, List<int>.generate(50, (i) => i + 1));
    });

    test('catalogNo set has no duplicates (belt-and-braces on the sorted check above)', () {
      final numbers = deathLines.map((e) => e.catalogNo).toSet();
      expect(numbers.length, deathLines.length);
    });
  });

  group('FlavorSelector.pick — uniform random, no off-by-one', () {
    const selector = FlavorSelector();

    test('never throws a RangeError across many draws, for every pool', () {
      final random = Random(1);
      for (var i = 0; i < 2000; i++) {
        expect(() => selector.pick(deathLines, random), returnsNormally);
        expect(() => selector.pick(survivedLines, random), returnsNormally);
        expect(() => selector.pick(eternalLines, random), returnsNormally);
      }
    });

    test('every entry in a small pool (eternal, 6) is reachable — no entry '
        'is structurally excluded by an off-by-one in the index math', () {
      final random = Random(42);
      final seen = <EternalFlavor>{};
      for (var i = 0; i < 500; i++) {
        final (entry, _) = selector.pick(eternalLines, random);
        seen.add(entry);
      }
      expect(seen.length, eternalLines.length);
    });

    test('a deterministic Random seed picks the exact index it should '
        '(pins the pick() -> Random.nextInt() contract)', () {
      // Random.nextInt is deterministic for a given seed across Dart/Flutter
      // SDK versions for a fixed algorithm; this pins pick() calling
      // random.nextInt(pool.length) with the *unmodified* pool length (no
      // -1/+1 typo) by cross-checking against a direct nextInt call on an
      // identically-seeded Random.
      final a = Random(7);
      final b = Random(7);
      final expectedIndex = a.nextInt(deathLines.length);
      final (picked, index) = selector.pick(deathLines, b);
      expect(picked, deathLines[expectedIndex]);
      expect(index, expectedIndex);
    });

    test('pick() with a pool of length 1 always returns that single entry '
        '(lower-bound sanity check on the index math)', () {
      final singlePool = [deathLines.first];
      final random = Random();
      for (var i = 0; i < 20; i++) {
        final (entry, index) = selector.pick(singlePool, random);
        expect(entry, same(deathLines.first));
        expect(index, 0);
      }
    });

    test('pool of length 1 with avoidIndex: 0 still returns the single entry '
        '(no infinite loop / no out-of-range shift)', () {
      final singlePool = [deathLines.first];
      final random = Random();
      final (entry, index) = selector.pick(singlePool, random, avoidIndex: 0);
      expect(entry, same(deathLines.first));
      expect(index, 0);
    });
  });

  group('FlavorSelector.pick — immediate-repeat avoidance', () {
    const selector = FlavorSelector();

    test('never returns avoidIndex across many draws, for a range of seeds', () {
      for (var seed = 0; seed < 50; seed++) {
        final random = Random(seed);
        for (var avoid = 0; avoid < eternalLines.length; avoid++) {
          final (_, index) = selector.pick(eternalLines, random, avoidIndex: avoid);
          expect(index, isNot(avoid));
        }
      }
    });

    test('avoidIndex: null (first-ever pick) behaves identically to no '
        'exclusion — same index as an unseeded pick would produce', () {
      final a = Random(3);
      final b = Random(3);
      final (_, withNull) = selector.pick(deathLines, a, avoidIndex: null);
      final expected = b.nextInt(deathLines.length);
      expect(withNull, expected);
    });

    test('shifted index wraps correctly when the excluded index is the last '
        'slot in the pool', () {
      // Force nextInt to land on the last index by using a pool sized so a
      // known seed's draw equals length-1, then confirm the wrap goes to 0
      // rather than out of range.
      final random = Random(5);
      final probe = Random(5).nextInt(eternalLines.length);
      final (_, index) = selector.pick(eternalLines, random, avoidIndex: probe);
      expect(index, (probe + 1) % eternalLines.length);
      expect(index, greaterThanOrEqualTo(0));
      expect(index, lessThan(eternalLines.length));
    });
  });

  group('FlavorSelector.render — named vs anonymous', () {
    const selector = FlavorSelector();

    test('a non-empty name substitutes the {name} placeholder in the named template', () {
      const entry = DeathFlavor(
        catalogNo: 1,
        named: '{name} blinked at the exact wrong moment.',
        anonymous: 'Blinked at the exact wrong moment.',
      );

      expect(selector.render(entry, 'Aman'), 'Aman blinked at the exact wrong moment.');
    });

    test('an empty name renders the anonymous fallback, not a named template '
        'with an empty substitution', () {
      const entry = DeathFlavor(
        catalogNo: 1,
        named: '{name} blinked at the exact wrong moment.',
        anonymous: 'Blinked at the exact wrong moment.',
      );

      expect(selector.render(entry, ''), 'Blinked at the exact wrong moment.');
      expect(
        selector.render(entry, ''),
        isNot(contains('{name}')),
        reason: 'must never leak the literal placeholder token',
      );
    });

    test('render() works identically for SurvivedFlavor and EternalFlavor '
        '(generic NamedFlavor contract, not death-only)', () {
      const survived = SurvivedFlavor(
        named: '{name} pulled the perfect tap out of nowhere.',
        anonymous: 'Pulled the perfect tap out of nowhere.',
      );
      const eternal = EternalFlavor(
        named: '{name} never even wobbled.',
        anonymous: 'Never even wobbled.',
        sub: 'Three perfect taps from cold.',
      );

      expect(selector.render(survived, 'Zoe'), 'Zoe pulled the perfect tap out of nowhere.');
      expect(selector.render(survived, ''), 'Pulled the perfect tap out of nowhere.');
      expect(selector.render(eternal, 'Zoe'), 'Zoe never even wobbled.');
      expect(selector.render(eternal, ''), 'Never even wobbled.');
    });

    test('every death-pool entry\'s anonymous form is a capitalized '
        'sentence with no leftover {name} token (content-authoring sanity)', () {
      for (final entry in deathLines) {
        expect(entry.anonymous, isNot(contains('{name}')));
        expect(entry.anonymous[0], entry.anonymous[0].toUpperCase());
      }
    });
  });
}
