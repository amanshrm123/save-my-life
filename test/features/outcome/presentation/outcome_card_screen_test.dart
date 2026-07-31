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

  RunSummary summary() {
    return RunSummary(
      outcome: RunOutcome.death,
      runNumber: 1,
      lifetimeDeaths: 1,
      peakLifePercent: 90,
      minLifePercent: 2,
      perfectCount: 0,
      playerName: 'Aman',
    );
  }

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
      expect(
        findShareButton(tester).enabled,
        isTrue,
        reason:
            'AsyncError must be treated as "settled" for Share-gating, exactly like AsyncData',
      );
    },
  );

  testWidgets(
    'the RepaintBoundary is nested INSIDE the FadeTransition/ScaleTransition '
    'entrance animation (a descendant, not an ancestor) — the load-bearing '
    'part of the fix: an ancestor Opacity/Transform never affects what a '
    'descendant RepaintBoundary.toImage() captures, so Share always '
    'rasterizes the fully-settled card regardless of how far the entrance '
    'animation has progressed',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      // Resolve, then pump only partway through the 260ms entrance
      // animation — deliberately NOT settled, to prove the structural
      // relationship holds even mid-animation.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 80));

      expect(find.byType(OutcomeCard), findsOneWidget);

      // MaterialApp's own route-transition machinery also builds ambient
      // FadeTransition/ScaleTransition/RepaintBoundary widgets elsewhere in
      // the tree (confirmed empirically), so raw type-based counts across
      // the whole tree aren't reliable here. Instead, walk up from the
      // (unique) OutcomeCard element and check the RELATIVE nesting order
      // of the nearest RepaintBoundary/ScaleTransition/FadeTransition
      // ancestors — our own entrance structure is always the *nearest* one
      // to OutcomeCard, regardless of what else exists further up the tree.
      final cardElement = tester.element(find.byType(OutcomeCard));
      final ancestorTypes = <Type>[];
      cardElement.visitAncestorElements((ancestor) {
        ancestorTypes.add(ancestor.widget.runtimeType);
        return ancestorTypes.length < 40;
      });

      final repaintIndex = ancestorTypes.indexOf(RepaintBoundary);
      final scaleIndex = ancestorTypes.indexOf(ScaleTransition);
      final fadeIndex = ancestorTypes.indexOf(FadeTransition);

      expect(
        repaintIndex,
        greaterThanOrEqualTo(0),
        reason: 'no RepaintBoundary ancestor found at all',
      );
      expect(
        scaleIndex,
        greaterThanOrEqualTo(0),
        reason: 'no ScaleTransition ancestor found at all',
      );
      expect(
        fadeIndex,
        greaterThanOrEqualTo(0),
        reason: 'no FadeTransition ancestor found at all',
      );

      expect(
        repaintIndex,
        lessThan(scaleIndex),
        reason:
            'RepaintBoundary must be nearer to OutcomeCard than ScaleTransition (i.e. a '
            'descendant of it), not the reverse',
      );
      expect(
        scaleIndex,
        lessThan(fadeIndex),
        reason:
            'ScaleTransition must be nearer to OutcomeCard than FadeTransition, matching the '
            'exact FadeTransition > ScaleTransition > RepaintBoundary > ...content nesting order '
            '_EntranceCard builds',
      );
    },
  );

  testWidgets(
    'the entrance ScaleTransition is never present while the card is still '
    'loading (OutcomeCardLoading has no ScaleTransition ancestor) — the '
    'entrance animation only wraps the RESOLVED card, never the loader',
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
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );

      await flushMinDurationTimer(tester);
    },
  );

  testWidgets(
    'REGRESSION: _ActionsRow actually passes the grown 44dp height to both '
    'its Share and Again StickerButtons (not the old 40dp)',
    (tester) async {
      final s = summary();
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final buttons = tester.widgetList<StickerButton>(find.byType(StickerButton)).toList();
      expect(buttons.length, 2, reason: 'exactly Share + Again on the resolved card');
      for (final button in buttons) {
        expect(button.height, 44);
        expect(button.height, isNot(40));
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
}

class _NeverCompletingService implements OutcomeStoryService {
  final Completer<OutcomeStoryContent> _completer =
      Completer<OutcomeStoryContent>();

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) =>
      _completer.future;
}
