import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/monitoring/sentry_config.dart';

/// Coverage for the dart-define gating constants — mirrors this codebase's
/// existing convention (e.g. `kFbAppId`) of a build with no `--dart-define`
/// degrading safely rather than crashing or silently enabling something.
void main() {
  test('kSentryDsn is empty by default (no --dart-define at test-run time)', () {
    expect(kSentryDsn, isEmpty);
  });

  test('kSentryEnabled is false when kSentryDsn is empty', () {
    expect(kSentryEnabled, isFalse);
  });

  test(
    'kSentryEnvironment defaults to development, not production — a build '
    'that forgets to pass SENTRY_ENV must never be silently mislabeled',
    () {
      expect(kSentryEnvironment, 'development');
    },
  );

  test('kSentryRelease has a non-empty fallback', () {
    expect(kSentryRelease, isNotEmpty);
  });
}
