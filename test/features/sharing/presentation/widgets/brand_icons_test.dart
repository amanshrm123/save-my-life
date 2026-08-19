import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/sharing/domain/share_target.dart';
import 'package:timing_tap/features/sharing/presentation/widgets/brand_icons.dart';

/// Coverage for `brandGlyphFor` (bug fix: the earlier hand-drawn
/// `CustomPainter` glyphs were approximations; these are pixel-accurate
/// Simple Icons SVGs, verified on-device — see `brand_icons.dart`'s doc
/// comment for why each brand needs a different backing-shape treatment).
void main() {
  Future<void> pump(WidgetTester tester, ShareTarget target) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: brandGlyphFor(target))),
      ),
    );
  }

  testWidgets('renders all 3 targets without throwing', (tester) async {
    for (final target in ShareTarget.values) {
      await pump(tester, target);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'target: $target');
    }
  });

  testWidgets('every target renders exactly one SvgPicture (the brand glyph)', (tester) async {
    for (final target in ShareTarget.values) {
      await pump(tester, target);
      await tester.pump();
      expect(find.byType(SvgPicture), findsOneWidget, reason: 'target: $target');
    }
  });

  testWidgets(
    'Instagram and WhatsApp draw an explicit colored backing shape behind '
    'their (fill-less, line-art) glyph; Facebook does not need one since its '
    'own path is a self-contained solid-with-cutout shape',
    (tester) async {
      await pump(tester, ShareTarget.instagramStory);
      await tester.pump();
      final instagramContainer = tester.widget<Container>(
        find.ancestor(of: find.byType(SvgPicture), matching: find.byType(Container)).first,
      );
      expect(instagramContainer.decoration, isA<BoxDecoration>());
      expect((instagramContainer.decoration as BoxDecoration).gradient, isNotNull);

      await pump(tester, ShareTarget.whatsappStatus);
      await tester.pump();
      final whatsappContainer = tester.widget<Container>(
        find.ancestor(of: find.byType(SvgPicture), matching: find.byType(Container)).first,
      );
      final whatsappDecoration = whatsappContainer.decoration as BoxDecoration;
      expect(whatsappDecoration.color, const Color(0xFF25D366));
      expect(whatsappDecoration.shape, BoxShape.circle);

      await pump(tester, ShareTarget.facebookStory);
      await tester.pump();
      expect(
        find.ancestor(of: find.byType(SvgPicture), matching: find.byType(Container)),
        findsNothing,
        reason: "Facebook's SVG is self-contained — no backing Container should wrap it",
      );
    },
  );
}
