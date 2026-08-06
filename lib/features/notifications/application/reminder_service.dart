/// Daily-reminder scheduling seam (architecture v3 §5/§8) — Android and iOS
/// both get real implementations (`AndroidReminderService`,
/// `IosReminderService`); web gets a no-op (same interface-first pattern as
/// `AdService`).
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

  /// Checks whether the OS notification permission is *currently* granted,
  /// without prompting the user (unlike [requestPermission], which shows a
  /// dialog). Used to self-correct if permission was revoked after the fact
  /// (e.g. via OS Settings) — architecture v3 §8: denied permission must
  /// never nag, so a stale schedule from before a revocation must not keep
  /// firing and the toggle must not stay on.
  Future<bool> hasPermission();
}
