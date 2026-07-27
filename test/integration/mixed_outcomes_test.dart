import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';

import 'support/app_harness.dart';

/// Task 4 — Death -> Eternal -> Survived (well, Death -> Survived -> Eternal
/// here, all three are exercised regardless of order), all three
/// `RunOutcome`s reachable in ONE session, via the same
/// `RunController.state=` test-visible-setter technique this project's own
/// Play Loop tests use. Confirms each outcome renders the correct
/// badge/share-button label, AND that the three lifetime counters
/// (`totalDeaths`/`totalSurvives`/`totalEternal`) increment independently —
/// the regression class where one outcome's increment accidentally touches
/// another's.
void main() {
  testWidgets(
    'death, survived, and eternal are each reachable in one session and '
    'increment only their own lifetime counter',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      expect(find.byType(HomeScreen), findsOneWidget);

      // -- Run 1: forced DEATH.
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await forceEndDeath(tester);

      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(find.text('💀 You died'), findsOneWidget);
      expect(find.widgetWithText(StickerButton, 'Share →'), findsOneWidget);
      expect(service.totalRunsPlayed, 1);
      expect(service.totalDeaths, 1);
      expect(service.totalSurvives, 0);
      expect(service.totalEternal, 0);

      // -- Run 2: forced SURVIVED (final-band sudden-death, non-miss).
      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();
      await pumpPastCountdown(tester);
      await forceEndSurvived(tester);

      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(find.text('🛟 Survived'), findsOneWidget);
      expect(find.widgetWithText(StickerButton, 'Share →'), findsOneWidget);
      expect(service.totalRunsPlayed, 2);
      expect(service.totalDeaths, 1, reason: 'unaffected by the survived run');
      expect(service.totalSurvives, 1);
      expect(service.totalEternal, 0);

      // -- Run 3: forced ETERNAL (3 Perfects from cold).
      await tester.tap(find.text('Again'));
      await tester.pumpAndSettle();
      await pumpPastCountdown(tester);
      await forceEndEternal(tester);

      expect(find.byType(OutcomeCardScreen), findsOneWidget);
      expect(find.text('✨ Eternal Human'), findsOneWidget);
      expect(
        find.widgetWithText(StickerButton, 'Flex it →'),
        findsOneWidget,
        reason: 'the eternal outcome uses a distinct share-button label, not "Share →"',
      );
      expect(service.totalRunsPlayed, 3);
      expect(service.totalDeaths, 1, reason: 'unaffected by the eternal run');
      expect(service.totalSurvives, 1, reason: 'unaffected by the eternal run');
      expect(service.totalEternal, 1);
    },
  );

  // REGRESSION (QA bug 3): architecture v3 §9's nav graph lists Home as a
  // sibling action to Share/Again on the outcome screen, but it was only
  // wired to the system back-gesture (`PopScope`), never a visible tappable
  // element -- a player who doesn't know/use the back gesture had no in-app
  // way back to Home.
  testWidgets(
    'OutcomeCardScreen has a visible, tappable Home affordance that returns '
    'to HomeScreen',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await forceEndDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);

      final homeAffordance = find.text('Home');
      expect(
        homeAffordance,
        findsOneWidget,
        reason: 'a visible on-screen "Home" element must exist, not just the back gesture',
      );

      await tester.tap(homeAffordance);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OutcomeCardScreen), findsNothing);
    },
  );
}
