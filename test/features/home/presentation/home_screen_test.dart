import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_route_observer.dart';
import 'package:timing_tap/features/ads/presentation/banner_ad_slot.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/home/presentation/widgets/streak_advanced_overlay.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';
import 'package:timing_tap/features/progression/domain/streak_calculator.dart';
import 'package:timing_tap/features/progression/state/stats_providers.dart';

/// `HomeScreen`'s `RouteAware` wiring (architecture v3 §6, the most serious
/// bug found and fixed this session): Home is reached via `pushReplacement`
/// chains that never pop it off the Navigator, so it sits mounted-but-
/// offscreen while covered by Play/Outcome/Settings/Stats. These tests
/// exercise the real `RouteObserver`/`didPushNext`/`didPopNext` mechanism —
/// not just the plain `mounted` flag a build-only check would use — by
/// actually pushing/popping a covering route on top of `HomeScreen` in a
/// real `Navigator`.
void main() {
  final calculator = const StreakCalculator();

  Future<ProviderContainer> buildEnvironment(WidgetTester tester, {
    required int streakCurrent,
    required int streakLastPlayDayOffsetFromToday,
  }) async {
    final today = calculator.today();
    SharedPreferences.setMockInitialValues({
      kKeyStreakCurrent: streakCurrent,
      kKeyStreakBest: streakCurrent,
      kKeyStreakLastPlayDay: today + streakLastPlayDayOffsetFromToday,
      // Neutralize the in-context reminder-opt-in push entirely so it can
      // never interfere with the navigation this test drives directly.
      kKeyReminderOptInShown: true,
    });
    final service = await PreferencesService.create();
    final container = ProviderContainer(
      overrides: [preferencesServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void pushCoveringRoute(WidgetTester tester) {
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _CoveringScreen()),
    );
  }

  Future<void> registerAdvancingRun(ProviderContainer container) async {
    await container.read(statsProvider.notifier).registerRunCompletion(
      const RunSummary(
        outcome: RunOutcome.survived,
        runNumber: 2,
        lifetimeDeaths: 0,
        peakLifePercent: 50,
        minLifePercent: 50,
        perfectCount: 0,
        playerName: '',
      ),
    );
  }

  testWidgets(
    'REGRESSION: a run completing (justAdvanced -> true) while Home is '
    'covered by another route does not get cleared before it is ever '
    'shown — popping back to Home still shows the celebration',
    (tester) async {
      final container = await buildEnvironment(
        tester,
        streakCurrent: 1,
        streakLastPlayDayOffsetFromToday: -1, // played yesterday
      );

      // Home is visible and normal (not yet celebrating).
      expect(find.byType(StreakAdvancedView), findsNothing);

      // Cover Home with another route, the same shape as the real
      // Play -> Outcome flow that never pops Home off the stack.
      pushCoveringRoute(tester);
      await tester.pumpAndSettle();
      expect(find.byType(_CoveringScreen), findsOneWidget);

      // A run completes while Home is hidden underneath. This flips
      // justAdvanced -> true via a real streak-advance (gap == 1 day).
      await registerAdvancingRun(container);
      await tester.pump();

      // Pop back to Home (didPopNext fires).
      Navigator.of(tester.element(find.byType(_CoveringScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(_CoveringScreen), findsNothing);
      expect(
        find.byType(StreakAdvancedView),
        findsOneWidget,
        reason: 'the old buggy behavior cleared justAdvanced from an '
            'offscreen rebuild before the player ever saw it; the '
            'RouteAware fix must not do that',
      );
    },
  );

  testWidgets(
    'a celebration already visible on Home is cleared once Home is '
    'covered (didPushNext) — it does not reappear a second time when '
    'Home becomes visible again',
    (tester) async {
      final container = await buildEnvironment(
        tester,
        streakCurrent: 1,
        streakLastPlayDayOffsetFromToday: -1,
      );

      // Advance the streak while Home is still the visible, current route.
      await registerAdvancingRun(container);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byType(StreakAdvancedView),
        findsOneWidget,
        reason: 'the celebration must show immediately while Home is visible',
      );

      // Cover Home (didPushNext) -- per the fix, this is the one point that
      // clears the transient flag, since the celebration has already had
      // its moment on screen.
      pushCoveringRoute(tester);
      await tester.pumpAndSettle();

      // Pop back (didPopNext) -- Home is visible again.
      Navigator.of(tester.element(find.byType(_CoveringScreen))).pop();
      await tester.pumpAndSettle();

      expect(
        find.byType(StreakAdvancedView),
        findsNothing,
        reason: 'display-once semantics: the celebration must not repeat '
            'once it has already been shown and Home was covered/uncovered',
      );
    },
  );

  testWidgets(
    'REGRESSION: BannerAdSlot.isVisible tracks HomeScreen\'s own RouteAware '
    'visibility — true while Home is the current route, false while '
    'covered, true again once popped back to, surviving rapid '
    'cover/uncover cycles without crashing',
    (tester) async {
      await buildEnvironment(
        tester,
        streakCurrent: 1,
        streakLastPlayDayOffsetFromToday: -1,
      );

      // `skipOffstage: false` — once covered by another route, HomeScreen's
      // subtree (BannerAdSlot included) stays mounted-but-unpainted rather
      // than disposed (`MaterialPageRoute.maintainState` default), and the
      // default finder's `skipOffstage: true` would otherwise treat that as
      // "not found" and throw, rather than actually reading its (correctly
      // updated) `isVisible` value.
      bool slotVisible() => tester
          .widget<BannerAdSlot>(find.byType(BannerAdSlot, skipOffstage: false))
          .isVisible;

      expect(slotVisible(), isTrue, reason: 'Home is the current, visible route on first build');

      // Quick navigation in/out, repeated, mirroring a player rapidly
      // opening/closing Settings from Home.
      for (var i = 0; i < 3; i++) {
        pushCoveringRoute(tester);
        await tester.pumpAndSettle();
        expect(find.byType(_CoveringScreen), findsOneWidget);
        expect(slotVisible(), isFalse, reason: 'didPushNext must flip isVisible false while Home is covered');

        Navigator.of(tester.element(find.byType(_CoveringScreen))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(_CoveringScreen), findsNothing);
        expect(slotVisible(), isTrue, reason: 'didPopNext must flip isVisible back true once Home is visible again');
      }
    },
  );
}

class _CoveringScreen extends StatelessWidget {
  const _CoveringScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('covering route')));
  }
}
