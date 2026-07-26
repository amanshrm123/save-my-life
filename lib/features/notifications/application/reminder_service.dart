/// Daily-reminder scheduling seam (architecture v3 §5/§8) — Android-only
/// real implementation; web/iOS get a no-op (same interface-first pattern
/// as `AdService`).
abstract class ReminderService {
  /// Requests the OS notification permission (Android 13+ `POST_NOTIFICATIONS`
  /// via the plugin). Returns whether it was granted.
  Future<bool> requestPermission();

  /// Schedules the single daily reminder at [hour] local time (idempotent:
  /// callers should treat this as cancel-then-schedule, architecture §11
  /// risk 1). Returns whether the underlying schedule call genuinely
  /// succeeded — never throws (a failure is reported via `false`, not an
  /// exception), so callers get an accurate signal without needing to
  /// handle errors themselves.
  Future<bool> scheduleDaily(int hour);

  /// Cancels the scheduled reminder, if any.
  Future<void> cancel();
}
