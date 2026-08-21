import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/tour/data/tour_repository.dart';

/// `TourRepository` (onboarding-tour v1 §5/§10): a thin, direct delegate
/// over `PreferencesService.homeTourShown`, mirroring `SettingsRepository`.
void main() {
  test('shown delegates to PreferencesService.homeTourShown', () async {
    SharedPreferences.setMockInitialValues({kKeyHomeTourShown: true});
    final service = await PreferencesService.create();
    final repository = TourRepository(service);

    expect(repository.shown, isTrue);
  });

  test('shown defaults to false when the flag has never been written', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();
    final repository = TourRepository(service);

    expect(repository.shown, isFalse);
  });

  test('markShown delegates to PreferencesService.setHomeTourShown(true)', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();
    final repository = TourRepository(service);

    await repository.markShown();

    expect(service.homeTourShown, isTrue);
  });
}
