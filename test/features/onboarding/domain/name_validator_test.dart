import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/onboarding/domain/name_validator.dart';
import 'package:timing_tap/features/onboarding/domain/profanity_filter.dart';

void main() {
  group('NameValidator - emoji regression coverage (bug #1)', () {
    const validator = NameValidator();

    test('accepts a flag emoji (regional-indicator pair) on its own', () {
      // Regression: a pair of regional-indicator codepoints (e.g. the India
      // flag) was previously rejected as illegalChars because the old glue
      // check didn't treat regional indicators as emoji-bearing.
      final result = validator.validate('\u{1F1EE}\u{1F1F3}'); // India flag
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('accepts a flag emoji combined with a plain name', () {
      final result = validator.validate('Aman \u{1F1EE}\u{1F1F3}');
      expect(result.isValid, isTrue);
    });

    test('accepts a ZWJ composite/family emoji', () {
      // family: man + ZWJ + woman + ZWJ + girl + ZWJ + boy
      const family =
          '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}';
      final result = validator.validate(family);
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('accepts a skin-tone-modified emoji', () {
      // thumbs up + medium skin tone modifier
      const thumbsUp = '\u{1F44D}\u{1F3FD}';
      final result = validator.validate(thumbsUp);
      expect(result.isValid, isTrue);
      expect(result.reason, isNull);
    });

    test('accepts plain accented-letter (composed) names', () {
      const composed = 'José'; // 'José', composed form
      final result = validator.validate(composed);
      expect(result.isValid, isTrue);
    });

    test('accepts plain accented-letter names built from combining marks', () {
      // 'e' followed by a combining acute accent (U+0301), decomposed form.
      const decomposed = 'Jose\u0301'; // Jose + combining acute
      final result = validator.validate(decomposed);
      expect(result.isValid, isTrue);
    });

    test(
      'a flag emoji is a single grapheme cluster, not decomposed into two',
      () {
        const flag = '\u{1F1EE}\u{1F1F3}';
        expect(flag.characters.length, 1);
      },
    );

    test(
      '12-cluster cap counts a composite ZWJ emoji as ONE cluster each, '
      'not one per UTF-16 code unit',
      () {
        const family =
            '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}';
        // 1 grapheme cluster, but 7 codepoints / more UTF-16 code units.
        final twelveFamilies = family * 12;
        expect(twelveFamilies.characters.length, 12);

        final result = validator.validate(twelveFamilies);
        expect(result.isValid, isTrue, reason: result.reason?.toString());
      },
    );

    test(
      '13 composite emoji clusters is rejected as tooLong (not silently '
      'truncated / not accepted because raw code-unit length looks small)',
      () {
        const family =
            '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}';
        final thirteenFamilies = family * 13;
        expect(thirteenFamilies.characters.length, 13);

        final result = validator.validate(thirteenFamilies);
        expect(result.isValid, isFalse);
        expect(result.reason, NameRejectReason.tooLong);
      },
    );

    test(
      'mixing letters and a flag emoji up to exactly 12 clusters is accepted',
      () {
        // 11 letters + 1 flag emoji = 12 clusters.
        final name = '${'A' * 11}\u{1F1EE}\u{1F1F3}';
        expect(name.characters.length, 12);
        final result = validator.validate(name);
        expect(result.isValid, isTrue);
      },
    );
  });

  group('NameValidator - ASCII length boundary', () {
    const validator = NameValidator();

    test('12 ASCII characters is accepted (at the cap)', () {
      final name = 'A' * 12;
      final result = validator.validate(name);
      expect(result.isValid, isTrue);
      expect(result.sanitized, name);
    });

    test('13 ASCII characters is rejected as tooLong (one past the cap)', () {
      final name = 'A' * 13;
      final result = validator.validate(name);
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.tooLong);
    });

    test('a single character is rejected as tooShort (below the floor)', () {
      final result = validator.validate('A');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.tooShort);
    });

    test('exactly 2 characters is accepted (at the floor)', () {
      final result = validator.validate('Jo');
      expect(result.isValid, isTrue);
      expect(result.sanitized, 'Jo');
    });

    test(
      'a single composite ZWJ emoji cluster is still accepted despite being '
      'only 1 cluster — the tooShort floor exempts emoji, matching the '
      'emoji-regression tests above that already protect this exact case',
      () {
        const family =
            '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}';
        expect(family.characters.length, 1);
        final result = validator.validate(family);
        expect(result.isValid, isTrue, reason: result.reason?.toString());
      },
    );
  });

  group('NameValidator - rule order & each NameRejectReason reachable', () {
    const validator = NameValidator();

    test('empty (post-trim) string -> empty reason', () {
      final result = validator.validate('   ');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.empty);
      expect(result.sanitized, '');
    });

    test('truly empty string -> empty reason', () {
      final result = validator.validate('');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.empty);
    });

    test('13+ char string -> tooLong reason', () {
      final result = validator.validate('ThisNameIsWayTooLong');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.tooLong);
    });

    test('a single character -> tooShort reason', () {
      final result = validator.validate('A');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.tooShort);
    });

    test(
      'the tooShort floor only catches a single plain letter/digit cluster — '
      'a single symbol like "@" falls through to the character-set check '
      'and is rejected as illegalChars instead, not tooShort',
      () {
        final result = validator.validate('@');
        expect(result.isValid, isFalse);
        expect(result.reason, NameRejectReason.illegalChars);
      },
    );

    test('disallowed character (e.g. "@") -> illegalChars reason', () {
      final result = validator.validate('Aman@');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.illegalChars);
    });

    test('a blocklisted word -> disallowedWord reason', () {
      final result = validator.validate('fuck');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.disallowedWord);
    });

    test(
      'length check runs before character-set check: a too-long name with '
      'illegal characters is rejected as tooLong, not illegalChars',
      () {
        final name = '${'A' * 12}@'; // 13 chars, last one illegal
        final result = validator.validate(name);
        expect(result.isValid, isFalse);
        expect(result.reason, NameRejectReason.tooLong);
      },
    );

    test(
      'character-set check runs before the profanity check: a name that is '
      'both illegal-charset AND contains a blocked word is rejected as '
      'illegalChars, not disallowedWord',
      () {
        // "fuck!!!!!!!!" = 12 chars, contains blocked word "fuck" AND
        // illegal '!' characters.
        final name = 'fuck${'!' * 8}';
        expect(name.length, 12);
        final result = validator.validate(name);
        expect(result.isValid, isFalse);
        expect(result.reason, NameRejectReason.illegalChars);
      },
    );
  });

  group('NameValidator - sanitize behavior', () {
    const validator = NameValidator();

    test('trims leading/trailing whitespace', () {
      final result = validator.validate('  Aman  ');
      expect(result.isValid, isTrue);
      expect(result.sanitized, 'Aman');
    });

    test('collapses internal runs of whitespace to a single space', () {
      final result = validator.validate('John    Doe');
      expect(result.isValid, isTrue);
      expect(result.sanitized, 'John Doe');
    });
  });

  group('NameValidator - allowed punctuation and normal names', () {
    const validator = NameValidator();

    test("allows hyphen, apostrophe, underscore and digits", () {
      // 11 characters, so it also stays within the 12-cluster cap.
      final result = validator.validate("Jo-Ann_O'12");
      expect(result.isValid, isTrue, reason: result.reason?.toString());
    });

    test('rejects a name containing a raw control character', () {
      final result = validator.validate('Aman\u0007');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.illegalChars);
    });

    test('rejects a name containing a zero-width space (formatting char)', () {
      final result = validator.validate('Aman\u200B');
      expect(result.isValid, isFalse);
      expect(result.reason, NameRejectReason.illegalChars);
    });
  });

  group('NameValidator - injected ProfanityFilter', () {
    test('respects a custom blocklist passed via the injected filter', () {
      const validator = NameValidator(
        profanityFilter: ProfanityFilter(blocklist: ['banana']),
      );
      final blocked = validator.validate('banana');
      expect(blocked.isValid, isFalse);
      expect(blocked.reason, NameRejectReason.disallowedWord);

      // The default seed word is not blocked by this custom filter.
      final notBlocked = validator.validate('fuck');
      expect(notBlocked.isValid, isTrue);
    });
  });
}
