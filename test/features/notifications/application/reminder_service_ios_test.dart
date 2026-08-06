import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_ios.dart';

/// `IosReminderService` talks to `flutter_local_notifications`'
/// `IOSFlutterLocalNotificationsPlugin`, which only resolves to a non-null
/// implementation when the app is genuinely running on iOS
/// (`defaultTargetPlatform == TargetPlatform.iOS`) -- on the `flutter test`
/// host platform it's always null, so every call below exercises the exact
/// "no native implementation available" path a real device would take if a
/// plugin call failed. What's under test is architecture §11 risk 1's
/// contract: a missing/failing plugin call must degrade to `false`/no-op,
/// never throw into the UI -- mirrors the same contract already relied on
/// for `AndroidReminderService`.
void main() {
  late IosReminderService service;

  setUp(() {
    service = IosReminderService(FlutterLocalNotificationsPlugin());
  });

  test('requestPermission() degrades to false instead of throwing when no '
      'native iOS implementation is available', () async {
    expect(await service.requestPermission(), isFalse);
  });

  test('hasPermission() degrades to false instead of throwing when no '
      'native iOS implementation is available', () async {
    expect(await service.hasPermission(), isFalse);
  });

  test('scheduleDaily() degrades to false instead of throwing when no '
      'native iOS implementation is available', () async {
    expect(await service.scheduleDaily(19), isFalse);
  });

  test('cancel() completes without throwing when no native iOS '
      'implementation is available', () async {
    await expectLater(service.cancel(), completes);
  });
}
