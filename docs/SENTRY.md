## Automatic Configuration (Recommended)

Add Sentry automatically to your app with the [Sentry wizard](https://docs.sentry.io/platforms/flutter/#install) (call this inside your project directory).

```bash
brew install getsentry/tools/sentry-wizard && sentry-wizard -i flutter --saas --org <your-org-slug> --project <your-project-slug>
```

The Sentry wizard will automatically patch your project with the following:

- Configure the SDK with your DSN and performance monitoring options in your `main.dart` file.
- Update your `pubspec.yaml` with the Sentry package
- Add an example error to verify your setup

## Manual Configuration

This app wires Sentry through `lib/core/monitoring/sentry_config.dart` (never
a hardcoded value — see that file's doc comment for why) plus
`lib/core/monitoring/sentry_service.dart`. Supply the following at build/run
time via `--dart-define`, never by editing the source:

```
flutter run --dart-define=SENTRY_DSN=<your-project-dsn> --dart-define=SENTRY_ENV=development
```

Find your project's DSN in Sentry under **Settings → Projects → (your
project) → Client Keys (DSN)**. **Do not paste it into this file or any other
committed doc/config** — a DSN pasted into a public (or later-made-public)
repo gets scraped and used to flood your project with garbage events. If a
real DSN was ever committed here, treat it as burned and rotate it from that
same settings page.

`SENTRY_ENV` defaults to `development` when unset, so a forgotten flag never
silently mislabels a local run as `production` — CI must pass
`--dart-define=SENTRY_ENV=production` explicitly for release builds.
`SENTRY_RELEASE` defaults to the version pinned in `sentry_config.dart`
(kept in sync with `pubspec.yaml`'s `version:` line by hand today — pass
`--dart-define=SENTRY_RELEASE=...` explicitly in CI to avoid relying on that).

## Verify

Create an intentional error, so you can test that everything is working. In the example below, pressing the button will throw an exception:

```dart

import 'package:sentry/sentry.dart';

child: ElevatedButton(
  onPressed: () {
    throw StateError('This is test exception');
  },
  child: const Text('Verify Sentry Setup'),
)

```
