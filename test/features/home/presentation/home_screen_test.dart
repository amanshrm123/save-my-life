import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/routing/app_route_observer.dart';
import 'package:timing_tap/core/routing/app_routes.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/ads/presentation/banner_ad_slot.dart';
import 'package:timing_tap/features/home/presentation/home_screen.dart';
import 'package:timing_tap/features/home/presentation/widgets/streak_advanced_overlay.dart';
import 'package:timing_tap/features/home/presentation/widgets/streak_broken_view.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';
import 'package:timing_tap/features/progression/domain/streak_calculator.dart';
import 'package:timing_tap/features/progression/state/stats_providers.dart';
import 'package:timing_tap/features/tour/data/tour_repository.dart';
import 'package:timing_tap/features/tour/presentation/widgets/tour_overlay.dart';
import 'package:timing_tap/features/tour/state/tour_providers.dart';

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

  Future<ProviderContainer> buildEnvironment(
    WidgetTester tester, {
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _CoveringScreen()));
  }

  Future<void> registerAdvancingRun(ProviderContainer container) async {
    await container
        .read(statsProvider.notifier)
        .registerRunCompletion(
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
        reason:
            'the old buggy behavior cleared justAdvanced from an '
            'offscreen rebuild before the player ever saw it; the '
            'RouteAware fix must not do that',
      );
    },
  );

  testWidgets('a celebration already visible on Home is cleared once Home is '
      'covered (didPushNext) — it does not reappear a second time when '
      'Home becomes visible again', (tester) async {
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
      reason:
          'display-once semantics: the celebration must not repeat '
          'once it has already been shown and Home was covered/uncovered',
    );
  });

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

      expect(
        slotVisible(),
        isTrue,
        reason: 'Home is the current, visible route on first build',
      );

      // Quick navigation in/out, repeated, mirroring a player rapidly
      // opening/closing Settings from Home.
      for (var i = 0; i < 3; i++) {
        pushCoveringRoute(tester);
        await tester.pumpAndSettle();
        expect(find.byType(_CoveringScreen), findsOneWidget);
        expect(
          slotVisible(),
          isFalse,
          reason: 'didPushNext must flip isVisible false while Home is covered',
        );

        Navigator.of(tester.element(find.byType(_CoveringScreen))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(_CoveringScreen), findsNothing);
        expect(
          slotVisible(),
          isTrue,
          reason:
              'didPopNext must flip isVisible back true once Home is visible again',
        );
      }
    },
  );
  group('onboarding-tour v1 §2/§4/§9 — the Home dashboard first-time tour', () {
    /// Same shape as `buildEnvironment` above, plus the tour's own prefs
    /// keys and a `routes` table so Home's real `pushNamed` calls (Play,
    /// Settings, the reminder opt-in) resolve to inert stubs instead of
    /// throwing, so navigation attempts are directly observable.
    Future<ProviderContainer> buildTourEnvironment(
      WidgetTester tester, {
      required int totalRunsPlayed,
      required bool homeTourShown,
      int streakCurrent = 0,
      int streakLastPlayDayOffsetFromToday = 0,
      bool reminderOptInShown = true,
      bool reminderEnabled = false,
      List<Override> extraOverrides = const [],
    }) async {
      final today = calculator.today();
      SharedPreferences.setMockInitialValues({
        kKeyTotalRunsPlayed: totalRunsPlayed,
        kKeyHomeTourShown: homeTourShown,
        kKeyStreakCurrent: streakCurrent,
        kKeyStreakBest: streakCurrent,
        kKeyStreakLastPlayDay: today + streakLastPlayDayOffsetFromToday,
        kKeyReminderOptInShown: reminderOptInShown,
        kKeyReminderEnabled: reminderEnabled,
      });
      final service = await PreferencesService.create();
      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(service),
          ...extraOverrides,
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorObservers: [appRouteObserver],
            home: const HomeScreen(),
            routes: {
              AppRoutes.play: (_) => const _RouteStub('play'),
              AppRoutes.settings: (_) => const _RouteStub('settings'),
              AppRoutes.reminderOptIn: (_) =>
                  const _RouteStub('reminder-opt-in'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets(
      'does not start when totalRunsPlayed == 0, even with the flag false',
      (tester) async {
        await buildTourEnvironment(
          tester,
          totalRunsPlayed: 0,
          homeTourShown: false,
        );

        expect(find.byType(TourOverlay), findsNothing);
      },
    );

    testWidgets(
      'starts at step 1 when totalRunsPlayed >= 1 and the flag is false, '
      'and writes home_tour_shown exactly once',
      (tester) async {
        final fakeRepo = _RecordingTourRepository();
        await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
          extraOverrides: [tourRepositoryProvider.overrideWithValue(fakeRepo)],
        );

        expect(find.byType(TourOverlay), findsOneWidget);
        expect(find.text('Keep your streak'), findsOneWidget);
        expect(fakeRepo.markShownCallCount, 1);
      },
    );

    testWidgets('does not start when the flag is already true', (tester) async {
      await buildTourEnvironment(
        tester,
        totalRunsPlayed: 5,
        homeTourShown: true,
      );

      expect(find.byType(TourOverlay), findsNothing);
    });

    testWidgets(
      'tapping the scrim advances 1 -> 2 -> 3 -> 4; "Got it" on step 4 '
      'dismisses; the flag stays true',
      (tester) async {
        final container = await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
        );

        expect(find.text('Keep your streak'), findsOneWidget);

        // A corner point far from the coach card/cutout on every step.
        const scrimPoint = Offset(10, 10);

        await tester.tapAt(scrimPoint);
        await tester.pumpAndSettle();
        expect(find.text('Your record'), findsOneWidget);

        await tester.tapAt(scrimPoint);
        await tester.pumpAndSettle();
        expect(find.text('This is you'), findsOneWidget);

        await tester.tapAt(scrimPoint);
        await tester.pumpAndSettle();
        expect(find.text('Everything else'), findsOneWidget);
        expect(find.text('Got it'), findsOneWidget);

        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        expect(find.byType(TourOverlay), findsNothing);
        expect(
          container.read(preferencesServiceProvider).homeTourShown,
          isTrue,
        );
      },
    );

    testWidgets(
      '"Skip the tour" on step 1 dismisses immediately; the flag is true',
      (tester) async {
        final container = await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
        );

        expect(find.text('Skip the tour'), findsOneWidget);
        await tester.tap(find.text('Skip the tour'));
        await tester.pumpAndSettle();

        expect(find.byType(TourOverlay), findsNothing);
        expect(
          container.read(preferencesServiceProvider).homeTourShown,
          isTrue,
        );
      },
    );

    testWidgets(
      'blocks interaction with the live UI underneath -- tapping at the '
      'Play button\'s own location does not navigate to /play',
      (tester) async {
        await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
        );

        final playCenter = tester.getCenter(
          find.widgetWithText(StickerButton, 'Play'),
        );
        await tester.tapAt(playCenter);
        await tester.pumpAndSettle();

        expect(find.byType(_RouteStub), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets('the back button dismisses the tour and does not pop Home', (
      tester,
    ) async {
      await buildTourEnvironment(
        tester,
        totalRunsPlayed: 1,
        homeTourShown: false,
      );

      expect(find.byType(TourOverlay), findsOneWidget);

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        popped,
        isTrue,
        reason: 'PopScope handled it -- Home itself never saw a real pop',
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(TourOverlay), findsNothing);
    });

    testWidgets(
      'justAdvanced == true hides the tour (and tears it down if it was '
      'already showing) -- the celebration replaces the body wholesale',
      (tester) async {
        final container = await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
          streakCurrent: 1,
          streakLastPlayDayOffsetFromToday:
              -1, // played yesterday -- next play advances
        );

        expect(
          find.byType(TourOverlay),
          findsOneWidget,
          reason: 'sanity: the tour starts normally first',
        );

        await container
            .read(statsProvider.notifier)
            .registerRunCompletion(
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
        await tester.pumpAndSettle();

        expect(find.byType(TourOverlay), findsNothing);
        expect(find.byType(StreakAdvancedView), findsOneWidget);
      },
    );

    testWidgets(
      'streak-broken at open hides the tour -- nothing to spotlight',
      (tester) async {
        await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
          streakCurrent: 3,
          streakLastPlayDayOffsetFromToday: -3, // 3 days ago -- broken
        );

        expect(find.byType(TourOverlay), findsNothing);
        expect(find.byType(StreakBrokenView), findsOneWidget);
      },
    );

    testWidgets(
      'when the tour and the reminder-prompt are both eligible in the same '
      'frame, the tour shows and the reminder opt-in is not pushed (§2.2)',
      (tester) async {
        await buildTourEnvironment(
          tester,
          totalRunsPlayed: 1,
          homeTourShown: false,
          streakCurrent: 2,
          reminderOptInShown: false,
          reminderEnabled: false,
        );

        expect(find.byType(TourOverlay), findsOneWidget);
        expect(
          find.byType(_RouteStub),
          findsNothing,
          reason:
              'the reminder opt-in route must not have been pushed this pass',
        );
      },
    );

    testWidgets(
      'a pending replay request (Settings\' "Replay tour") starts the tour '
      'on didPopNext even with home_tour_shown already true and zero runs '
      'played',
      (tester) async {
        final container = await buildTourEnvironment(
          tester,
          totalRunsPlayed: 0,
          homeTourShown: true,
        );
        expect(find.byType(TourOverlay), findsNothing);

        pushCoveringRoute(tester);
        await tester.pumpAndSettle();

        container.read(pendingHomeTourProvider.notifier).state = true;

        Navigator.of(tester.element(find.byType(_CoveringScreen))).pop();
        await tester.pumpAndSettle();

        expect(find.byType(TourOverlay), findsOneWidget);
        expect(
          container.read(pendingHomeTourProvider),
          isFalse,
          reason: 'the transient replay request is consumed immediately',
        );
      },
    );
  });

  group('onboarding-tour v1 §5.1/§10 — resolveTourTargetRect', () {
    testWidgets('a null key resolves to null', (tester) async {
      expect(resolveTourTargetRect(null), isNull);
    });

    testWidgets(
      'a key never attached to anything in the current tree resolves to null',
      (tester) async {
        final key = GlobalKey();

        expect(resolveTourTargetRect(key), isNull);
      },
    );

    testWidgets('a key attached to a zero-size box resolves to null', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SizedBox.shrink(key: key)),
        ),
      );

      expect(resolveTourTargetRect(key), isNull);
    });

    testWidgets(
      'a key attached to a laid-out, non-zero box resolves to its global rect',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(key: key, width: 40, height: 20),
              ),
            ),
          ),
        );

        final rect = resolveTourTargetRect(key);

        expect(rect, isNotNull);
        expect(rect!.width, 40);
        expect(rect.height, 20);
      },
    );
  });
}

/// A stand-in for `TourRepository` that records how many times `markShown`
/// is called, so "written exactly once" is a real assertion rather than an
/// inference from `homeTourShown`'s final value.
class _RecordingTourRepository implements TourRepository {
  bool _shown = false;
  int markShownCallCount = 0;

  @override
  bool get shown => _shown;

  @override
  Future<void> markShown() async {
    markShownCallCount++;
    _shown = true;
  }
}

class _RouteStub extends StatelessWidget {
  const _RouteStub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('stub:$label')));
  }
}

class _CoveringScreen extends StatelessWidget {
  const _CoveringScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('covering route')));
  }
}
