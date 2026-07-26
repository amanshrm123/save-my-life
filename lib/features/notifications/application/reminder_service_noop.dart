import 'reminder_service.dart';

/// Web/iOS no-op (architecture v3 §5/§8's interface-first pattern) — this
/// dev target ships Android + web only (no iOS toolchain available), so the
/// no-op mainly serves web; never throws, never schedules anything real.
class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> scheduleDaily(int hour) async => false;

  @override
  Future<void> cancel() async {}
}
