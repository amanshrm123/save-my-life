import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/onboarding/domain/profanity_filter.dart';

void main() {
  group('ProfanityFilter', () {
    test('default seed blocklist rejects a known seed word', () {
      const filter = ProfanityFilter();
      expect(filter.isAllowed('fuck'), isFalse);
    });

    test('default seed blocklist allows an ordinary name', () {
      const filter = ProfanityFilter();
      expect(filter.isAllowed('Aman'), isTrue);
    });

    test('match is case-insensitive', () {
      const filter = ProfanityFilter();
      expect(filter.isAllowed('FuCk'), isFalse);
    });

    test('match is substring-based (blocked word embedded in a longer name)', () {
      const filter = ProfanityFilter();
      expect(filter.isAllowed('xxfuckxx'), isFalse);
    });

    test('a custom injected blocklist replaces the default seed list', () {
      const filter = ProfanityFilter(blocklist: ['banana']);
      expect(filter.isAllowed('banana'), isFalse);
      expect(filter.isAllowed('fuck'), isTrue); // not in the custom list
    });
  });
}
