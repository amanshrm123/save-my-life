import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/onboarding/presentation/onboarding_screen.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/countdown_view.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/stop_button.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/target_arm_button.dart';

import 'support/app_harness.dart';

/// Task 6 — rapid/boundary interactions, simulating a fast real double-tap
/// by firing two `tester.tap()` calls back-to-back with NO `pump()` in
/// between (the same technique `settings_screen_test.dart`'s existing
/// re-entrancy regression test uses for "Yes, reset"). This confirms the
/// `_submitting`/`_navigating`/`_handedOff`/`_sharing`/phase guards actually
/// hold when exercised through the full real widget (raw `Listener`,
/// `GestureDetector`, `StickerButton`), not just unit-tested against the
/// bare `RunController`/`Notifier` in isolation.
void main() {
  testWidgets(
    'rapid double-tap on STOP registers only one attempt, not two',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);

      await tester.tap(find.byType(TargetArmButton));
      await tester.pump();
      expect(runControllerOf(tester).state.phase, RunPhase.running);

      // Two STOP taps fired back-to-back, with no pump/rebuild in between —
      // the closest a widget test can get to a genuine fast real double-tap.
      await tester.tap(find.byType(StopButton));
      await tester.tap(find.byType(StopButton), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final state = runControllerOf(tester).state;
      expect(state.phase, RunPhase.stopped);
      expect(
        state.attemptIndex,
        1,
        reason: 'a second onPointerDown firing immediately after the first '
            'must be fully inert (architecture v2 §9 risk 3), even through '
            'the real raw Listener wiring',
      );

      // Drain the flash-dwell `Future.delayed` this stop scheduled, so no
      // pending `Timer` survives this test's teardown.
      await flushDwell(tester);
    },
  );

  testWidgets(
    'rapid double-tap on the ARM plate only starts running once',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      expect(runControllerOf(tester).state.phase, RunPhase.armed);

      await tester.tap(find.byType(TargetArmButton));
      await tester.tap(find.byType(TargetArmButton), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        runControllerOf(tester).state.phase,
        RunPhase.running,
        reason: 'a second ARM tap once already running must be a no-op '
            '(architecture v2 §9 risk 4), through the real GestureDetector',
      );
    },
  );

  testWidgets(
    'rapid double-tap on "Again" navigates to the next run exactly once, '
    'never pushing two PlayLoopScreens',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await forceEndDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);

      await tester.tap(find.text('Again'));
      await tester.tap(find.text('Again'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(PlayLoopScreen),
        findsOneWidget,
        reason: 'the `_navigating` guard must make the second "Again" tap '
            'inert, not push a second PlayLoopScreen on top',
      );
      expect(find.byType(CountdownView), findsOneWidget);

      // Drain the fresh countdown's own internal timer chain so no pending
      // `Timer` survives this test's teardown.
      await pumpPastCountdown(tester);
    },
  );

  testWidgets(
    'rapid double-tap on Share does not throw or crash the outcome screen',
    (tester) async {
      final service = await mockPrefsService({
        kKeyOnboardingComplete: true,
        kKeyPlayerName: 'Aman',
        kKeyReminderOptInShown: true,
      });
      await pumpRealAppPastSplash(tester, service);
      await tapPlayFromHome(tester);
      await pumpPastCountdown(tester);
      await forceEndDeath(tester);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(StickerButton, 'Share →'));
      await tester.tap(find.widgetWithText(StickerButton, 'Share →'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // `renderToFile`/`share_plus` platform channels aren't available under
      // `flutter test` (`CardRenderer` catches this and returns `null`
      // cleanly) -- the point of this test is the `_sharing` re-entrancy
      // guard around the concurrent renders/taps, not a genuine share
      // succeeding (that needs a real device/manual QA pass).
      expect(tester.takeException(), isNull);
      expect(find.byType(OutcomeCardScreen), findsOneWidget);
    },
  );

  testWidgets(
    'rapid double-tap on "Start playing" completes onboarding exactly once '
    '(no double navigation into Home)',
    (tester) async {
      final service = await mockPrefsService(); // fresh install
      await pumpRealAppPastSplash(tester, service);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(StickerButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StickerButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(StickerButton, 'Got it'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Aman');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(StickerButton, 'Start playing'));
      await tester.tap(find.widgetWithText(StickerButton, 'Start playing'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(service.playerName, 'Aman');
    },
  );
}
