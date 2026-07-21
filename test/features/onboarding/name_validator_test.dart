// Unit tests for `NameValidator` (lib/features/onboarding/name_validator.dart)
// — docs/design/onboarding-flow-v1.md §5.5/§5.6.
//
// Length behavior is deliberately not this class's job (enforced instead by
// `TextField.maxLength` at the input level, §5.5) so it isn't tested here —
// these tests exercise only the profanity-match path, constructing
// `NameValidator` directly from an explicit word list rather than going
// through `NameValidator.load()`'s asset-bundle read, keeping this a pure
// logic test with no Flutter binding/asset dependency.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/onboarding/name_validator.dart';

/// Minimal fake `AssetBundle` so `NameValidator.load()`'s parsing can be
/// exercised without touching the real bundled `assets/profanity.txt`.
class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._contents);

  final String _contents;

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError('only loadString is used by NameValidator.load');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return _contents;
  }
}

void main() {
  group('NameValidator.containsProfanity', () {
    late NameValidator validator;

    setUp(() {
      validator = NameValidator(['damn', 'heck']);
    });

    test('returns false for a clean name', () {
      expect(validator.containsProfanity('Aman'), isFalse);
    });

    test('returns true for an exact banned word (case-insensitive)', () {
      expect(validator.containsProfanity('damn'), isTrue);
      expect(validator.containsProfanity('DAMN'), isTrue);
      expect(validator.containsProfanity('DaMn'), isTrue);
    });

    test('matches a banned word as one token among several', () {
      expect(validator.containsProfanity('oh damn really'), isTrue);
    });

    test('does not false-positive on a banned word embedded inside a '
        'longer, otherwise-clean word (whole-word match only)', () {
      // "heck" is banned; "hecklers" contains it as a substring but is a
      // different whole word and must not be flagged.
      expect(validator.containsProfanity('hecklers'), isFalse);
    });

    test('empty string is not flagged', () {
      expect(validator.containsProfanity(''), isFalse);
    });

    test('whitespace-only string is not flagged', () {
      expect(validator.containsProfanity('   '), isFalse);
    });

    test('punctuation-separated banned word is still matched', () {
      expect(validator.containsProfanity('damn!'), isTrue);
      expect(validator.containsProfanity('damn-it'), isTrue);
    });

    test('an empty banned-word list never flags anything', () {
      final NameValidator empty = NameValidator(const []);
      expect(empty.containsProfanity('damn'), isFalse);
    });
  });

  group('NameValidator.load (asset parsing)', () {
    test('skips blank lines and #-comment lines from the bundled word list',
        () async {
      const String raw = '''
# comment line, ignored
damn

heck
''';
      final NameValidator validator =
          await NameValidator.load(bundle: _FakeAssetBundle(raw));

      expect(validator.containsProfanity('damn'), isTrue);
      expect(validator.containsProfanity('heck'), isTrue);
      expect(validator.containsProfanity('#'), isFalse);
    });

    test('loads the real bundled assets/profanity.txt without throwing',
        () async {
      // Sanity check against the actual shipped word list (not just a
      // fake) — this is the exact asset path production code reads. Needs
      // a real Flutter binding (unlike the pure-logic tests above) since
      // it goes through the real `rootBundle`/platform asset channel.
      TestWidgetsFlutterBinding.ensureInitialized();
      final NameValidator validator = await NameValidator.load();
      expect(validator.containsProfanity('shit'), isTrue);
      expect(validator.containsProfanity('Aman'), isFalse);
    });
  });
}
