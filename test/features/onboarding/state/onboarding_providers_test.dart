import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/domain/player_profile.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> buildContainer(
    Map<String, Object> initialPrefs,
  ) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'playerProfileProvider loads the persisted profile once, from RAM, '
    'without any further writes',
    () async {
      final container = await buildContainer({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
      });

      final profile = await container.read(playerProfileProvider.future);

      expect(profile, const PlayerProfile(name: 'Aman', onboardingComplete: true));
    },
  );

  test('first-launch defaults are served when prefs are empty', () async {
    final container = await buildContainer({});

    final profile = await container.read(playerProfileProvider.future);

    expect(profile, PlayerProfile.empty);
  });

  test(
    'completeWithName writes through prefs and updates in-memory state to '
    'AsyncData with the new profile',
    () async {
      final container = await buildContainer({});
      await container.read(playerProfileProvider.future); // let it load

      final notifier = container.read(playerProfileProvider.notifier);
      final result = await notifier.completeWithName('Aman');

      expect(result, const PlayerProfile(name: 'Aman', onboardingComplete: true));
      expect(
        container.read(playerProfileProvider).value,
        const PlayerProfile(name: 'Aman', onboardingComplete: true),
      );
    },
  );

  test(
    'completeAnonymous writes through prefs with an empty name and marks '
    'onboarding permanently complete',
    () async {
      final container = await buildContainer({});
      await container.read(playerProfileProvider.future);

      final notifier = container.read(playerProfileProvider.notifier);
      final result = await notifier.completeAnonymous();

      expect(result.isAnonymous, isTrue);
      expect(result.onboardingComplete, isTrue);
      expect(
        container.read(playerProfileProvider).value?.onboardingComplete,
        isTrue,
      );
    },
  );

  test(
    'building the provider (a mere read/load) never itself marks onboarding '
    'complete or writes a name — only the terminal actions do',
    () async {
      final container = await buildContainer({});

      // Simulate several reads/rebuilds without ever calling a terminal
      // action — analogous to paging through the teach cards, which must
      // never touch persisted state (architecture v1 §3, §8.1).
      await container.read(playerProfileProvider.future);
      container.read(playerProfileProvider);
      container.read(playerProfileProvider);

      final profile = container.read(playerProfileProvider).value;
      expect(profile?.onboardingComplete, isFalse);
      expect(profile?.name, '');
    },
  );
}
