import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/theme/app_theme.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';

/// Coverage for `StickerButton`'s opt-in `showTrailingArrow` slot (design v1
/// Revision 2 §R2.3): a strictly-additive param that defaults to `false` so
/// every pre-existing call site (14+ across the app) renders exactly as
/// before, and — when opted in — appends a `Transform.rotate(-pi/3)`-wrapped
/// "→" glyph after the label, sharing its text style.
void main() {
  Widget harness(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  testWidgets('showTrailingArrow defaults to false — renders a bare '
      'centered Text with no Row/arrow', (tester) async {
    await tester.pumpWidget(
      harness(
        StickerButton(
          label: 'Again',
          fill: AppColors.paper,
          labelShadow: AppColors.ink,
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('→'), findsNothing);
    // No Row inside this StickerButton's own subtree (only the plain Text).
    expect(
      find.descendant(of: find.byType(StickerButton), matching: find.byType(Row)),
      findsNothing,
    );
  });

  testWidgets('showTrailingArrow: true renders the label plus a separately '
      'rotated "→" glyph, sharing the label style', (tester) async {
    await tester.pumpWidget(
      harness(
        StickerButton(
          label: 'Share',
          fill: AppColors.red,
          labelShadow: AppColors.ink,
          showTrailingArrow: true,
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);

    // The arrow is wrapped in its own Transform.rotate at exactly -pi/3
    // (-60 degrees, tilting the rightward arrow up-and-to-the-right) —
    // distinct from the label, which is not rotated.
    final arrowTransform = tester.widget<Transform>(
      find.ancestor(of: find.text('→'), matching: find.byType(Transform)).first,
    );
    // Transform.rotate builds a rotation matrix; sanity-check it isn't the
    // identity matrix (i.e. some rotation is actually applied) and matches
    // the expected -pi/3 rotation matrix directly.
    final expected = Matrix4.rotationZ(-pi / 3);
    expect(arrowTransform.transform, expected);

    // Same label TextStyle (color/font) is shared by both Text widgets.
    final labelText = tester.widget<Text>(find.text('Share'));
    final arrowText = tester.widget<Text>(find.text('→'));
    expect(arrowText.style?.color, labelText.style?.color);
    expect(arrowText.style?.fontSize, labelText.style?.fontSize);
    expect(arrowText.style?.fontFamily, labelText.style?.fontFamily);
  });

  testWidgets('showTrailingArrow: true still centers content with no '
      'overflow at the grown 44dp button size', (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 150,
          child: StickerButton(
            label: 'Share',
            fill: AppColors.red,
            labelShadow: AppColors.ink,
            showTrailingArrow: true,
            height: 44,
            borderRadius: 14,
            restShadowOffset: 5,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
  });

  testWidgets(
    'BUGFIX: the rotated arrow never carries a text-shadow, even when '
    'showLabelTextShadow is true (a rotated straight-down shadow would '
    "read as visibly angled relative to the label's own un-rotated one) "
    "— the label's own shadow is unaffected and still applied",
    (tester) async {
      await tester.pumpWidget(
        harness(
          StickerButton(
            label: 'Share',
            fill: AppColors.red,
            labelShadow: AppColors.ink,
            showTrailingArrow: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final labelText = tester.widget<Text>(find.text('Share'));
      final arrowText = tester.widget<Text>(find.text('→'));

      expect(labelText.style?.shadows, isNotNull, reason: 'default showLabelTextShadow: true');
      expect(arrowText.style?.shadows, isNull);

      // Color/fontSize still match, per the pre-existing sharing contract.
      expect(arrowText.style?.color, labelText.style?.color);
      expect(arrowText.style?.fontSize, labelText.style?.fontSize);
    },
  );
}
