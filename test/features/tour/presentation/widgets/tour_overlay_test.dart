import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/tour/domain/tour_step.dart';
import 'package:timing_tap/features/tour/presentation/widgets/coach_mark_card.dart';
import 'package:timing_tap/features/tour/presentation/widgets/tour_overlay.dart';

/// `TourOverlay` (design v1 §3/§4): the full-screen scrim + coach mark. Home
/// itself (measuring/converting rects, wiring the real advance/skip/dismiss
/// handlers) is covered end-to-end in `home_screen_test.dart`; these tests
/// only exercise the overlay's own interaction/placement contract in
/// isolation, given an already-resolved local `targetRect`.
void main() {
  // §3.1's 8dp cutout inflate -- a stable, spec-pinned constant, safe to
  // hardcode here the same way the widget itself does.
  const cutoutInflate = 8.0;
  const screenSize = Size(400, 800);

  Widget harness({
    required Rect? targetRect,
    required VoidCallback onAdvance,
    required VoidCallback onSkip,
    int stepIndex = 0,
    bool closing = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            TourOverlay(
              step: kHomeTourSteps[stepIndex],
              stepIndex: stepIndex,
              stepCount: kHomeTourSteps.length,
              targetRect: targetRect,
              closing: closing,
              onAdvance: onAdvance,
              onSkip: onSkip,
              onDismissed: () {},
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = screenSize;
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('tapping the scrim calls onAdvance', (tester) async {
    var advanced = false;
    await tester.pumpWidget(
      harness(
        targetRect: const Rect.fromLTWH(20, 20, 100, 60),
        onAdvance: () => advanced = true,
        onSkip: () {},
      ),
    );
    await tester.pump();

    // Tap somewhere clearly on the scrim, away from the coach card/cutout.
    await tester.tapAt(const Offset(300, 700));

    expect(advanced, isTrue);
  });

  testWidgets('tapping "Skip the tour" calls onSkip, not onAdvance', (
    tester,
  ) async {
    var advanced = false;
    var skipped = false;
    await tester.pumpWidget(
      harness(
        targetRect: const Rect.fromLTWH(20, 20, 100, 60),
        onAdvance: () => advanced = true,
        onSkip: () => skipped = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Skip the tour'));

    expect(skipped, isTrue);
    expect(advanced, isFalse);
  });

  testWidgets('with a null targetRect, renders a plain scrim with no coach '
      'mark yet, and still absorbs taps', (tester) async {
    var advanced = false;
    await tester.pumpWidget(
      harness(
        targetRect: null,
        onAdvance: () => advanced = true,
        onSkip: () {},
      ),
    );
    await tester.pump();

    expect(find.byType(CoachMarkCard), findsNothing);

    await tester.tapAt(const Offset(50, 50));
    expect(advanced, isTrue);
  });

  testWidgets('places the coach mark below the cutout when its bottom edge '
      'is in the top 55% of the screen', (tester) async {
    const targetRect = Rect.fromLTWH(20, 20, 100, 40); // near the top

    await tester.pumpWidget(
      harness(targetRect: targetRect, onAdvance: () {}, onSkip: () {}),
    );
    await tester.pump();

    final cardTop = tester.getTopLeft(find.byType(CoachMarkCard)).dy;
    final cutoutBottom = targetRect.bottom + cutoutInflate;
    expect(cardTop, greaterThanOrEqualTo(cutoutBottom));
  });

  testWidgets(
    'REGRESSION (code-reviewer finding #1): a dismiss requested before the '
    'overlay has finished appearing still calls onDismissed, rather than '
    'permanently soft-locking Home',
    (tester) async {
      var dismissed = false;
      // Deliberately closing: false on the very first pump, then flipping
      // to closing: true on the very next pumpWidget call WITHOUT an
      // intervening tester.pump() -- this reproduces the exact race
      // (Home's own post-frame remeasure callback requesting a dismiss in
      // the same frame batch as this widget's own initState "appeared"
      // callback) that used to leave AnimatedOpacity's target unchanged
      // (0.0 -> 0.0) across the update, so its onEnd never fired.
      await tester.pumpWidget(
        harness(
          targetRect: const Rect.fromLTWH(20, 20, 100, 60),
          onAdvance: () {},
          onSkip: () {},
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TourOverlay(
                  step: kHomeTourSteps[0],
                  stepIndex: 0,
                  stepCount: kHomeTourSteps.length,
                  targetRect: const Rect.fromLTWH(20, 20, 100, 60),
                  closing: true,
                  onAdvance: () {},
                  onSkip: () {},
                  onDismissed: () => dismissed = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Let the fallback's post-frame callback run. No fixed-duration
      // AnimatedOpacity animation should be needed at all here -- if it
      // were, this bounded pump wouldn't be enough to observe it.
      await tester.pump();

      expect(
        dismissed,
        isTrue,
        reason:
            'onDismissed must fire even when the overlay never had a '
            'real appeared -> closing opacity transition to animate',
      );
    },
  );

  testWidgets('places the coach mark above the cutout when its bottom edge '
      'is past the top 55% of the screen', (tester) async {
    // A target low enough on screen that its (inflated) cutout bottom sits
    // past 55% of the (fixed, 800dp-tall) screen height.
    const targetRect = Rect.fromLTWH(20, 700, 100, 60);

    await tester.pumpWidget(
      harness(targetRect: targetRect, onAdvance: () {}, onSkip: () {}),
    );
    await tester.pump();

    final cardBottom = tester.getBottomLeft(find.byType(CoachMarkCard)).dy;
    final cutoutTop = targetRect.top - cutoutInflate;
    expect(cardBottom, lessThanOrEqualTo(cutoutTop));
  });
}
