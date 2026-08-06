import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_android.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_ios.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_noop.dart';
import 'package:timing_tap/features/notifications/state/reminder_providers.dart';

/// `createReminderService` is a plain top-level function precisely so this
/// 3-way platform branch is testable without a real `--dart-define`/platform
/// override -- see reminder_providers.dart's doc comment.
void main() {
  test('isWeb true always wins, regardless of platform', () {
    expect(
      createReminderService(TargetPlatform.android, isWeb: true),
      isA<NoopReminderService>(),
    );
    expect(createReminderService(TargetPlatform.iOS, isWeb: true), isA<NoopReminderService>());
  });

  test('Android, not web -> AndroidReminderService', () {
    expect(
      createReminderService(TargetPlatform.android, isWeb: false),
      isA<AndroidReminderService>(),
    );
  });

  test('iOS, not web -> IosReminderService', () {
    expect(createReminderService(TargetPlatform.iOS, isWeb: false), isA<IosReminderService>());
  });

  test('any other platform (e.g. macOS/windows/linux/fuchsia), not web -> '
      'NoopReminderService', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        createReminderService(platform, isWeb: false),
        isA<NoopReminderService>(),
        reason: '$platform should fall back to the no-op',
      );
    }
  });
}
