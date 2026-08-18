import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/avatar/domain/avatar_catalog.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_figure.dart';

/// Coverage for the arms/hands + shirt-yoke structural pass added on top of
/// the figure's previously limbless silhouette. The new geometry is purely
/// additive (never touches `_bodyPath`, the fill clip, or any existing
/// constant the wave test/HUD sizing test already pin) so there's nothing
/// new to unit-test at the pure-function level -- what's actually at risk is
/// a `Canvas` exception from a hand-tuned coordinate on one of the 12 real
/// hairstyle/color combinations the painter never got exercised against
/// individually before, at both the tiny HUD size and the life-threatening
/// fill extremes where the new shirt-yoke clip and the arms' shoulder-socket
/// overlap with `_paintBody` are most geometrically stressed.
void main() {
  group('AvatarFigure renders every catalog entry without throwing', () {
    for (final spec in kAvatars) {
      for (final fillPercent in [0, 1, 50, 100]) {
        testWidgets(
          'id ${spec.id} (${spec.gender.name}/${spec.hair.name}) at '
          '$fillPercent% fill, HUD size (58x72), continuousWave',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 58,
                      height: 72,
                      child: AvatarFigure(
                        spec: spec,
                        fillPercent: fillPercent,
                        continuousWave: true,
                      ),
                    ),
                  ),
                ),
              ),
            );
            // A few frames, not `pumpAndSettle` -- the continuous wave never
            // settles by design (see `LifeAvatar`'s own doc comment).
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await tester.pump(const Duration(milliseconds: 400));

            expect(tester.takeException(), isNull);
            expect(find.byType(AvatarFigure), findsOneWidget);
          },
        );
      }
    }
  });
}
