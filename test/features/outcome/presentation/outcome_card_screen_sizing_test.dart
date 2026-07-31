import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/application/outcome_story_service.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/presentation/outcome_card_screen.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card.dart';
import 'package:timing_tap/features/outcome/presentation/widgets/outcome_card_shell.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// P0 REGRESSION coverage for the real bug this whole session's "the Outcome
/// card is still too long" feedback traced back to: `OutcomeCardShell`'s
/// `AspectRatio(3/4)` never actually took effect in production, because the
/// real widget tree hands it a TIGHT height constraint (`Expanded` inside
/// `Column`), and `RenderAspectRatio` silently falls back to that tight
/// `minHeight` instead of deriving height from width whenever the ratio-
/// derived height would be less than it — which is *always* true under a
/// tight constraint.
///
/// Deliberately pumps the actual `OutcomeCardScreen` (not `OutcomeCardShell`/
/// `OutcomeCard` in isolation) inside a realistic phone-sized `MaterialApp` —
/// the existing widget-level tests all use a `Center(child: SizedBox(...))`
/// harness that hands `AspectRatio` a LOOSE constraint directly, which is
/// exactly why they never caught this: they never exercised the real
/// `Column > Expanded > Padding` ancestor chain that makes the constraint
/// tight in production.
void main() {
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
    Duration? Function(int, Object)? retry,
  }) {
    return ProviderScope(
      // A fresh `UniqueKey()` per call is load-bearing when a single test
      // calls `harness` more than once (see the pop-on-resolve size
      // comparison below): without it, `pumpWidget`'s tree-diffing sees the
      // same `ProviderScope` type/position across both calls and tries to
      // UPDATE the existing element with a different-length `overrides`
      // list, which Riverpod's `ProviderContainer` explicitly disallows
      // ("Tried to change the number of overrides") — a fresh key forces a
      // real teardown+remount instead.
      key: UniqueKey(),
      overrides: overrides,
      retry: retry,
      child: MaterialApp(home: OutcomeCardScreen(summary: s)),
    );
  }

  /// Common phone size (iPhone 12/13/14-class) — logical 390x844 at a 3.0
  /// device pixel ratio, matching this app's other realistic-screen-size
  /// test harnesses (e.g. `home_avatar_flow_test.dart`).
  void setRealisticScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Size cardBoxSize(WidgetTester tester) =>
      tester.getSize(find.byType(OutcomeCardShell));

  testWidgets(
    'loading state: the rendered OutcomeCardShell box is genuinely 3:4, not '
    "the old ~9:16 phone-screen shape Expanded's tight constraint used to "
    'force it into',
    (tester) async {
      setRealisticScreenSize(tester);
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

      final size = cardBoxSize(tester);
      expect(
        size.width / size.height,
        closeTo(3 / 4, 0.01),
        reason:
            'the loading card must be shaped 3:4, not stretched to whatever height Expanded handed it',
      );

      // Flush the provider's internal min-duration Timer so it doesn't leak
      // past this test.
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'data state: the rendered OutcomeCardShell box is genuinely 3:4',
    (tester) async {
      setRealisticScreenSize(tester);
      final s = summary();
      await tester.pumpWidget(harness(s));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));

      final size = cardBoxSize(tester);
      expect(size.width / size.height, closeTo(3 / 4, 0.01));
    },
  );

  testWidgets(
    'error state (unreachable-by-construction N/A fallback): the rendered '
    'OutcomeCardShell box is genuinely 3:4',
    (tester) async {
      setRealisticScreenSize(tester);
      final s = summary();
      await tester.pumpWidget(
        harness(
          s,
          overrides: [
            outcomeStoryProvider.overrideWith(
              (ref, arg) async => throw Exception('forced error for test'),
            ),
          ],
          retry: (retryCount, error) => null,
        ),
      );
      await tester.pump();
      await tester.pump();

      final size = cardBoxSize(tester);
      expect(size.width / size.height, closeTo(3 / 4, 0.01));
    },
  );

  testWidgets(
    'REGRESSION: loading and data states resolve to the EXACT SAME box size '
    '(within a pixel) — no visible pop-on-resolve size jump. The loading '
    'branch must carry the same 32dp shadow inset the data/error branches '
    'get via _EntranceCard, or the card would visibly shrink/inset the '
    'instant it resolves',
    (tester) async {
      setRealisticScreenSize(tester);

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
      final loadingSize = cardBoxSize(tester);
      await tester.pump(const Duration(seconds: 3));

      await tester.pumpWidget(harness(summary()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      final dataSize = cardBoxSize(tester);

      expect(
        dataSize.width,
        closeTo(loadingSize.width, 1),
        reason:
            'loading and resolved card widths must match — no pop-on-resolve size jump',
      );
      expect(
        dataSize.height,
        closeTo(loadingSize.height, 1),
        reason:
            'loading and resolved card heights must match — no pop-on-resolve size jump',
      );
    },
  );

  testWidgets('REGRESSION: the actual RepaintBoundary Share captures is sized exactly '
      "OutcomeCardShell's own genuinely-3:4 box plus the kOutcomeCardShadowInset "
      'padding on every side — not just the shell measuring right in isolation. '
      'This is the box CardRenderer.renderToFile actually rasterizes into the '
      "shared PNG, so if a future change ever re-broke the shell's real sizing "
      "while leaving OutcomeCardShell's own AspectRatio test passing (e.g. by "
      "reintroducing a tight constraint somewhere between the boundary and the "
      'shell), this is the test that would catch it.', (tester) async {
    setRealisticScreenSize(tester);
    final s = summary();
    await tester.pumpWidget(harness(s));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));

    final shellSize = cardBoxSize(tester);

    // Walk up from the (unique) OutcomeCard element to the nearest actual
    // RepaintBoundary ancestor — the exact one `_EntranceCard` builds
    // around the card, keyed by `_cardKey` and handed to
    // `CardRenderer.renderToFile` on Share. A bare `find.byType` count is
    // unreliable here (MaterialApp's own route machinery also builds
    // ambient RepaintBoundary widgets elsewhere in the tree, per this
    // file's sibling `outcome_card_screen_test.dart`), so this walks
    // ancestors directly instead, exactly like that file's established
    // technique.
    final cardElement = tester.element(find.byType(OutcomeCard));
    Element? repaintElement;
    cardElement.visitAncestorElements((ancestor) {
      if (ancestor.widget.runtimeType == RepaintBoundary) {
        repaintElement = ancestor;
        return false;
      }
      return true;
    });
    expect(
      repaintElement,
      isNotNull,
      reason: 'no RepaintBoundary ancestor found at all',
    );

    final renderObject = repaintElement!.renderObject;
    expect(renderObject, isA<RenderRepaintBoundary>());
    final capturedSize = (renderObject! as RenderRepaintBoundary).size;

    expect(
      capturedSize.width,
      closeTo(shellSize.width + 2 * kOutcomeCardShadowInset, 1),
      reason:
          'the captured box must be exactly the shell width plus the shadow inset on both sides',
    );
    expect(
      capturedSize.height,
      closeTo(shellSize.height + 2 * kOutcomeCardShadowInset, 1),
      reason:
          'the captured box must be exactly the shell height plus the shadow inset on both sides',
    );
    expect(
      capturedSize.width / capturedSize.height,
      isNot(closeTo(3 / 4, 0.01)),
      reason:
          'the captured box (shell + fixed 32dp inset on all sides) is deliberately NOT itself '
          "3:4 — only the shell inside it is; this pins that the inset doesn't happen to "
          'accidentally preserve the ratio, which would mask a shell-only regression',
    );
  });
}

class _NeverCompletingService implements OutcomeStoryService {
  final Completer<OutcomeStoryContent> _completer =
      Completer<OutcomeStoryContent>();

  @override
  Future<OutcomeStoryContent> fetchStory(RunSummary summary) =>
      _completer.future;
}
