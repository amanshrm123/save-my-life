import 'reminder_service.dart';

/// Web no-op (architecture v3 §5/§8's interface-first pattern) — Android and
/// iOS both get real implementations, so this is reached only on web (and as
/// a defensive fallback for any other/unknown platform); never throws, never
/// schedules anything real.
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> scheduleDaily(int hour) async => false;

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> hasPermission() async => false;
}
