import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/avatar/domain/avatar_catalog.dart';
import 'package:timing_tap/features/avatar/domain/avatar_spec.dart';

void main() {
  group('kAvatars', () {
    test('has exactly 12 entries', () {
      expect(kAvatars.length, 12);
    });

    test('id ascends 0..11 and matches its own list index', () {
      for (var i = 0; i < kAvatars.length; i++) {
        expect(kAvatars[i].id, i);
      }
    });

    test('id == gender.index * 6 + variant for every entry (§4.1 id math)', () {
      for (final spec in kAvatars) {
        expect(spec.id, spec.gender.index * 6 + spec.variant);
      }
    });

    test('male entries are ids 0-5, female entries are ids 6-11', () {
      final male = kAvatars.where((s) => s.gender == AvatarGender.male).toList();
      final female = kAvatars.where((s) => s.gender == AvatarGender.female).toList();
      expect(male.map((s) => s.id).toList(), [0, 1, 2, 3, 4, 5]);
      expect(female.map((s) => s.id).toList(), [6, 7, 8, 9, 10, 11]);
    });

    test('every AvatarHair value is used exactly once across the catalog', () {
      final hairs = kAvatars.map((s) => s.hair).toSet();
      expect(hairs.length, AvatarHair.values.length);
      expect(hairs, AvatarHair.values.toSet());
    });

    test('variant cycles 0-5 within each gender', () {
      final maleVariants = kAvatars
          .where((s) => s.gender == AvatarGender.male)
          .map((s) => s.variant)
          .toList();
      final femaleVariants = kAvatars
          .where((s) => s.gender == AvatarGender.female)
          .map((s) => s.variant)
          .toList();
      expect(maleVariants, [0, 1, 2, 3, 4, 5]);
      expect(femaleVariants, [0, 1, 2, 3, 4, 5]);
    });
  });

  group('AvatarCatalog.byId', () {
    test('returns the matching entry for every valid id 0-11', () {
      for (var id = 0; id < 12; id++) {
        expect(AvatarCatalog.byId(id).id, id);
      }
    });

    test('falls back to id 0 for the never-picked sentinel (-1)', () {
      expect(AvatarCatalog.byId(-1), AvatarCatalog.fallback);
      expect(AvatarCatalog.byId(-1).id, 0);
    });

    test('falls back to id 0 for any out-of-range id, never throws', () {
      expect(AvatarCatalog.byId(12), AvatarCatalog.fallback);
      expect(AvatarCatalog.byId(999), AvatarCatalog.fallback);
      expect(AvatarCatalog.byId(-100), AvatarCatalog.fallback);
    });
  });

  group('AvatarCatalog.fallback', () {
    test('is id 0: sweptBack / male', () {
      expect(AvatarCatalog.fallback.id, 0);
      expect(AvatarCatalog.fallback.hair, AvatarHair.sweptBack);
      expect(AvatarCatalog.fallback.gender, AvatarGender.male);
    });
  });

  group('AvatarCatalog.forGender', () {
    test('male returns exactly ids 0-5, in variant order', () {
      final specs = AvatarCatalog.forGender(AvatarGender.male);
      expect(specs.map((s) => s.id).toList(), [0, 1, 2, 3, 4, 5]);
    });

    test('female returns exactly ids 6-11, in variant order', () {
      final specs = AvatarCatalog.forGender(AvatarGender.female);
      expect(specs.map((s) => s.id).toList(), [6, 7, 8, 9, 10, 11]);
    });

    test('each gender list has exactly 6 entries', () {
      expect(AvatarCatalog.forGender(AvatarGender.male).length, 6);
      expect(AvatarCatalog.forGender(AvatarGender.female).length, 6);
    });
  });
}
