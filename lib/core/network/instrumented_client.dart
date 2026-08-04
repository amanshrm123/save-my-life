import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

class InstrumentedClient extends http.BaseClient {
  final http.Client _inner;

  InstrumentedClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final start = DateTime.now();
    try {
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(start);

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'HTTP ${request.method} ${request.url} ${response.statusCode}',
          data: {
            'method': request.method,
            'url': request.url.toString(),
            'status_code': response.statusCode,
            'duration_ms': duration.inMilliseconds,
          },
        ),
      );

      return response;
    } catch (error, stackTrace) {
      final duration = DateTime.now().difference(start);
      Sentry.captureException(error, stackTrace: stackTrace);
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'HTTP ${request.method} ${request.url} FAILED',
          data: {'method': request.method, 'url': request.url.toString(), 'duration_ms': duration.inMilliseconds},
        ),
      );
      rethrow;
    }
  }
}
