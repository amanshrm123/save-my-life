import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/ads/presentation/interstitial_screen.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/countdown_view.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';

import 'support/app_harness.dart';

/// Task 1 — full first-session flow, exercised through the REAL `App`/
/// `MaterialApp` widget and its real named routes end to end: fresh launch
/// (empty prefs) -> onboarding (splash -> 3 teach cards -> name capture) ->
/// Home -> Play -> countdown -> arm -> run -> stop -> outcome -> Again
/// (no ad, 1st completed run) -> run 2 -> Again (no ad, 2nd) -> run 3 ->
/// Again (ad due, 3rd completed run) -> dismiss ad -> next countdown.
///
/// No single existing test file exercises this whole chain: onboarding,
/// Play Loop, Outcome Cards, and the AdGate cadence are each covered in
/// isolation elsewhere, but never chained through one real session.
void main() {
  testWidgets(
    'fresh install -> onboarding -> Home -> Play -> 3 completed runs -> '
    'AdGate fires on the 3rd "Again", not the 1st or 2nd',
    (tester) async {
      final service = await mockPrefsService(); // genuinely empty prefs
      await pumpRealAppPastSplash(tester, service);

      // -- Onboarding, starting from a real fresh install.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await completeOnboarding(tester, name: 'Aman');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(service.onboardingComplete, isTrue);
      expect(service.playerName, 'Aman');

      // -- Home -> Play -> countdown.
      await tapPlayFromHome(tester);
      expect(find.byType(PlayLoopScreen), findsOneWidget);
      expect(find.byType(CountdownView), findsOneWidget);
      await pumpPastCountdown(tester);

      // -- Run 1: arm, run, stop (real taps), forced to a quick death.
      await tapThroughToQuickDeath(tester);

      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(find.text('💀 You died'), findsOneWidget);
      expect(service.totalRunsPlayed, 1);
      expect(service.totalDeaths, 1);

      // -- "Again" after the 1st completed run: no ad, straight to the next
      // countdown.
      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();

      expect(
        find.byType(InterstitialScreen),
        findsNothing,
        reason: 'AdGate cadence is every 3 completed runs; this is only the 1st',
      );
      expect(find.byType(CountdownView), findsOneWidget);
      await pumpPastCountdown(tester);

      // -- Run 2: same shape.
      await tapThroughToQuickDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(service.totalRunsPlayed, 2);
      expect(service.totalDeaths, 2);

      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();

      expect(
        find.byType(InterstitialScreen),
        findsNothing,
        reason: 'still only the 2nd completed run',
      );
      expect(find.byType(CountdownView), findsOneWidget);
      await pumpPastCountdown(tester);

      // -- Run 3: completes the 3rd run -> AdGate is now due.
      await tapThroughToQuickDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(service.totalRunsPlayed, 3);
      expect(service.totalDeaths, 3);

      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();

      expect(
        find.byType(InterstitialScreen),
        findsOneWidget,
        reason: 'the 3rd completed run must trigger the interstitial per '
            'the "every 3 completed runs" cadence',
      );

      // -- Dismiss the ad (close button) -> continues into the next run.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(InterstitialScreen), findsNothing);
      expect(find.byType(PlayLoopScreen), findsOneWidget);
      expect(find.byType(CountdownView), findsOneWidget);

      // Drain the fresh countdown's own internal timer chain so no pending
      // `Timer` survives this test's teardown.
      await pumpPastCountdown(tester);
    },
  );
}
