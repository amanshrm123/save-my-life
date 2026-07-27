import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/data/player_profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesService> buildService(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    return PreferencesService.create();
  }

  group('PlayerProfileRepository.load', () {
    test('returns defaults when no keys are present (first launch)', () async {
      final service = await buildService({});
      final repo = PlayerProfileRepository(service);

      final profile = await repo.load();

      expect(profile.name, '');
      expect(profile.onboardingComplete, isFalse);
    });

    test('reflects previously-persisted values', () async {
      final service = await buildService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
      });
      final repo = PlayerProfileRepository(service);

      final profile = await repo.load();

      expect(profile.name, 'Aman');
      expect(profile.onboardingComplete, isTrue);
    });
  });

  group('PlayerProfileRepository.completeWithName', () {
    test('persists the name, sets onboarding_complete=true, writes schema '
        'version, and returns the resulting profile', () async {
      final service = await buildService({});
      final repo = PlayerProfileRepository(service);

      final profile = await repo.completeWithName('Aman');

      expect(profile.name, 'Aman');
      expect(profile.onboardingComplete, isTrue);

      // Verify durability: re-reading via a fresh repository (simulating a
      // relaunch) picks up what was actually written to prefs.
      final reloaded = await PlayerProfileRepository(service).load();
      expect(reloaded.name, 'Aman');
      expect(reloaded.onboardingComplete, isTrue);
      expect(service.schemaVersion, kPrefsSchemaVersion);
    });
  });

  group('PlayerProfileRepository.completeAnonymous', () {
    test(
      'persists an empty name, sets onboarding_complete=true (skip = '
      'anonymous but permanently done, per architecture v1 §4)',
      () async {
        final service = await buildService({});
        final repo = PlayerProfileRepository(service);

        final profile = await repo.completeAnonymous();

        expect(profile.name, '');
        expect(profile.onboardingComplete, isTrue);
        expect(profile.isAnonymous, isTrue);

        final reloaded = await PlayerProfileRepository(service).load();
        expect(reloaded.name, '');
        expect(reloaded.onboardingComplete, isTrue);
      },
    );

    test('clears a previously-set name when skipping after typing one', () async {
      final service = await buildService({kKeyPlayerName: 'Aman'});
      final repo = PlayerProfileRepository(service);

      final profile = await repo.completeAnonymous();

      expect(profile.name, '');
      expect(service.playerName, '');
    });
  });
}
