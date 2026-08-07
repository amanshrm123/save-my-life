import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/monitoring/sentry_service.dart';
import 'reminder_service.dart';

/// Real iOS implementation (architecture v3 §8), mirroring
/// [AndroidReminderService] exactly but through `flutter_local_notifications`'
/// Darwin surface: `DarwinInitializationSettings`, `requestPermissions`,
/// `checkPermissions`, and `DarwinNotificationDetails`. Every plugin call is
/// wrapped so a denied permission or a failed schedule never throws into the
/// UI (architecture §11 risk 1) — worst case the reminder silently doesn't
/// fire. Swallowed exceptions are reported to Sentry rather than discarded,
/// so a real failure is invisible to the player but visible to us.
///
/// `tz.local` is set to the device's real IANA zone once at startup
/// (`main()`, via `flutter_timezone`), so "19:00 local" genuinely means
/// 19:00 in the phone's own timezone, not UTC.
class IosReminderService implements ReminderService {
  IosReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Lazily initializes the plugin exactly once before its first real use
  /// (permission request or schedule) — the plugin requires `initialize()`
  /// with Darwin settings before those calls behave correctly.
  ///
  /// The three `request*Permission` flags are explicitly `false` here — bug
  /// fix: `DarwinInitializationSettings()`'s own defaults are all `true`,
  /// which makes `initialize()` itself implicitly trigger the real OS
  /// permission prompt as a side effect, *before* [requestPermission]'s own
  /// explicit (and, until this fix, redundant) call ever runs. That made the
  /// actual moment the user sees the system dialog an implementation detail
  /// of a differently-named method instead of the one the toggle calls,
  /// which is exactly what made a live end-to-end test of this flow so hard
  /// to reason about. With these forced `false`, `initialize()` genuinely
  /// never prompts, and [requestPermission]'s own `requestPermissions(...)`
  /// call is the single, intentional place the dialog can appear.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
    }
  }

  /// A single stable notification id (architecture §11 risk 1) — enabling
  /// always cancels-then-schedules, so there is never more than one
  /// scheduled reminder at a time. Same id as [AndroidReminderService]'s,
  /// since the two services never run in the same process.
  static const int _notificationId = 1001;

  static const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: true,
  );

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
      return false;
    }
  }

  @override
  Future<bool> scheduleDaily(int hour) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(id: _notificationId);
      final scheduledDate = _nextInstanceOfHour(hour);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Keep your streak alive?',
        body: "A daily nudge so you don't lose your streak. No spam.",
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(iOS: _iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e, st) {
      // Swallow — a failed schedule never crashes/blocks gameplay. `false`
      // signals the caller that it genuinely didn't take (architecture §11
      // risk 1 self-heals via `reconcile()` on next launch regardless).
      unawaited(SentryService.captureException(e, stackTrace: st));
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
    }
  }

  /// Non-prompting permission check (architecture §11 risk 1's self-heal):
  /// `checkPermissions()` reads current OS state without showing the
  /// permission dialog, unlike [requestPermission]. Any one of
  /// alert/sound/badge being enabled counts as "has permission" — mirrors
  /// Android's coarser `areNotificationsEnabled()` boolean.
  @override
  Future<bool> hasPermission() async {
    try {
      await _ensureInitialized();
      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final options = await iosImpl?.checkPermissions();
      if (options == null) return false;
      return options.isAlertEnabled || options.isSoundEnabled || options.isBadgeEnabled;
    } catch (e, st) {
      unawaited(SentryService.captureException(e, stackTrace: st));
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
