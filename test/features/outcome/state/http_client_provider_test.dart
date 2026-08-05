import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:timing_tap/core/network/instrumented_client.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';

/// Coverage for `createHttpClient`'s gating — extracted specifically so this
/// branch is testable without a real `--dart-define=SENTRY_DSN=...` at
/// test-run time (mirrors this codebase's established pattern for anything
/// gated on a compile-time `kXyzEnabled` constant).
void main() {
  test('wraps in InstrumentedClient when sentryEnabled is true', () {
    final inner = http.Client();
    final client = createHttpClient(inner, sentryEnabled: true);

    expect(client, isA<InstrumentedClient>());
  });

  test('returns the plain inner client, unwrapped, when sentryEnabled is false', () {
    final inner = http.Client();
    final client = createHttpClient(inner, sentryEnabled: false);

    expect(client, same(inner));
  });
}
