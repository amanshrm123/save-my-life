import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
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
}

class _NeverCompletingService implements OutcomeStoryService {
  final Completer<OutcomeStoryContent> _completer =
      Completer<OutcomeStoryContent>();

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) =>
      _completer.future;
}
