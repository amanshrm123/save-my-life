import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/state/settings_providers.dart';
import '../application/reminder_service.dart';
import '../application/reminder_service_android.dart';
import '../application/reminder_service_noop.dart';

/// Default reminder hour (architecture v3 §8, flagged as a tunable default,
/// not founder-pinned beyond "19:00 local").
const int kDefaultReminderHour = 19;

/// Android-only real service; web (and any other non-Android platform) gets
/// the no-op (architecture §5/§8's interface-first pattern). `kIsWeb` is
/// checked first so `defaultTargetPlatform` is never consulted in a context
/// where it would be meaningless.
final Provider<ReminderService> reminderServiceProvider = Provider<ReminderService>((ref) {
  if (kIsWeb) return const NoopReminderService();
  if (defaultTargetPlatform != TargetPlatform.android) return const NoopReminderService();
  return AndroidReminderService(FlutterLocalNotificationsPlugin());
});

/// Orchestrates enable/disable/reconcile (architecture v3 §8/§11 risk 1).
/// Deliberately separate from `SettingsController` — `settings` stays
/// notifications-agnostic; this controller depends on `settings` (one
/// direction only) to keep the persisted toggle in sync with the real
/// scheduling outcome.
class ReminderController extends Notifier<void> {
  @override
  void build() {}

  /// Requests permission and, if granted, schedules the daily reminder and
  /// flips the settings toggle on. Returns whether scheduling genuinely
  /// succeeded (permission granted *and* the underlying schedule call
  /// itself succeeded) — the toggle is still flipped on even if the
  /// schedule call failed, since it self-heals via `reconcile()` on next
  /// launch regardless (architecture §11 risk 1); this return value is
  /// purely a signal-accuracy improvement for the calling UI.
  Future<bool> enable({int hour = kDefaultReminderHour}) async {
    final service = ref.read(reminderServiceProvider);
    final granted = await service.requestPermission();
    if (!granted) return false;
    final scheduled = await service.scheduleDaily(hour);
    await ref.read(settingsProvider.notifier).setReminderFlag(true);
    return scheduled;
  }

  Future<void> disable() async {
    await ref.read(reminderServiceProvider).cancel();
    await ref.read(settingsProvider.notifier).setReminderFlag(false);
  }

  /// App-start reconciliation (architecture §11 risk 1): if the toggle is on
  /// but nothing is guaranteed to still be scheduled (e.g. after a plugin
  /// update or a cleared alarm), cancel-then-reschedule is idempotent and
  /// cheap, so it's safe to just always re-assert the schedule when enabled.
  Future<void> reconcile() async {
    final enabled = ref.read(settingsProvider).reminder;
    if (!enabled) return;
    await ref.read(reminderServiceProvider).scheduleDaily(kDefaultReminderHour);
  }
}

final NotifierProvider<ReminderController, void> reminderControllerProvider =
    NotifierProvider<ReminderController, void>(ReminderController.new);
