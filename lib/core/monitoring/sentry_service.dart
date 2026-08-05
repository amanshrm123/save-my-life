import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  static Future<void> init({required String dsn, required String environment, required String release}) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = environment;
        options.release = release;
        options.tracesSampleRate = 0.0; // disabled by default; enable if you want perf tracing
      },
      // no appRunner here; caller should call runApp after init completes
    );
  }

  static Future<SentryId> captureException(dynamic exception, {dynamic stackTrace}) {
    return Sentry.captureException(exception, stackTrace: stackTrace);
  }

  static void addBreadcrumb({required String message, Map<String, dynamic>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, data: data));
  }
}
