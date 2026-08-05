/// Sentry DSN (see docs/SENTRY.md) — injected at build time only via
/// `--dart-define=SENTRY_DSN=...`, read with `String.fromEnvironment`. Empty
/// by default; NEVER hardcode a real value here or anywhere else (matches
/// the `kFbAppId` convention at
/// `lib/features/sharing/domain/share_target.dart`). A build with no define
/// simply never initializes Sentry — `main()` gates on [kSentryEnabled].
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Defaults to `development`, not `production` — a build that sets
/// `SENTRY_DSN` (e.g. via a CI secret) but forgets this flag must never have
/// its events silently mislabeled as production traffic. CI passes
/// `--dart-define=SENTRY_ENV=production` explicitly for release builds.
const String kSentryEnvironment = String.fromEnvironment(
  'SENTRY_ENV',
  defaultValue: 'development',
);

/// Falls back to the version currently pinned in `pubspec.yaml`'s
/// `version:` line — kept in sync by hand today, so pass
/// `--dart-define=SENTRY_RELEASE=...` explicitly in CI rather than relying
/// on this default staying correct after a version bump.
const String kSentryRelease = String.fromEnvironment(
  'SENTRY_RELEASE',
  defaultValue: '1.0.0+1',
);

/// Whether `main()` should initialize Sentry at all.
bool get kSentryEnabled => kSentryDsn.isNotEmpty;
