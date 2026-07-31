import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card_loading.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card_shell.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';

/// REGRESSION coverage for design v1 Revision 5 (`docs/design/outcome-card-
/// revision-5.md` §R5.1/§R5.3, following the same no-trust-the-doc-estimate
/// lesson design v1 Revision 4 (`docs/design/outcome-card-revision-4.md`
/// §R4.5 item 4) established the last time this shell's ratio changed):
/// `OutcomeCardLoading` shares `OutcomeCardShell`, so the shell's
/// `aspectRatio` change (6/7 -> 3/4) applies to the loader automatically
/// with no code change on the loader's side — but that lesson explicitly
/// flags this as the exact file that had a real overflow regression the
/// last time the shell's ratio changed, and says not to trust the doc's own
/// clearance estimate without rendering it.
/// These tests pump the actual widget inside a box shaped like the new
/// 3/4 silhouette (not the old 6/7 one) and assert no `RenderFlex`/overflow
/// exception is thrown, for all three tiers.
void main() {
  /// Mirrors `OutcomeCardShell`'s own `AspectRatio(3/4)` + `LayoutBuilder` ->
  /// `k` contract (design v1 §2.2): a bounded box [width]dp wide, height
  /// derived from the 3/4 ratio, so `k = width / 250`.
  Widget harness(RunOutcome outcome, {double width = 250}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: width * 4 / 3,
            child: OutcomeCardLoading(outcome: outcome),
          ),
        ),
      ),
    );
  }

  for (final outcome in RunOutcome.values) {
    testWidgets(
      '$outcome: OutcomeCardLoading renders with no overflow at the new 3/4 '
      'shell ratio (k=1, 250x333.33dp)',
      (tester) async {
        await tester.pumpWidget(harness(outcome));
        // The loader owns a repeating AnimationController — a single pump
        // (not pumpAndSettle, which would hang on a never-completing
        // animation) is enough to build+layout+paint one frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$outcome: OutcomeCardLoading renders with no overflow at the new 3/4 '
      'shell ratio at a narrower device width (k<1, 200dp)',
      (tester) async {
        await tester.pumpWidget(harness(outcome, width: 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'OutcomeCardShell itself now measures 250x333.33dp at k=1 (3/4), not '
    '250x291.67dp (the old 6/7) — the box OutcomeCardLoading actually sits '
    'inside via the real production path',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: OutcomeCardLoading(outcome: RunOutcome.death),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(OutcomeCardShell));
      expect(size.width, closeTo(250, 0.01));
      expect(size.height, closeTo(250 * 4 / 3, 0.01));
      expect(size.height, isNot(closeTo(250 * 7 / 6, 0.01)));
    },
  );
}
