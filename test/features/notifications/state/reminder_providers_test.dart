import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/notifications/application/reminder_service.dart';
import 'package:timing_tap/features/notifications/state/reminder_providers.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/settings/state/settings_providers.dart';

/// REGRESSION (QA bug 1): `reminder_enabled` must never persist `true`, and
/// a schedule must never be left behind, unless permission was genuinely
/// granted -- architecture v3 §8: "Denied permission: `reminder_enabled`
/// stays false... never nags."
void main() {
  Future<ProviderContainer> makeContainer(
    ReminderService service, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefsService = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefsService),
        reminderServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('enable() with permission denied: reminder_enabled stays false and '
      'scheduleDaily is never called', () async {
    final fake = _FakeReminderService(granted: false);
    final container = await makeContainer(fake);

    final result = await container.read(reminderControllerProvider.notifier).enable();

    expect(result, isFalse);
    expect(container.read(settingsProvider).reminder, isFalse);
    expect(fake.scheduleDailyCallCount, 0);
  });

  test('enable() with permission granted but the schedule call itself '
      'failing: reminder_enabled still stays false (gated on BOTH booleans, '
      'not permission alone)', () async {
    final fake = _FakeReminderService(granted: true, scheduled: false);
    final container = await makeContainer(fake);

    final result = await container.read(reminderControllerProvider.notifier).enable();

    expect(result, isFalse);
    expect(container.read(settingsProvider).reminder, isFalse);
  });

  test('enable() with permission granted and schedule succeeding: '
      'reminder_enabled becomes true', () async {
    final fake = _FakeReminderService(granted: true, scheduled: true);
    final container = await makeContainer(fake);

    final result = await container.read(reminderControllerProvider.notifier).enable();

    expect(result, isTrue);
    expect(container.read(settingsProvider).reminder, isTrue);
  });

  test('reconcile() self-corrects when permission was revoked at the OS '
      'level after the toggle was turned on: cancels the stale schedule and '
      'flips reminder_enabled back off, rather than blindly rescheduling', () async {
    final fake = _FakeReminderService(granted: true, scheduled: true, permissionCurrentlyGranted: false);
    final container = await makeContainer(fake, initialPrefs: {kKeyReminderEnabled: true});

    await container.read(reminderControllerProvider.notifier).reconcile();

    expect(
      container.read(settingsProvider).reminder,
      isFalse,
      reason: 'permission is gone, so the toggle must not still claim it is on',
    );
    expect(fake.cancelCallCount, 1);
    expect(
      fake.scheduleDailyCallCount,
      0,
      reason: 'must not reschedule once permission is confirmed revoked',
    );
  });

  test('reconcile() reschedules as normal when permission is still granted', () async {
    final fake = _FakeReminderService(granted: true, scheduled: true, permissionCurrentlyGranted: true);
    final container = await makeContainer(fake, initialPrefs: {kKeyReminderEnabled: true});

    await container.read(reminderControllerProvider.notifier).reconcile();

    expect(container.read(settingsProvider).reminder, isTrue);
    expect(fake.scheduleDailyCallCount, 1);
  });
}

/// A fully-controllable `ReminderService` test double (no real platform
/// channel) -- records call counts so tests can assert exactly what was and
/// wasn't invoked, not just the end state.
class _FakeReminderService implements ReminderService {
  _FakeReminderService({
    required this.granted,
    this.scheduled = true,
    this.permissionCurrentlyGranted = true,
  });

  final bool granted;
  final bool scheduled;
  final bool permissionCurrentlyGranted;

  int scheduleDailyCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool> scheduleDaily(int hour) async {
    scheduleDailyCallCount += 1;
    return scheduled;
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
  }

  @override
  Future<bool> hasPermission() async => permissionCurrentlyGranted;
}
