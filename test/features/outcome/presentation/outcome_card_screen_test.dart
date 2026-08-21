import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/ads/application/ad_service.dart';
import 'package:timing_tap/features/ads/application/ad_gate.dart';
import 'package:timing_tap/features/ads/presentation/ad_failed_view.dart';
import 'package:timing_tap/features/ads/presentation/interstitial_screen.dart';
import 'package:timing_tap/features/ads/state/ad_providers.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider;
import 'package:timing_tap/features/outcome/application/outcome_story_service.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card_loading.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';

/// Screen-level regression coverage for `OutcomeCardScreen` (architecture v4
/// §4/§6/§8), targeting two of this session's fixes specifically:
///   - Share-gating via the shared `_isSettled()` helper: disabled while
///     `loading`, enabled on `AsyncData`, AND enabled on `AsyncError` (not
///     left permanently disabled behind the unreachable-by-construction
///     error branch).
///   - The `RepaintBoundary`/entrance-animation restructure: the capture
///     boundary must be a DESCENDANT of the `FadeTransition`/
///     `ScaleTransition`, not an ancestor, so an in-flight entrance
///     animation can never be captured mid-fade/scale by `toImage()`.
///
/// Note on ambient noise: `MaterialApp`'s own `Navigator`/route-transition
/// machinery ALSO builds `FadeTransition`/`ScaleTransition`/`RepaintBoundary`
/// widgets for the current route, even with no push in flight — so bare
/// `find.byType(...)` counts on these three types are not reliable signals
/// on their own in this app (confirmed empirically). Tests below either
/// scope to a widget known to be unique to our own subtree (`OutcomeCard`/
/// `OutcomeCardLoading`) or compare *relative nesting order* rather than
/// raw counts, to stay robust to that ambient framework structure.
void main() {
  // Remote-story-config-implementation-spec: `outcomeStoryServiceProvider`'s
  // default is now `RemoteOutcomeStoryService`, which transitively watches
  // `preferencesServiceProvider` (via `storyPoolRepositoryProvider`/
  // `storyCycleStoreProvider`) even for tests that never override the
  // service itself. Without a working override, reading it throws
  // `UnimplementedError` at provider-construction time, which used to
  // manifest here as an immediately-settled `AsyncError` (indistinguishable
  // from a real resolve, since Share-gating treats both as "settled") well
  // before any of this file's timing assertions became meaningful. One
  // shared mock-backed instance for the whole file is enough — none of
  // these tests inspect prefs content, they only need the provider chain to
  // actually run.
  late PreferencesService prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
  });

  RunSummary summaryFor(RunOutcome outcome) {
    return RunSummary(
      outcome: outcome,
      runNumber: 1,
      lifetimeDeaths: 1,
      peakLifePercent: 90,
      minLifePercent: 2,
      perfectCount: 0,
      playerName: 'Aman',
    );
  }

  RunSummary summary() => summaryFor(RunOutcome.death);

  Widget harness(
    RunSummary s, {
    List<Override> overrides = const [],
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      retry: retry,
      child: MaterialApp(home: OutcomeCardScreen(summary: s)),
    );
  }

  /// Same as [harness], but with `MediaQuery.disableAnimations` forced
  /// `true` (OS Reduce Motion) — placed as a direct ancestor of
  /// `OutcomeCardScreen` (inside `MaterialApp`, not outside it) so it's
  /// guaranteed to be the nearest `MediaQuery` the screen's `context` sees,
  /// regardless of whatever ambient `MediaQuery` `MaterialApp`/the test
  /// binding itself provides above it.
  Widget reduceMotionHarness(
    RunSummary s, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OutcomeCardScreen(summary: s),
        ),
      ),
    );
  }

  /// Walks up from the (unique) `OutcomeCard` element and returns the
  /// nearest `RepaintBoundary` ancestor — i.e. the screen's own shareable
  /// capture boundary (`_cardKey`'s `RepaintBoundary`), not any of the
  /// ambient ones `MaterialApp`'s route-transition machinery also builds
  /// further up the tree (see this file's header comment). Mirrors the
  /// existing nesting-order tests' own ancestor-walk technique, just scoped
  /// down to a reusable `Finder` for tests that need to query the
  /// boundary's descendants specifically (e.g. "is X inside the shareable
  /// capture or not").
  Finder cardRepaintBoundaryFinder(WidgetTester tester) {
    final cardElement = tester.element(find.byType(OutcomeCard));
    Element? boundaryElement;
    cardElement.visitAncestorElements((ancestor) {
      if (ancestor.widget is RepaintBoundary) {
        boundaryElement = ancestor;
        return false;
      }
      return true;
    });
    expect(
      boundaryElement,
      isNotNull,
      reason: 'no RepaintBoundary ancestor found for OutcomeCard at all',
    );
    final boundaryWidget = boundaryElement!.widget;
    return find.byWidgetPredicate((widget) => identical(widget, boundaryWidget));
  }

  StickerButton findShareButton(WidgetTester tester) {
    // Death's share label is 'Share' (`_shareButtonStyle`); Eternal's is
    // 'Flex it' — this suite only exercises Death, so match on whichever
    // of the two `_ActionsRow` buttons is NOT 'Again', making it robust to
    // either label without hard-coding it.
    final buttons = tester
        .widgetList<StickerButton>(find.byType(StickerButton))
        .toList();
    return buttons.firstWhere((b) => b.label != 'Again');
  }

  /// Flushes the provider's internal `kMinStoryLoadDuration` (1200ms)
  /// `Future.delayed` `Timer` so a test that deliberately never lets the
  /// overall `Future.wait` resolve (e.g. via a never-completing fake
  /// service) doesn't leave a real (fake-clock) `Timer` pending at test
  /// teardown, which `flutter_test`'s `AutomatedTestWidgetsFlutterBinding`
  /// asserts against. The floor's `Timer` fires and clears itself well
  /// before this; the overall `AsyncValue` correctly stays `loading`
  /// forever regardless, since `Future.wait` still awaits the other
  /// (never-completing) future.
  Future<void> flushMinDurationTimer(WidgetTester tester) {
    return tester.pump(const Duration(seconds: 3));
  }

  testWidgets('Share is disabled while the card is still loading', (
    tester,
  ) async {
    final s = summary();
    await tester.pumpWidget(
      harness(
        s,
        overrides: [
          outcomeStoryServiceProvider.overrideWithValue(
            _NeverCompletingService(),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(OutcomeCardLoading), findsOneWidget);
    final share = findShareButton(tester);
    expect(share.enabled, isFalse);

    await flushMinDurationTimer(tester);
  });

  testWidgets(
    '"Again" stays fully enabled during loading, even though Share is disabled',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(
        harness(
          s,
          overrides: [
            outcomeStoryServiceProvider.overrideWithValue(
              _NeverCompletingService(),
            ),
          ],
        ),
      );
      await tester.pump();

      final again = tester.widget<StickerButton>(
        find.widgetWithText(StickerButton, 'Again'),
      );
      expect(again.enabled, isTrue);

      await flushMinDurationTimer(tester);
    },
  );

  testWidgets('Share becomes enabled once the card resolves to AsyncData', (
    tester,
  ) async {
    final s = summary();
    // Real RemoteOutcomeStoryService (resolving off the bundled asset, no
    // network) + the real kMinStoryLoadDuration (1200ms) provider floor.
    await tester.pumpWidget(harness(s));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      findShareButton(tester).enabled,
      isFalse,
      reason: 'still short of the floor',
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(OutcomeCardLoading), findsNothing);
    expect(findShareButton(tester).enabled, isTrue);
  });

  testWidgets(
    'REGRESSION: Share is ALSO enabled on AsyncError, not left permanently '
    'disabled behind the (unreachable-by-construction) error branch — this '
    "session's _isSettled() fix covers both AsyncData and AsyncError",
    (tester) async {
      final s = summary();
      await tester.pumpWidget(
        harness(
          s,
          overrides: [
            outcomeStoryProvider.overrideWith(
              (ref, arg) async => throw Exception('forced error for test'),
            ),
          ],
          // Riverpod 3's FutureProvider auto-retries on error by default
          // (exponential backoff via a real Timer) — disabling retries here
          // is what actually lets the provider settle into a stable
          // AsyncError instead of looping through AsyncLoading(error: ...)
          // retry states forever, which is what this test needs to reach
          // and pin the _isSettled() Share-gating behavior specifically.
          retry: (retryCount, error) => null,
        ),
      );
      // Let the synchronously-throwing future's error propagate into a
      // settled AsyncError state.
      await tester.pump();
      await tester.pump();

      expect(find.byType(OutcomeCardLoading), findsNothing);
      expect(
        find.byType(OutcomeCard),
        findsOneWidget,
        reason: 'the N/A card renders on AsyncError',
      );

      // Juice spec "actions gate": settling into AsyncError also kicks off
      // the entrance reveal, which locks Share/Again for `_kActionsLockDuration`
      // (300ms) even though the card content itself is already settled — so
      // this test must clear that window too, on top of `_isSettled()`,
      // before Share is genuinely expected to be enabled.
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        findShareButton(tester).enabled,
        isTrue,
        reason:
            'AsyncError must be treated as "settled" for Share-gating, exactly like AsyncData, '
            'once the ~300ms actions-lock window has also cleared',
      );
    },
  );

  for (final outcome in RunOutcome.values) {
    testWidgets(
      'the RepaintBoundary is nested INSIDE the ${outcome.name} entrance '
      "animation's transform (a descendant, not an ancestor) — the "
      'load-bearing part of the fix: an ancestor Opacity/Transform never '
      'affects what a descendant RepaintBoundary.toImage() captures, so '
      'Share always rasterizes the fully-settled card regardless of how far '
      'the entrance animation has progressed. Generalized off '
      '`find.byType(ScaleTransition)` (removed this pass — every outcome now '
      'uses a raw `Transform`, not `ScaleTransition`, for its shake/flip/pop) '
      'to `find.byType(Transform)` instead, checked per-outcome.',
      (tester) async {
        final s = summaryFor(outcome);
        await tester.pumpWidget(harness(s));
        await tester.pump(const Duration(seconds: 2));
        // Resolve, then pump only partway through the entrance animation —
        // deliberately NOT settled, to prove the structural relationship
        // holds even mid-animation (every outcome's entrance duration is
        // >=500ms, so 130ms is comfortably still in-flight for all three).
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 80));

        expect(find.byType(OutcomeCard), findsOneWidget);

        // MaterialApp's own route-transition machinery also builds ambient
        // FadeTransition/Transform/RepaintBoundary widgets elsewhere in the
        // tree (confirmed empirically), so raw type-based counts across the
        // whole tree aren't reliable here. Instead, walk up from the
        // (unique) OutcomeCard element and check the RELATIVE nesting order
        // of the nearest RepaintBoundary/Transform/FadeTransition
        // ancestors — our own entrance structure is always the *nearest*
        // one to OutcomeCard, regardless of what else exists further up the
        // tree.
        final cardElement = tester.element(find.byType(OutcomeCard));
        final ancestorTypes = <Type>[];
        cardElement.visitAncestorElements((ancestor) {
          ancestorTypes.add(ancestor.widget.runtimeType);
          return ancestorTypes.length < 40;
        });

        final repaintIndex = ancestorTypes.indexOf(RepaintBoundary);
        final transformIndex = ancestorTypes.indexOf(Transform);
        final fadeIndex = ancestorTypes.indexOf(FadeTransition);

        expect(
          repaintIndex,
          greaterThanOrEqualTo(0),
          reason: 'no RepaintBoundary ancestor found at all',
        );
        expect(
          transformIndex,
          greaterThanOrEqualTo(0),
          reason:
              'no Transform ancestor found at all — every outcome entrance '
              '(shake/flip/pop) is built from a raw Transform, not ScaleTransition',
        );
        expect(
          fadeIndex,
          greaterThanOrEqualTo(0),
          reason: 'no FadeTransition ancestor found at all',
        );

        expect(
          repaintIndex,
          lessThan(transformIndex),
          reason:
              'RepaintBoundary must be nearer to OutcomeCard than Transform (i.e. a '
              'descendant of it), not the reverse',
        );
        expect(
          transformIndex,
          lessThan(fadeIndex),
          reason:
              'Transform must be nearer to OutcomeCard than FadeTransition, matching the '
              'FadeTransition > AnimatedBuilder > Transform > RepaintBoundary > ...content '
              'nesting order _EntranceCard builds',
        );
      },
    );
  }

  testWidgets(
    'the entrance Transform is never present while the card is still '
    'loading (OutcomeCardLoading has no Transform ancestor) — the entrance '
    'animation only wraps the RESOLVED card, never the loader. Generalized '
    'off `ScaleTransition` (no longer used by any outcome entrance) to '
    '`Transform`.',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(
        harness(
          s,
          overrides: [
            outcomeStoryServiceProvider.overrideWithValue(
              _NeverCompletingService(),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(OutcomeCardLoading), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(OutcomeCardLoading),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await flushMinDurationTimer(tester);
    },
  );

  testWidgets(
    'REGRESSION: _ActionsRow actually passes the grown 52dp height to both '
    'its Share and Again StickerButtons (not the old 44dp) — height only '
    '(design v1 Revision 4 §R4.1): borderRadius/restShadowOffset stay at '
    "the widget's own 14/5 defaults, matching every other button in the app",
    (tester) async {
      final s = summary();
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final buttons = tester.widgetList<StickerButton>(find.byType(StickerButton)).toList();
      expect(buttons.length, 2, reason: 'exactly Share + Again on the resolved card');
      for (final button in buttons) {
        expect(button.height, 52);
        expect(button.borderRadius, 14);
        expect(button.restShadowOffset, 5);
      }
    },
  );

  testWidgets(
    'REGRESSION: only the Share button opts into showTrailingArrow — '
    '"Again" renders with the default (false), unaffected by the arrow slot',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final share = findShareButton(tester);
      final again = tester.widget<StickerButton>(find.widgetWithText(StickerButton, 'Again'));

      expect(share.showTrailingArrow, isTrue);
      expect(again.showTrailingArrow, isFalse);

      // The arrow glyph itself is present exactly once (on Share only).
      expect(find.text('→'), findsOneWidget);
    },
  );

  testWidgets(
    'REGRESSION (code review): Eternal — the shine+sparks fx overlay '
    "(_EternalFxOverlay's sparks CustomPaint) is NEVER a descendant of the "
    "card's own RepaintBoundary — the single most load-bearing invariant in "
    'this file, since anything inside that boundary gets shared as a PNG',
    (tester) async {
      final s = summaryFor(RunOutcome.eternal);
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      // Well inside both the 600ms pop entrance and the 1200ms fx timeline
      // (sparks can start up to 300ms in), so the overlay is guaranteed to
      // actually be mounted and painting by this point.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OutcomeCard), findsOneWidget);

      // Matched by painter type specifically (rather than a bare
      // `find.byType(CustomPaint)`, which could pick up unrelated ambient
      // `CustomPaint`s elsewhere in the tree) so this test unambiguously
      // targets the sparks fx overlay itself.
      final sparksFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_SparksPainter',
      );
      expect(
        sparksFinder,
        findsOneWidget,
        reason:
            'the sparks fx overlay must actually be mounted for this test to be '
            'meaningful — if this fails, the overlay itself regressed, not the '
            'non-descendancy invariant below',
      );

      final boundaryFinder = cardRepaintBoundaryFinder(tester);
      expect(
        find.descendant(of: boundaryFinder, matching: sparksFinder),
        findsNothing,
        reason:
            'the sparks CustomPaint must be a sibling overlay positioned over the '
            "card, never inside the shareable RepaintBoundary — otherwise it'd leak "
            "into Share's toImage() capture",
      );
    },
  );

  testWidgets(
    'REGRESSION: Reduce Motion (MediaQuery.disableAnimations) collapses the '
    'Eternal entrance to a single plain FadeTransition — no Transform '
    '(shake/flip/pop) and no shine/sparks fx overlay at all, not merely a '
    'skipped animation',
    (tester) async {
      final s = summaryFor(RunOutcome.eternal);
      await tester.pumpWidget(reduceMotionHarness(s));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 130));

      expect(find.byType(OutcomeCard), findsOneWidget);

      final cardElement = tester.element(find.byType(OutcomeCard));
      final ancestorTypes = <Type>[];
      cardElement.visitAncestorElements((ancestor) {
        ancestorTypes.add(ancestor.widget.runtimeType);
        return ancestorTypes.length < 40;
      });

      expect(
        ancestorTypes.contains(FadeTransition),
        isTrue,
        reason: 'Reduce Motion still gets a plain fade-in',
      );
      expect(
        ancestorTypes.contains(Transform),
        isFalse,
        reason: 'no pop/shake/flip Transform under Reduce Motion',
      );

      final sparksFinder = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_SparksPainter',
      );
      expect(
        sparksFinder,
        findsNothing,
        reason:
            "the eternal fx overlay (and its AnimationController) must not build "
            'at all under Reduce Motion, not just render invisibly',
      );
    },
  );

  testWidgets(
    'REGRESSION (juice spec actions gate): both Share and Again are '
    'disabled immediately once the card settles, and both re-enable '
    '~300ms later',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(
        harness(
          s,
          overrides: [
            outcomeStoryProvider.overrideWith(
              (ref, arg) async => throw Exception('forced error for test'),
            ),
          ],
          // Settles on the very next couple of pumps (no 1200ms floor to
          // wait out), so the ~300ms actions-lock window can be measured
          // precisely from a known t=0.
          retry: (retryCount, error) => null,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(OutcomeCard), findsOneWidget, reason: 'settled into the N/A card');

      StickerButton again() =>
          tester.widget<StickerButton>(find.widgetWithText(StickerButton, 'Again'));

      expect(
        findShareButton(tester).enabled,
        isFalse,
        reason: 'actions gate locks Share immediately on settle',
      );
      expect(
        again().enabled,
        isFalse,
        reason: 'actions gate locks Again immediately on settle too',
      );

      // Still short of the 300ms lock window.
      await tester.pump(const Duration(milliseconds: 200));
      expect(findShareButton(tester).enabled, isFalse);
      expect(again().enabled, isFalse);

      // Past the 300ms lock window.
      await tester.pump(const Duration(milliseconds: 150));
      expect(findShareButton(tester).enabled, isTrue);
      expect(again().enabled, isTrue);
    },
  );

  testWidgets(
    'DISPOSAL: unmounting the screen ~130ms into an Eternal reveal (mid '
    'actions-lock timer, mid haptic timers, mid fx timeline) cancels every '
    'pending Timer cleanly — flutter_test itself fails this test at '
    'teardown with a "Timer is still pending" error if disposal leaks one, '
    'so simply completing without that error IS the assertion',
    (tester) async {
      final s = summaryFor(RunOutcome.eternal);
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      // Inside the 300ms actions-lock window, inside the eternal haptic
      // timers' 120ms/240ms intervals, and inside several sparks'
      // startDelay windows — maximally many pending Timers in flight at
      // once.
      await tester.pump(const Duration(milliseconds: 130));

      expect(find.byType(OutcomeCard), findsOneWidget);

      // Unmount the whole screen (and thus its State, mid-reveal) while all
      // of the above timers are still pending.
      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
    },
  );

  group('"Again" -> AdService routing (real-ad-serving pass)', () {
    /// Fast-forwards `adGateProvider` to be "due" without relying on 3
    /// separate `OutcomeCardScreen` instances: `OutcomeCardScreen.initState`
    /// itself registers exactly one completed run per mount (via a
    /// post-frame callback), so bumping the counter by 2 more externally,
    /// right after the first pump, lands exactly on the 3rd completed run.
    Future<void> makeInterstitialDue(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OutcomeCardScreen)),
      );
      final gate = container.read(adGateProvider.notifier);
      gate.registerRunCompleted();
      gate.registerRunCompleted();
      expect(gate.isDue, isTrue, reason: '1 (from initState) + 2 more == the 3rd run');
    }

    testWidgets(
      'REGRESSION: when rendersOwnUi is false (a real MAX interstitial '
      'already showed its own native overlay) and the result is shown, '
      '"Again" skips InterstitialScreen entirely and goes straight to '
      'PlayLoopScreen',
      (tester) async {
        final s = summary();
        await tester.pumpWidget(
          harness(
            s,
            overrides: [
              adServiceProvider.overrideWithValue(_RendersOwnUiFalseAdService()),
            ],
          ),
        );
        await tester.pump();
        await makeInterstitialDue(tester);

        // Let the card resolve so "Again" is reachable/tappable.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        // `PlayLoopScreen`'s own countdown (`RunConfig.defaults`:
        // 3 steps * 700ms) schedules a real `Timer` chain on mount
        // (`countdown_view.dart`) — flush it explicitly (mirrors
        // `play_loop_screen_test.dart`'s own `pumpPastCountdown` helper).
        // Deliberately a bounded pump, not `pumpAndSettle()`: once on
        // PlayLoopScreen, `LifeAvatar`'s continuous 60fps wave animation
        // (juice spec effect 1, see `pumpPastCountdown`'s own doc comment
        // in `play_loop_screen_test.dart`) never stops scheduling frames,
        // so `pumpAndSettle()` here would hang until it times out.
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(InterstitialScreen),
          findsNothing,
          reason: 'rendersOwnUi == false must never push this app\'s own interstitial screen',
        );
        expect(find.byType(PlayLoopScreen), findsOneWidget);
      },
    );

    testWidgets(
      'when rendersOwnUi is true (FakeAdService, unchanged pre-existing '
      'behavior) and the result is shown, "Again" still pushes '
      'InterstitialScreen',
      (tester) async {
        final s = summary();
        await tester.pumpWidget(harness(s));
        await tester.pump();
        await makeInterstitialDue(tester);

        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        // Deliberately bounded pumps (not `pumpAndSettle`) here:
        // `InterstitialScreen` auto-advances itself via a real 4s
        // `Timer.periodic` (1 tick/sec), which `pumpAndSettle` would
        // fast-forward straight through (each periodic tick reschedules a
        // frame, so `pumpAndSettle` keeps going until the whole countdown
        // — and its auto-hand-off past this very screen — finishes). A
        // short, fixed pump instead captures the screen mid-display, which
        // is what this test actually needs to assert on.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(InterstitialScreen), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION (fix 9): tapping Home while an "Again" interstitial call '
      'is still in flight is a no-op — without this, the real ad overlay '
      'could land on top of Home once the call resolves and displays, '
      'confusing even though it could never crash (_onAgain\'s own '
      '!mounted check already prevented that)',
      (tester) async {
        final s = summary();
        final adService = _SequencedAdService(rendersOwnUi: false);
        await tester.pumpWidget(
          harness(s, overrides: [adServiceProvider.overrideWithValue(adService)]),
        );
        await tester.pump();
        await makeInterstitialDue(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        expect(adService.callCount, 1, reason: 'the "Again" call is now genuinely in flight');

        // Tap Home while that call is still unresolved.
        await tester.tap(find.text('Home'));
        await tester.pump();

        expect(
          find.byType(OutcomeCardScreen),
          findsOneWidget,
          reason: '_navigating must block Home from popping away mid-call',
        );

        // Resolving the in-flight call afterward still completes
        // normally — proves the guard blocks the tap rather than
        // corrupting `_onAgain`'s own state.
        adService.resolveCall(0, InterstitialResult.shown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(PlayLoopScreen), findsOneWidget);
      },
    );
  });

  group('AdFailedView Retry (real-ad-serving pass review, fix 4)', () {
    Future<void> makeInterstitialDue(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OutcomeCardScreen)),
      );
      final gate = container.read(adGateProvider.notifier);
      gate.registerRunCompleted();
      gate.registerRunCompleted();
      expect(gate.isDue, isTrue, reason: '1 (from initState) + 2 more == the 3rd run');
    }

    testWidgets(
      'REGRESSION: Retry, when it succeeds with rendersOwnUi == false (a '
      'real MAX interstitial that already showed its own native overlay), '
      'goes straight to PlayLoopScreen — mirrors "Again"\'s own routing, not '
      'just the FakeAdService rendersOwnUi == true path',
      (tester) async {
        final s = summary();
        final adService = _SequencedAdService(rendersOwnUi: false);
        await tester.pumpWidget(
          harness(s, overrides: [adServiceProvider.overrideWithValue(adService)]),
        );
        await tester.pump();
        await makeInterstitialDue(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        // "Again"'s first showInterstitial() call fails -> lands on
        // AdFailedView.
        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        adService.resolveCall(0, InterstitialResult.failedToLoad);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AdFailedView), findsOneWidget);

        // Retry's call succeeds.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        adService.resolveCall(1, InterstitialResult.shown);
        // Several smaller pumps (not one large jump, and not
        // `pumpAndSettle()` — `LifeAvatar`'s continuous wave animation on
        // PlayLoopScreen never lets that settle) to reliably drain the
        // resulting pushReplacement's own transition/route-settling steps,
        // mirroring this file's established `pumpPastCountdown`-style
        // approach elsewhere for timer/animation-chained navigation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(InterstitialScreen),
          findsNothing,
          reason: 'rendersOwnUi == false must never push this app\'s own interstitial screen',
        );
        expect(find.byType(PlayLoopScreen), findsOneWidget);
        expect(adService.callCount, 2, reason: 'exactly one "Again" call + one Retry call');
      },
    );

    testWidgets(
      'REGRESSION: a second Retry tap while the first is still in flight is '
      'a no-op — does not start a second overlapping showInterstitial() '
      'call (fix 4\'s single-flight guard, mirroring "Again"\'s own '
      '_navigating guard)',
      (tester) async {
        final s = summary();
        final adService = _SequencedAdService(rendersOwnUi: false);
        await tester.pumpWidget(
          harness(s, overrides: [adServiceProvider.overrideWithValue(adService)]),
        );
        await tester.pump();
        await makeInterstitialDue(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        adService.resolveCall(0, InterstitialResult.failedToLoad);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AdFailedView), findsOneWidget);

        // First Retry tap starts a genuinely in-flight (never-yet-resolved)
        // second showInterstitial() call.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(adService.callCount, 2);

        // A second tap while that call is still pending must be swallowed
        // by the guard, not start a THIRD call.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(
          adService.callCount,
          2,
          reason: 'the guard must ignore a re-entrant tap while a retry is already in flight',
        );

        // Resolving the one genuine in-flight call still completes the
        // flow normally. Bounded pumps, not `pumpAndSettle()` — see the
        // continuous-wave-animation note above.
        adService.resolveCall(1, InterstitialResult.shown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(PlayLoopScreen), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION: the _retrying single-flight guard resets across a fresh '
      '_AdFailedHost instance — TWO consecutive failures (Again, then '
      'Retry) followed by a THIRD attempt still succeeds, rather than the '
      'guard staying permanently tripped',
      (tester) async {
        final s = summary();
        final adService = _SequencedAdService(rendersOwnUi: false);
        await tester.pumpWidget(
          harness(s, overrides: [adServiceProvider.overrideWithValue(adService)]),
        );
        await tester.pump();
        await makeInterstitialDue(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        // Failure #1: "Again" -> AdFailedView (host A).
        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        adService.resolveCall(0, InterstitialResult.failedToLoad);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AdFailedView), findsOneWidget);

        // Failure #2: Retry on host A also fails -> a brand-new
        // _AdFailedHost (host B) replaces it via pushReplacement.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        adService.resolveCall(1, InterstitialResult.failedToLoad);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AdFailedView), findsOneWidget);

        // Attempt #3: Retry on host B (a fresh State with its own
        // `_retrying = false`) must still be tappable and succeed — proves
        // the guard never permanently wedges Retry after repeated failures.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(adService.callCount, 3, reason: 'the third genuine tap must reach the service');
        // Bounded pumps, not `pumpAndSettle()` — see the continuous-wave
        // -animation note above.
        adService.resolveCall(2, InterstitialResult.shown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(PlayLoopScreen), findsOneWidget);
      },
    );

    testWidgets(
      'REGRESSION (fix 9): tapping "Maybe later" while a Retry call is '
      'still in flight is a no-op — without this, PlayLoopScreen would be '
      'armed (countdown/haptics started) and then have the real ad land on '
      'top of the run once the in-flight call resolves and displays',
      (tester) async {
        final s = summary();
        final adService = _SequencedAdService(rendersOwnUi: false);
        await tester.pumpWidget(
          harness(s, overrides: [adServiceProvider.overrideWithValue(adService)]),
        );
        await tester.pump();
        await makeInterstitialDue(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 100));

        // "Again"'s first call fails -> AdFailedView.
        await tester.tap(find.widgetWithText(StickerButton, 'Again'));
        await tester.pump();
        adService.resolveCall(0, InterstitialResult.failedToLoad);
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AdFailedView), findsOneWidget);

        // Retry starts a genuinely in-flight second call.
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(adService.callCount, 2);

        // "Maybe later" tapped while that call is still pending must be a
        // no-op, not navigate to PlayLoopScreen.
        await tester.tap(find.text('Maybe later'));
        await tester.pump();
        expect(
          find.byType(PlayLoopScreen),
          findsNothing,
          reason: 'the _retrying guard must block "Maybe later" while Retry is in flight',
        );
        expect(find.byType(AdFailedView), findsOneWidget);

        // Resolving the in-flight call afterward still completes normally.
        adService.resolveCall(1, InterstitialResult.shown);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 2200));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(PlayLoopScreen), findsOneWidget);
      },
    );
  });
}

/// Minimal `AdService` test double exercising the `rendersOwnUi == false`
/// branch (a real MAX interstitial's SDK-owned native overlay) without any
/// dependency on the real `applovin_max` plugin/platform channel.
class _RendersOwnUiFalseAdService implements AdService {
  @override
  bool get rendersOwnUi => false;

  @override
  Future<InterstitialResult> showInterstitial() async => InterstitialResult.shown;

  @override
  Future<RewardedResult> showRewarded() async => RewardedResult.failedToLoad;
}

/// `AdService` test double whose `showInterstitial()` calls resolve only
/// when the test explicitly tells them to (`resolveCall`) — unlike
/// `FakeAdService`'s near-instant resolve, this lets a test hold a call
/// genuinely "in flight" across a real await gap, which is what's needed to
/// exercise the single-flight Retry guard (fix 4) and the
/// `rendersOwnUi`-branch routing together.
class _SequencedAdService implements AdService {
  _SequencedAdService({required this.rendersOwnUi});

  @override
  final bool rendersOwnUi;

  int callCount = 0;
  final List<Completer<InterstitialResult>> _completers = [];

  @override
  Future<InterstitialResult> showInterstitial() {
    callCount++;
    final completer = Completer<InterstitialResult>();
    _completers.add(completer);
    return completer.future;
  }

  /// Resolves the [index]th `showInterstitial()` call (0-based, in call
  /// order) with [result].
  void resolveCall(int index, InterstitialResult result) {
    _completers[index].complete(result);
  }

  @override
  Future<RewardedResult> showRewarded() async => RewardedResult.failedToLoad;
}

class _NeverCompletingService implements OutcomeStoryService {
  final Completer<OutcomeStoryContent> _completer =
      Completer<OutcomeStoryContent>();

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) =>
      _completer.future;
}
