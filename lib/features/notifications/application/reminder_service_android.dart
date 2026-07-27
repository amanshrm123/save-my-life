import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Real Android implementation (architecture v3 §8): `flutter_local_
/// notifications` + `timezone`. Every plugin call is wrapped so a denied
/// permission or a failed schedule never throws into the UI (architecture
/// §11 risk 1) — worst case the reminder silently doesn't fire.
///
/// `tz.local` is set to the device's real IANA zone once at startup
/// (`main()`, via `flutter_timezone`), so "19:00 local" genuinely means
/// 19:00 in the phone's own timezone, not UTC.
class AndroidReminderService implements ReminderService {
  AndroidReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Lazily initializes the plugin exactly once before its first real use
  /// (permission request or schedule) — the plugin requires `initialize()`
  /// with Android settings before those calls behave correctly.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    } catch (_) {
      // Swallow — a failed init just means later calls no-op/fail quietly.
    }
  }

  /// A single stable notification id (architecture §11 risk 1) — enabling
  /// always cancels-then-schedules, so there is never more than one
  /// scheduled reminder at a time.
  static const int _notificationId = 1001;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'daily_reminder_channel',
    'Daily reminder',
    channelDescription: 'A daily nudge to keep your Stay Alive streak going.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> scheduleDaily(int hour) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(id: _notificationId);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Keep your streak alive?',
        body: "A daily nudge so you don't lose your streak. No spam.",
        scheduledDate: _nextInstanceOfHour(hour),
        notificationDetails: const NotificationDetails(android: _androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      // Swallow — a failed schedule never crashes/blocks gameplay. `false`
      // signals the caller that it genuinely didn't take (architecture §11
      // risk 1 self-heals via `reconcile()` on next launch regardless).
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {
      // Swallow.
    }
  }

  /// Non-prompting permission check (architecture §11 risk 1's self-heal):
  /// `areNotificationsEnabled()` reads current OS state without showing the
  /// permission dialog, unlike [requestPermission].
  @override
  Future<bool> hasPermission() async {
    try {
      await _ensureInitialized();
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImpl?.areNotificationsEnabled();
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
