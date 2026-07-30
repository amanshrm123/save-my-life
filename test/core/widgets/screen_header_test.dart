import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/widgets/screen_header.dart';

void main() {
  testWidgets('long title does not overflow at narrow widths', (tester) async {
    // 360x640 is a common narrow Android logical size -- the width at which
    // AvatarPickerScreen's 'Choose your avatar' title previously overflowed
    // this shared widget's Row by ~29px (no Expanded/ellipsis on the title).
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ScreenHeader(emoji: '\u{1F9D1}', title: 'Choose your avatar')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Choose your avatar'), findsOneWidget);
  });

  testWidgets('short title still renders unclipped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScreenHeader(emoji: '\u{2699}\u{FE0F}', title: 'Settings'))),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });
}
