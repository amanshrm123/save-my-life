import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';

/// `PreferencesService.homeTourShown` (onboarding-tour v1 §2.4/§10): the
/// same default-false / round-trip / swallow-on-failure shape as every
/// neighbouring getter/setter in this file.
void main() {
  test('homeTourShown defaults to false when the key has never been written', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();

    expect(service.homeTourShown, isFalse);
  });

  test('setHomeTourShown round-trips true, then false', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();

    await service.setHomeTourShown(true);
    expect(service.homeTourShown, isTrue);

    await service.setHomeTourShown(false);
    expect(service.homeTourShown, isFalse);
  });

  test(
    'homeTourShown returns the documented default rather than throwing when '
    'the backing store holds a value of the wrong type (a corrupt/failed '
    'read)',
    () async {
      // A real `getBool` cast failure, not a mock: seed the key with a
      // non-bool value so `_prefs.getBool` throws when it casts, exercising
      // the try/catch-swallow path for real.
      SharedPreferences.setMockInitialValues({kKeyHomeTourShown: 'not-a-bool'});
      final service = await PreferencesService.create();

      expect(service.homeTourShown, isFalse);
    },
  );

  test(
    'setHomeTourShown swallows a failing write rather than throwing into '
    'the caller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = await PreferencesService.create();
      SharedPreferencesStorePlatform.instance = _ThrowingSetValueStore();

      await expectLater(service.setHomeTourShown(true), completes);
    },
  );
}

/// A [SharedPreferencesStorePlatform] whose `setValue` always fails, so a
/// write's failure path can be exercised without a real platform channel.
class _ThrowingSetValueStore extends InMemorySharedPreferencesStore {
  _ThrowingSetValueStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    throw Exception('simulated disk-write failure');
  }
}
