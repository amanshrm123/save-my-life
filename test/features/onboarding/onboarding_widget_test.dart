// Widget-level smoke tests for the full onboarding chain
// (docs/design/onboarding-flow-v1.md) — Splash -> Teach1 -> Teach2 ->
// Teach3 -> Name capture -> Play, plus the returning-launch shortcut and
// the 8.1 name-rejected state.
//
// `profileRepositoryProvider`/`nameValidatorProvider` are overridden with
// test doubles so these tests never touch real Hive/asset-bundle I/O —
// same seam-over-mock approach as the existing `FakeMonotonicClock` tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/app/splash_screen.dart';
import 'package:timing_tap/core/theme.dart';
import 'package:timing_tap/features/onboarding/name_validator.dart';
import 'package:timing_tap/features/onboarding/onboarding_flow.dart';
import 'package:timing_tap/features/persistence/hive_profile_repository.dart';
import 'package:timing_tap/features/persistence/profile_repository.dart';
import 'package:timing_tap/features/run/countdown_view.dart';
import 'package:timing_tap/features/run/run_controller.dart';

import '../../support/fake_monotonic_clock.dart';
import '../../support/fake_profile_repository.dart';

void main() {
  Future<ProviderContainer> pumpSplash(
    WidgetTester tester, {
    required FakeProfileRepository repository,
    required FakeMonotonicClock clock,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileRepositoryProvider
            .overrideWith((ref) async => repository as ProfileRepository),
        nameValidatorProvider.overrideWith(
          (ref) async => NameValidator(['badword']),
        ),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SplashScreen(),
        ),
      ),
    );
    await tester.pump();
    // Clear the 900ms minimum-display timer, let the (already-resolved)
    // init future's microtasks flush, then let the `pushReplacement`
    // transition into the next screen fully settle — otherwise the next
    // screen's widgets are mid-slide-transition (positioned partway off
    // the right edge of the viewport), which makes `tester.tap` on them
    // flaky/non-hit-testing.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    return container;
  }

  // `CountdownView` paces itself with a real `Timer.periodic` (3 x 1s
  // ticks), deliberately not `pumpAndSettle`-friendly (see
  // test/widget_test.dart's own countdown group) — draining it fully here
  // avoids a "Timer is still pending" failure at test teardown once a test
  // has navigated as far as Play.
  Future<void> drainCountdown(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  }

  group('first launch (isOnboardingComplete == false)', () {
    testWidgets(
      'Splash -> Teach1 -> Teach2 -> Teach3 -> Name capture -> Play, '
      'persisting the entered name',
      (tester) async {
        final FakeProfileRepository repository = FakeProfileRepository();
        await pumpSplash(
          tester,
          repository: repository,
          clock: FakeMonotonicClock(0),
        );

        // Landed on Teach1.
        expect(find.byType(OnboardingFlow), findsOneWidget);
        expect(find.text('Tap on the number'), findsOneWidget);

        // Teach1 "Next" -> Teach2. Scoped by card key: `PageView` may keep
        // an adjacent page built just outside the viewport, so a plain
        // `find.text('Next')` could otherwise match more than one card.
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard0')),
          matching: find.text('Next'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Mind your life'), findsOneWidget);

        // Teach2 "Next" -> Teach3.
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard1')),
          matching: find.text('Next'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Three ways it ends'), findsOneWidget);

        // Teach3 "Got it" -> Name capture.
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard2')),
          matching: find.text('Got it'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('What should we call you?'), findsOneWidget);

        // Enter a clean name and submit.
        await tester.enterText(find.byType(TextField), 'Aman');
        await tester.tap(find.text('Start playing'));
        await tester.pumpAndSettle();

        // Landed in Play, straight into the countdown (first run, §9
        // "done when").
        expect(find.byType(CountdownView), findsOneWidget);
        expect(repository.isOnboardingComplete, isTrue);
        expect(repository.name, 'Aman');
        await drainCountdown(tester);
      },
    );

    testWidgets(
      'Skip on any teach card lands on Name capture, not straight into '
      'Play (§3.4) — one Skip + one "Skip for now" reaches Play',
      (tester) async {
        final FakeProfileRepository repository = FakeProfileRepository();
        await pumpSplash(
          tester,
          repository: repository,
          clock: FakeMonotonicClock(0),
        );

        expect(find.text('Tap on the number'), findsOneWidget);

        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard0')),
          matching: find.text('Skip'),
        ));
        await tester.pumpAndSettle();

        // Stops at Name capture — not Play yet.
        expect(find.text('What should we call you?'), findsOneWidget);
        expect(find.byType(CountdownView), findsNothing);
        expect(repository.isOnboardingComplete, isFalse);

        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(find.byType(CountdownView), findsOneWidget);
        expect(repository.isOnboardingComplete, isTrue);
        expect(repository.name, isNull);
        await drainCountdown(tester);
      },
    );

    testWidgets(
      'manual swipe reconciles with controller state, so a button tap '
      "after swiping doesn't skip a card or get eaten (regression test: "
      'onPageChanged used to be missing, desyncing PageView from '
      'OnboardingController.state.step)',
      (tester) async {
        final FakeProfileRepository repository = FakeProfileRepository();
        await pumpSplash(
          tester,
          repository: repository,
          clock: FakeMonotonicClock(0),
        );

        // Advance via the button to Teach2 (state.step == teach2, page 1).
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard0')),
          matching: find.text('Next'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Mind your life'), findsOneWidget);

        // Manually swipe backward to Teach1 (page 0) without touching any
        // button — this used to leave state.step stuck at teach2 while the
        // visible page moved to 0.
        await tester.fling(
          find.byType(PageView),
          const Offset(400, 0),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.text('Tap on the number'), findsOneWidget);

        // Tapping Teach1's "Next" should land on Teach2 — not skip straight
        // to Teach3 because state.step was still (incorrectly) teach2.
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard0')),
          matching: find.text('Next'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Mind your life'), findsOneWidget);
        expect(find.text('Three ways it ends'), findsNothing);
      },
    );

    testWidgets(
      '8.1 name-rejected: a profanity match shows the inline error state '
      'without navigating, and "Skip for now" remains a working escape '
      'hatch from it',
      (tester) async {
        final FakeProfileRepository repository = FakeProfileRepository();
        await pumpSplash(
          tester,
          repository: repository,
          clock: FakeMonotonicClock(0),
        );

        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('teachCard0')),
          matching: find.text('Skip'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('What should we call you?'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'badword');
        await tester.tap(find.text('Start playing'));
        await tester.pumpAndSettle();

        // 8.1 state: heading swaps, still on the same screen (no
        // navigation), repository not yet marked complete.
        expect(find.text('Pick another name'), findsOneWidget);
        expect(find.byType(CountdownView), findsNothing);
        expect(repository.isOnboardingComplete, isFalse);
        expect(
          find.textContaining("isn't allowed"),
          findsOneWidget,
        );

        // Re-typing clears the error back to the normal appearance.
        await tester.enterText(find.byType(TextField), 'Aman');
        await tester.pump();
        expect(find.text('What should we call you?'), findsOneWidget);

        // "Skip for now" still escapes even while an error was showing.
        await tester.enterText(find.byType(TextField), 'badword');
        await tester.tap(find.text('Start playing'));
        await tester.pumpAndSettle();
        expect(find.text('Pick another name'), findsOneWidget);

        await tester.tap(find.text('Skip for now'));
        await tester.pumpAndSettle();

        expect(find.byType(CountdownView), findsOneWidget);
        expect(repository.isOnboardingComplete, isTrue);
        expect(repository.name, isNull);
        await drainCountdown(tester);
      },
    );
  });

  group('returning launch (isOnboardingComplete == true)', () {
    testWidgets(
      'Splash routes straight to Play via the temporary Home shim '
      '(app/router.dart) — no onboarding content shown again',
      (tester) async {
        final FakeProfileRepository repository =
            FakeProfileRepository(isOnboardingComplete: true, name: 'Aman');
        await pumpSplash(
          tester,
          repository: repository,
          clock: FakeMonotonicClock(0),
        );

        expect(find.byType(OnboardingFlow), findsNothing);
        expect(find.byType(CountdownView), findsOneWidget);
        await drainCountdown(tester);
      },
    );
  });
}
