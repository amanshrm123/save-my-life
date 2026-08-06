import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/state/settings_providers.dart';
import '../application/reminder_service.dart';
import '../application/reminder_service_android.dart';
import '../application/reminder_service_ios.dart';
import '../application/reminder_service_noop.dart';

/// Default reminder hour (architecture v3 §8, flagged as a tunable default,
/// not founder-pinned beyond "19:00 local").
const int kDefaultReminderHour = 19;

/// Plain top-level function — not buried inside the provider body — so all
/// three branches — Android real, iOS real, web/other no-op — are directly
/// unit-testable without needing a real `--dart-define`/platform override
/// at test time. `isWeb` is checked first so [platform] is never consulted
/// in a context where it would be meaningless (architecture §5/§8's
/// interface-first pattern).
ReminderService createReminderService(TargetPlatform platform, {required bool isWeb}) {
  if (isWeb) return const NoopReminderService();
  if (platform == TargetPlatform.android) {
    return AndroidReminderService(FlutterLocalNotificationsPlugin());
  }
  if (platform == TargetPlatform.iOS) {
    return IosReminderService(FlutterLocalNotificationsPlugin());
  }
  return const NoopReminderService();
}

final Provider<ReminderService> reminderServiceProvider = Provider<ReminderService>((ref) {
  return createReminderService(defaultTargetPlatform, isWeb: kIsWeb);
});

/// Orchestrates enable/disable/reconcile (architecture v3 §8/§11 risk 1).
/// Deliberately separate from `SettingsController` — `settings` stays
/// notifications-agnostic; this controller depends on `settings` (one
/// direction only) to keep the persisted toggle in sync with the real
/// scheduling outcome.
class ReminderController extends Notifier<void> {
  @override
  void build() {}

  /// Requests permission and, only if it's genuinely granted *and* the
  /// underlying schedule call itself succeeds, flips the settings toggle on
  /// (architecture v3 §8: "Denied permission: `reminder_enabled` stays
  /// false... never nags"). Gated on both booleans deliberately — neither a
  /// denied permission nor a permission-granted-but-schedule-failed outcome
  /// may ever persist `reminder_enabled = true` or leave a schedule behind,
  /// so the toggle's on/off state is always an accurate reflection of "is a
  /// reminder genuinely scheduled right now".
  Future<bool> enable({int hour = kDefaultReminderHour}) async {
    final service = ref.read(reminderServiceProvider);
    final granted = await service.requestPermission();
    if (!granted) return false;
    final scheduled = await service.scheduleDaily(hour);
    if (!scheduled) return false;
    await ref.read(settingsProvider.notifier).setReminderFlag(true);
    return true;
  }

  Future<void> disable() async {
    await ref.read(reminderServiceProvider).cancel();
    await ref.read(settingsProvider.notifier).setReminderFlag(false);
  }

  /// App-start reconciliation (architecture §11 risk 1): if the toggle is on
  /// but nothing is guaranteed to still be scheduled (e.g. after a plugin
  /// update or a cleared alarm), cancel-then-reschedule is idempotent and
  /// cheap, so it's safe to just always re-assert the schedule when enabled
  /// *and permission is still actually granted*.
  ///
  /// The permission re-check matters: the OS permission can be revoked after
  /// the toggle was turned on (e.g. via OS Settings) without our app ever
  /// hearing about it, and Android's own scheduling call succeeds regardless
  /// of notification permission (permission is only checked at display
  /// time) — so blindly rescheduling here would silently keep a schedule
  /// alive, and the toggle would stay on, even though permission is denied.
  /// That would violate architecture v3 §8's "denied permission: never
  /// nags". So: if permission is no longer granted, self-correct by
  /// cancelling and flipping the toggle off instead of rescheduling.
  Future<void> reconcile() async {
    final enabled = ref.read(settingsProvider).reminder;
    if (!enabled) return;
    final service = ref.read(reminderServiceProvider);
    final stillPermitted = await service.hasPermission();
    if (!stillPermitted) {
      await service.cancel();
      await ref.read(settingsProvider.notifier).setReminderFlag(false);
      return;
    }
    await service.scheduleDaily(kDefaultReminderHour);
  }
}

final NotifierProvider<ReminderController, void> reminderControllerProvider =
    NotifierProvider<ReminderController, void>(ReminderController.new);
