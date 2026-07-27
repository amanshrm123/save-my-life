import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/home/presentation/widgets/streak_advanced_overlay.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/progression/domain/streak_calculator.dart';

import 'support/app_harness.dart';

/// Task 5 — the streak-advanced celebration (6.2), reached through REAL
/// `Home -> Play -> Outcome -> Home` navigation via the real `App`/
/// `AppRoutes` route table — not a synthetic covering screen the way
/// `test/features/home/presentation/home_screen_test.dart`'s existing
/// `RouteObserver` unit tests push/pop one.
///
/// This is the highest-value regression test for the most serious bug fixed
/// this session (Home sitting mounted-but-offscreen under the
/// `pushReplacement` chain and clearing `justAdvanced` before it was ever
/// shown) — this closes the gap that the existing synthetic-screen test
/// doesn't quite cover, by using the actual `PlayLoopScreen`/
/// `OutcomeCardScreen` in the real navigation stack.
void main() {
  testWidgets(
    'a run completing that advances the streak to day 2 shows the '
    'celebration on Home after real Play -> Outcome -> Home navigation',
    (tester) async {
      final today = const StreakCalculator().today();
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyStreakCurrent: 1,
        kKeyStreakBest: 1,
        kKeyStreakLastPlayDay: today - 1, // played yesterday
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.byType(StreakAdvancedView),
        findsNothing,
        reason: 'no run has completed yet this session',
      );

      // Real Home -> Play -> a completed run (real taps through arm/STOP).
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await tapThroughToQuickDeath(tester);

      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(service.streakCurrent, 2, reason: 'the completed run must have advanced the streak (gap == 1 day)');

      // Real back-gesture "Home" action from the outcome screen (the only
      // way this screen exposes it — see `outcome_card_screen.dart`'s
      // `PopScope`).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(OutcomeCardScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.byType(StreakAdvancedView),
        findsOneWidget,
        reason: 'popping back to the real Home after the streak-advancing '
            'run must show the celebration -- the whole point of the '
            'RouteAware fix this session',
      );
      expect(find.text('Day 2 — streak alive!'), findsOneWidget);
    },
  );
}
