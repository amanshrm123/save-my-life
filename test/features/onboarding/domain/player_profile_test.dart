import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/onboarding/domain/player_profile.dart';

void main() {
  group('PlayerProfile', () {
    test('empty constant is anonymous and onboarding-incomplete', () {
      expect(PlayerProfile.empty.name, '');
      expect(PlayerProfile.empty.onboardingComplete, isFalse);
      expect(PlayerProfile.empty.isAnonymous, isTrue);
    });

    test('isAnonymous is true iff name is empty', () {
      const named = PlayerProfile(name: 'Aman', onboardingComplete: true);
      const anonymous = PlayerProfile(name: '', onboardingComplete: true);
      expect(named.isAnonymous, isFalse);
      expect(anonymous.isAnonymous, isTrue);
    });

    test('copyWith overrides only the given fields, leaving others intact', () {
      const original = PlayerProfile(name: 'Aman', onboardingComplete: false);

      final withNewName = original.copyWith(name: 'Neha');
      expect(withNewName.name, 'Neha');
      expect(withNewName.onboardingComplete, false);

      final withComplete = original.copyWith(onboardingComplete: true);
      expect(withComplete.name, 'Aman');
      expect(withComplete.onboardingComplete, true);
    });

    test('copyWith with no arguments returns an equivalent profile', () {
      const original = PlayerProfile(name: 'Aman', onboardingComplete: true);
      final copy = original.copyWith();
      expect(copy, original);
    });

    test('copyWith does not mutate the original (immutability)', () {
      const original = PlayerProfile(name: 'Aman', onboardingComplete: false);
      original.copyWith(name: 'Neha', onboardingComplete: true);
      expect(original.name, 'Aman');
      expect(original.onboardingComplete, false);
    });

    test('== and hashCode are value-based', () {
      const a = PlayerProfile(name: 'Aman', onboardingComplete: true);
      const b = PlayerProfile(name: 'Aman', onboardingComplete: true);
      const c = PlayerProfile(name: 'Neha', onboardingComplete: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
