## Automatic Configuration (Recommended)

Add Sentry automatically to your app with the [Sentry wizard](https://docs.sentry.io/platforms/flutter/#install) (call this inside your project directory).

```bash
brew install getsentry/tools/sentry-wizard && sentry-wizard -i flutter --saas --org 43886872cecb --project flutter
```

The Sentry wizard will automatically patch your project with the following:

- Configure the SDK with your DSN and performance monitoring options in your `main.dart` file.
- Update your `pubspec.yaml` with the Sentry package
- Add an example error to verify your setup

## Manual Configuration

Alternatively, you can also set up the SDK manually, by following the [manual setup docs](https://docs.sentry.io/platforms/flutter/manual-setup/).

If you already have the configuration for Sentry in your application, and just need this project's (flutter) DSN, you can find it below:

```
https://36d80c9be3ff30149b8b5f5718a76ff9@o4511853081657344.ingest.de.sentry.io/4511853094174806
```

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
