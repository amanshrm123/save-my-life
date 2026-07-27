import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/settings/presentation/settings_screen.dart';

import 'support/app_harness.dart';

/// Task 3 — reset-then-onboard-again, through the REAL app/routes: from a
/// populated state (name set, some stats, sound toggled off), Settings'
/// "Reset progress" -> confirm -> lands back on onboarding (a real
/// `pushNamedAndRemoveUntil('/')`, so the real `SplashScreen` re-runs its own
/// brand-beat/branch logic) -> onboard again with a DIFFERENT name -> Home
/// must show fresh/zeroed stats and the new name, not any leftover state
/// from before the reset (a stale un-invalidated provider, a stale closure
/// capturing the old name, etc.).
void main() {
  testWidgets(
    'Reset progress -> re-onboard with a different name -> Home/Settings '
    'reflect ONLY the new name and zeroed stats, nothing from before reset',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyTotalRunsPlayed: 5,
        kKeyTotalDeaths: 2,
        kKeyTotalSurvives: 1,
        kKeyTotalEternal: 1,
        kKeyBestLifePercent: 77,
        kKeyStreakCurrent: 4,
        kKeyStreakBest: 4,
        kKeySoundEnabled: false,
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      expect(find.byType(HomeScreen), findsOneWidget);

      // -- Sanity: the populated pre-reset state actually shows up.
      expect(statTileValue(tester, 'Deaths'), '2');
      expect(statTileValue(tester, 'Eternal'), '1');
      expect(statTileValue(tester, 'Best\nlife'), '77%');

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Aman'), findsOneWidget);

      // -- Reset progress -> confirm.
      await tester.tap(find.text('Reset progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, reset'));
      await tester.pump(); // let the reset's async chain (disable/clearAll) run
      // The real `SplashScreen` is now current (pushNamedAndRemoveUntil('/'))
      // and runs its own brand-beat delay before branching again.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(
        find.byType(OnboardingScreen),
        findsOneWidget,
        reason: 'onboarding_complete was cleared -> splash must route back into onboarding',
      );

      // -- Onboard again with a DIFFERENT name.
      await completeOnboarding(tester, name: 'Zoe');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(service.playerName, 'Zoe');
      expect(service.onboardingComplete, isTrue);
      expect(service.totalRunsPlayed, 0);
      expect(service.totalDeaths, 0);
      expect(service.totalSurvives, 0);
      expect(service.totalEternal, 0);
      expect(service.bestLifePercent, 0);
      expect(service.streakCurrent, 0);
      expect(service.soundEnabled, isTrue, reason: 'back to the documented default after a clear');

      // Home itself shows zeroed stats now, not the pre-reset numbers.
      expect(statTileValue(tester, 'Deaths'), '0');
      expect(statTileValue(tester, 'Eternal'), '0');
      expect(statTileValue(tester, 'Best\nlife'), '0%');

      // -- Regression guard: revisit Settings and confirm the Name row shows
      // the NEW name, not a stale closure/provider still holding "Aman".
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Zoe'), findsOneWidget);
      expect(find.text('Aman'), findsNothing, reason: 'no stale reference to the pre-reset name anywhere');
    },
  );
}
