import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/widgets/page_dots.dart';
import 'package:timing_tap/features/tour/domain/tour_step.dart';
import 'package:timing_tap/features/tour/presentation/widgets/coach_mark_card.dart';

/// `CoachMarkCard` (design v1 §3.2): the coach mark's content + the
/// steps-1-3-only `Skip the tour` link.
void main() {
  Widget harness(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  testWidgets('renders the step\'s emoji, headline and body, plus dots at the '
      'right index', (tester) async {
    await tester.pumpWidget(
      harness(
        CoachMarkCard(
          step: kHomeTourSteps[1],
          stepIndex: 1,
          stepCount: kHomeTourSteps.length,
          onAdvance: () {},
          onSkip: () {},
        ),
      ),
    );

    expect(find.text('📊'), findsOneWidget);
    expect(find.text('Your record'), findsOneWidget);
    expect(find.text('Survived, Eternal, Deaths. Tap any tile for full stats.'), findsOneWidget);
    final dots = tester.widget<PageDots>(find.byType(PageDots));
    expect(dots.activeIndex, 1);
    expect(dots.count, 4);
  });

  testWidgets('button reads "Next" on steps 1-3 and shows the Skip link', (tester) async {
    var advanced = false;
    var skipped = false;
    await tester.pumpWidget(
      harness(
        CoachMarkCard(
          step: kHomeTourSteps[0],
          stepIndex: 0,
          stepCount: kHomeTourSteps.length,
          onAdvance: () => advanced = true,
          onSkip: () => skipped = true,
        ),
      ),
    );

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Got it'), findsNothing);
    expect(find.text('Skip the tour'), findsOneWidget);

    await tester.tap(find.text('Next'));
    expect(advanced, isTrue);

    await tester.tap(find.text('Skip the tour'));
    expect(skipped, isTrue);
  });

  testWidgets('button reads "Got it" on the last step and hides the Skip link '
      'when onSkip is null', (tester) async {
    await tester.pumpWidget(
      harness(
        CoachMarkCard(
          step: kHomeTourSteps[3],
          stepIndex: 3,
          stepCount: kHomeTourSteps.length,
          onAdvance: () {},
          onSkip: null,
        ),
      ),
    );

    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Skip the tour'), findsNothing);
  });
}
