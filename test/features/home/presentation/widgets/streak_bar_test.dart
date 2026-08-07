import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/home/presentation/widgets/streak_bar.dart';

/// Coverage for juice spec effect 5 (`StreakWeekBar.animateEntrance`)'s
/// Reduce Motion fallback — zero prior coverage anywhere in the repo
/// (confirmed via grep: `disableAnimations` only appears in the 3 lib files
/// touched by this pass, and no `streak_bar` test file existed before this
/// one).
void main() {
  Widget harness({required int streakCount, required bool disableAnimations}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: StreakWeekBar(streakCount: streakCount, animateEntrance: true),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Reduce Motion: every completed pip renders already filled instantly, '
    'with no elastic punch-in animation in flight and no haptics scheduled',
    (tester) async {
      await tester.pumpWidget(harness(streakCount: 4, disableAnimations: true));
      // A single pump (no further time advance): if this were the animated
      // path, filled pips would still be mid-punch (staggered 150ms apart,
      // 400ms each) at this point.
      await tester.pump();

      // No `Transform` at all — the animated path wraps every filled pip in
      // `Transform.rotate(child: Transform.scale(...))` for the punch;
      // Reduce Motion's `_StaticStreakRow` path never does.
      expect(
        find.descendant(
          of: find.byType(StreakWeekBar),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      // The static row uses `AnimatedContainer` (already-filled colors from
      // the very first frame) instead of the animated path's raw `Container`
      // + `AnimatedBuilder`.
      expect(find.byType(AnimatedContainer), findsNWidgets(7));
      expect(
        find.descendant(
          of: find.byType(StreakWeekBar),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
        reason:
            'the animated punch path drives all 7 pips off one shared '
            'AnimatedBuilder; Reduce Motion\'s static row uses none',
      );

      // Advancing time changes nothing further — proving there's no
      // in-flight animation to complete (if there were, this would be the
      // only way the filled pips ever reached their end state).
      final beforeContainers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration as BoxDecoration).color)
          .toList();
      await tester.pump(const Duration(milliseconds: 500));
      final afterContainers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration as BoxDecoration).color)
          .toList();
      expect(afterContainers, beforeContainers);

      // No pending Timer (haptics) survives to teardown — if Reduce Motion
      // still scheduled the per-pip haptic Timers, flutter_test would fail
      // this test at teardown with a "Timer is still pending" error.
    },
  );

  testWidgets(
    'Reduce Motion with a zero streak renders the static all-empty row with '
    'no crash (edge case: `_setUpEntrance` never runs because '
    '`animateEntrance` still gates it, but the Reduce Motion check happens '
    'later in didChangeDependencies)',
    (tester) async {
      await tester.pumpWidget(harness(streakCount: 0, disableAnimations: true));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedContainer), findsNWidgets(7));
      expect(
        find.descendant(
          of: find.byType(StreakWeekBar),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'sanity: with motion enabled, the same streakCount DOES render the '
    'animated punch path (proves the Reduce Motion tests above are actually '
    'exercising the fallback, not just how this widget always renders)',
    (tester) async {
      await tester.pumpWidget(harness(streakCount: 4, disableAnimations: false));
      await tester.pump();

      expect(find.byType(AnimatedBuilder), findsWidgets);
      // At least one filled pip's punch transform is present immediately
      // after the first pump (t=0 of the entrance controller).
      expect(find.byType(Transform), findsWidgets);
    },
  );
}
