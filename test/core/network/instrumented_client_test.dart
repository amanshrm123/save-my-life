import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timing_tap/core/network/instrumented_client.dart';

/// Coverage for `InstrumentedClient` — the wrapper stays entirely
/// transparent to callers (same response, same thrown error) since it's
/// spliced into the app's one real `http.Client` via `createHttpClient`
/// (outcome_providers.dart). None of these tests initialize Sentry, so a
/// passing run also proves `Sentry.addBreadcrumb`/`captureException` are
/// safe no-ops without `SentryFlutter.init` having run first (the state
/// every non-Sentry-configured build is actually in).
void main() {
  test('a successful request passes the real response through unchanged', () async {
    final inner = MockClient((request) async {
      return http.Response('ok', 200);
    });
    final client = InstrumentedClient(inner);

    final response = await client.get(Uri.parse('https://example.com/stories.json'));

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
  });

  test('a failing request rethrows the original error, not a wrapped one', () async {
    final inner = MockClient((request) async {
      throw Exception('boom');
    });
    final client = InstrumentedClient(inner);

    await expectLater(
      () => client.get(Uri.parse('https://example.com/stories.json')),
      throwsA(isA<Exception>()),
    );
  });

  test('close() forwards to the wrapped inner client, not a no-op', () {
    var innerClosed = false;
    final inner = _TrackingCloseClient(onClose: () => innerClosed = true);
    final client = InstrumentedClient(inner);

    client.close();

    expect(
      innerClosed,
      isTrue,
      reason:
          'http.BaseClient.close() is a no-op by default — without an '
          'override, wrapping a client here would silently stop it from '
          'ever actually releasing its connection pool',
    );
  });
}

class _TrackingCloseClient extends http.BaseClient {
  _TrackingCloseClient({required this.onClose});
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError('not exercised by the close() test');
  }

  @override
  void close() => onClose();
}
