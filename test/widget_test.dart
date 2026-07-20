// Smoke test: the Play screen builds and shows the four zones' static
// labels without throwing. Not a timing-correctness test — see
// test/features/timing_engine/timing_engine_test.dart for that.

import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/app/app.dart';

void main() {
  testWidgets('Play screen renders the four zones', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.textContaining('LIFE:'), findsOneWidget);
    expect(find.textContaining('TARGET:'), findsOneWidget);
    expect(find.textContaining('DELTA:'), findsOneWidget);
    expect(find.textContaining('BAND:'), findsOneWidget);
    expect(find.text('TAP'), findsOneWidget);
  });
}
