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
import 'package:timing_tap/features/play_loop/presentation/widgets/primary_action_button.dart';

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

      // Arm via the merged button's `armStart` look.
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.pump();
      expect(runControllerOf(tester).state.phase, RunPhase.running);

      // Burn real wall-clock time past `RunConfig.minStopElapsedMs` so the
      // FIRST of the two STOP taps below is a genuine, accepted stop (not
      // itself swallowed by the fast-double-tap guard) — this test is about
      // the `_stopConsumed`/phase double-tap guard specifically, a distinct
      // invariant from the near-instant-tap guard covered by the next test.
      burnPastMinStopElapsed();

      // Two STOP taps fired back-to-back, with no pump/rebuild in between —
      // the closest a widget test can get to a genuine fast real double-tap.
      // The same widget (now reskinned to `stopNormal`) handles both.
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.tap(find.byType(PrimaryActionButton), warnIfMissed: false);
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
    'a rapid double-tap on the merged button while arming is fully '
    'suppressed on the second tap — never a duplicate start, and never an '
    'unearned stop either (design spec v2 §3\'s merged-button behavior; '
    'fix for the merged-button double-tap regression, RunConfig.'
    'minStopElapsedMs)',
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

      // Two taps fired back-to-back, with no pump/rebuild in between: the
      // first flips the controller straight to `running` (synchronously,
      // ahead of any rebuild); the still-un-rebuilt widget's second tap
      // therefore hits `handlePrimaryPointerDown()` while the phase is
      // already `running`, resolving as that same attempt's would-be stop —
      // at ~0ms elapsed, well under `RunConfig.minStopElapsedMs`, so it must
      // be fully suppressed rather than an unearned Miss (or an instant
      // death, had this landed during `finalBandRunning`).
      await tester.tap(find.byType(PrimaryActionButton));
      await tester.tap(find.byType(PrimaryActionButton), warnIfMissed: false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final state = runControllerOf(tester).state;
      expect(
        state.phase,
        RunPhase.running,
        reason: 'the second near-instant tap on the same merged widget must '
            'be suppressed, not resolved as a stop for the run the first '
            'tap just started',
      );
      expect(
        state.attemptIndex,
        0,
        reason: 'a suppressed too-fast stop must not count as an attempt',
      );

      // Unlike the suppressed test above, the run is still genuinely
      // `running` here, which means `startRunning()`'s real auto-miss
      // `Timer` is still pending (`RunConfig.autoMissGraceMs` past the
      // random target, up to ~7s away) — `pause()` cancels it (same
      // architecture v2 §9 risk 1 discard-in-flight path a real backgrounded
      // app would take) so no pending `Timer` survives this test's teardown.
      runControllerOf(tester).pause();
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
