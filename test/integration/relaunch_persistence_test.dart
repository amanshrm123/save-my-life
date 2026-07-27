import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/run_chips.dart';

import 'support/app_harness.dart';

/// Task 2 — relaunch persistence: complete a full session (onboard + a few
/// runs, at least one death), then simulate an app "relaunch" by rebuilding
/// a brand-new `App()`/`ProviderScope` widget tree against the SAME
/// `SharedPreferences` mock backing store (never resetting
/// `setMockInitialValues`) — exactly what a real process kill+relaunch does:
/// fresh in-RAM providers, same durable prefs. Confirms onboarding is
/// correctly skipped and Home/Play reflect the persisted totals + streak,
/// not fresh/zeroed state.
///
/// Note: the outcome screen's "Home" action has no visible button in this
/// codebase — it's reached only via the system back gesture (`PopScope`'s
/// `onPopInvokedWithResult` -> `_onHome()`), so a real back-gesture
/// simulation (`tester.binding.handlePopRoute()`) is the correct way to
/// exercise it, matching this project's `play_loop_screen_test.dart` pattern
/// for the same PopScope idiom.
void main() {
  testWidgets(
    'a relaunched app (same prefs, fresh ProviderScope) skips onboarding and '
    'shows the persisted Run/Deaths/stats numbers and streak',
    (tester) async {
      final service = await mockPrefsService();
      await pumpRealAppPastSplash(tester, service);

      await completeOnboarding(tester, name: 'Aman');
      expect(find.byType(HomeScreen), findsOneWidget);

      // Run 1: a real death.
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await tapThroughToQuickDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      // `OutcomeChip` uppercases its label (design v1 §3/§5); Death's copy
      // itself is unchanged.
      expect(find.text('💀 YOU DIED'), findsOneWidget);

      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();

      // Run 2: forced to survive (final-band sudden-death, non-miss).
      await pumpPastCountdown(tester);
      await forceEndSurvived(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      // 🆘, not 🛟 (founder-resolved tofu-rendering swap, design v1
      // §0/§4.2), and uppercased by `OutcomeChip`.
      expect(find.text('🆘 SURVIVED'), findsOneWidget);

      // Persisted state right before the "relaunch".
      expect(service.totalRunsPlayed, 2);
      expect(service.totalDeaths, 1);
      expect(service.totalSurvives, 1);
      expect(service.totalEternal, 0);
      expect(service.bestLifePercent, 50, reason: 'neither forced run ever raised life above the starting 50%');
      expect(service.streakCurrent, 1, reason: 'both runs completed on the same real calendar day');

      // Back-gesture "Home" from the outcome screen.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(statTileValue(tester, 'Deaths'), '1');
      expect(statTileValue(tester, 'Eternal'), '0');
      expect(statTileValue(tester, 'Best\nlife'), '50%');
      expect(
        find.text('1 day', findRichText: true),
        findsOneWidget,
        reason: 'DAILY STREAK card reads "1 day" (singular) before the relaunch',
      );

      // -- Simulate an app relaunch: an entirely fresh widget tree / fresh
      // `ProviderScope` (fresh in-RAM providers), same `service` instance
      // (same underlying mock `SharedPreferences` state) — no
      // `setMockInitialValues` reset.
      await pumpRealAppPastSplash(tester, service);

      expect(
        find.byType(OnboardingScreen),
        findsNothing,
        reason: 'onboarding_complete was persisted true; a relaunch must skip it',
      );
      expect(find.byType(HomeScreen), findsOneWidget);

      // Home reflects the persisted totals, not a fresh/zeroed RAM state.
      expect(statTileValue(tester, 'Deaths'), '1');
      expect(statTileValue(tester, 'Eternal'), '0');
      expect(statTileValue(tester, 'Best\nlife'), '50%');
      expect(
        find.text('1 day', findRichText: true),
        findsOneWidget,
        reason: 'the streak (day 1, last played "today") must read correctly '
            'after the relaunch, not reset or broken',
      );

      // Cross-check the persisted Run number too, via the real Play screen's
      // RunChips (this app has no "Total runs" figure on Home itself).
      // RunChips only renders past the countdown (the countdown phase shows
      // `CountdownView` instead), so flush it first — which also drains the
      // countdown's own internal timer chain before this test ends.
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      final chips = tester.widget<RunChips>(find.byType(RunChips));
      expect(chips.runNumber, 3, reason: 'totalRunsPlayed persisted as 2 -> this fresh run is #3');
      expect(chips.deaths, 1, reason: 'totalDeaths persisted as 1 carries into the fresh run seed');
    },
  );
}
