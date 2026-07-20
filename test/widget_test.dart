// Widget-level tests for the Days 1-2 walking skeleton Play screen
// (docs/design/play-screen-skeleton-v1.md).
//
// The first test is the original smoke test (four zones render). The rest
// drive the *real* `PlayScreen` — real `TapSurface`/`Listener`, real
// `RunController`, real `resolve()` — through actual simulated pointer
// events (`tester.tap` / `tester.startGesture`, which both dispatch genuine
// `PointerDownEvent`s through Flutter's hit-test + pointer-router pipeline,
// landing on `TapSurface`'s `Listener.onPointerDown` exactly as a real touch
// would — no shortcut that calls `RunController.registerTap()` directly).
//
// To make this deterministic (the production clock is a live `Stopwatch`,
// and target durations are randomized across 3-20 *real* seconds — not
// something a test should sit and wait for), we replace `App()`'s baked-in
// `ProviderScope` with our own `ProviderContainer`/`UncontrolledProviderScope`
// where `clockProvider` is overridden with a `FakeMonotonicClock`
// (test/support/fake_monotonic_clock.dart). This is exactly the seam
// architecture v1 §1.3 calls out Riverpod for: "mock the clock ... in
// tests." Everything downstream of the clock (TapSurface, RunController,
// resolve(), PlayScreen's text) is exercised unmodified.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/app/app.dart';
import 'package:timing_tap/features/run/run_controller.dart';
import 'package:timing_tap/features/timing_engine/tap_surface.dart';

import 'support/fake_monotonic_clock.dart';

void main() {
  testWidgets('Play screen renders the four zones', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.textContaining('LIFE:'), findsOneWidget);
    expect(find.textContaining('TARGET:'), findsOneWidget);
    expect(find.textContaining('DELTA:'), findsOneWidget);
    expect(find.textContaining('BAND:'), findsOneWidget);
    expect(find.text('TAP'), findsOneWidget);
  });

  group('PlayScreen end-to-end tap flow (real Listener.onPointerDown path)', () {
    late FakeMonotonicClock clock;
    late ProviderContainer container;

    setUp(() {
      clock = FakeMonotonicClock(0);
      container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(clock)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pump();
    }

    /// Positions the fake clock so that a tap *right now* lands
    /// [deltaMicros] away from the current round's target, then dispatches
    /// a real simulated pointer-down/up through `TapSurface`'s `Listener`,
    /// then pumps a frame so the rebuilt text reflects the new state.
    Future<void> tapAtDelta(WidgetTester tester, int deltaMicros) async {
      final RunState before = container.read(runControllerProvider);
      final int targetMicros =
          before.roundStartMicros + before.targetDurationMicros;
      clock.setMicros(targetMicros + deltaMicros);
      await tester.tap(find.byType(TapSurface));
      await tester.pump();
    }

    testWidgets(
      'idle state before any tap shows placeholder DELTA/BAND and starting life',
      (tester) async {
        await pumpScreen(tester);

        expect(find.textContaining('DELTA: —'), findsOneWidget);
        expect(find.textContaining('BAND: —'), findsOneWidget);
        expect(find.textContaining('LIFE: 50%'), findsOneWidget);
      },
    );

    testWidgets(
      'Perfect -> On-point -> Miss -> Perfect sequence updates delta/band/life '
      'correctly after every tap',
      (tester) async {
        await pumpScreen(tester);

        // Round 1: Perfect (10ms, inside +-30ms).
        await tapAtDelta(tester, 10000);
        expect(find.textContaining('DELTA: 10 ms'), findsOneWidget);
        expect(find.textContaining('BAND: PERFECT'), findsOneWidget);
        expect(find.textContaining('LIFE: 53%'), findsOneWidget); // 50 + 3

        // Round 2: On-point (50ms, inside +-80ms, outside +-30ms).
        await tapAtDelta(tester, 50000);
        expect(find.textContaining('DELTA: 50 ms'), findsOneWidget);
        expect(find.textContaining('BAND: ON_POINT'), findsOneWidget);
        expect(find.textContaining('LIFE: 55%'), findsOneWidget); // 53 + 2

        // Round 3: Miss (500ms, well outside +-80ms).
        await tapAtDelta(tester, 500000);
        expect(find.textContaining('DELTA: 500 ms'), findsOneWidget);
        expect(find.textContaining('BAND: MISS'), findsOneWidget);
        expect(find.textContaining('LIFE: 51%'), findsOneWidget); // 55 - 4

        // Round 4: Perfect again, on the negative side (press before target).
        await tapAtDelta(tester, -20000);
        expect(find.textContaining('DELTA: 20 ms'), findsOneWidget);
        expect(find.textContaining('BAND: PERFECT'), findsOneWidget);
        expect(find.textContaining('LIFE: 54%'), findsOneWidget); // 51 + 3
      },
    );

    testWidgets(
      'Zone C holds the previous result and does not reset to placeholder '
      'between rounds',
      (tester) async {
        await pumpScreen(tester);
        await tapAtDelta(tester, 10000); // Perfect
        expect(find.textContaining('BAND: PERFECT'), findsOneWidget);

        // No tap yet this new round; per play-screen-skeleton-v1.md §2
        // State 1, Zone C must keep showing the previous tap's result, not
        // blank/placeholder, until the next tap overwrites it.
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.textContaining('BAND: PERFECT'), findsOneWidget);
        expect(find.textContaining('DELTA: 10 ms'), findsOneWidget);
      },
    );

    testWidgets(
      'TARGET readout is re-rolled after every tap (new round each time)',
      (tester) async {
        await pumpScreen(tester);
        final Set<int> seenTargets = {
          container.read(runControllerProvider).targetDurationMicros,
        };

        for (int i = 0; i < 8; i++) {
          await tapAtDelta(tester, 10000); // always Perfect; band irrelevant
          seenTargets.add(container.read(runControllerProvider).targetDurationMicros);
        }

        // Targets are drawn from a 17,000,000-microsecond-wide range; 9
        // draws landing on the exact same value would itself indicate the
        // roll isn't happening. Assert we actually saw more than one.
        expect(seenTargets.length, greaterThan(1));
      },
    );

    testWidgets(
      'rapid-fire taps: 25 taps in a tight loop do not throw and life '
      'accumulates without double-counting or corruption',
      (tester) async {
        await pumpScreen(tester);

        for (int i = 0; i < 25; i++) {
          final int delta = switch (i % 3) {
            0 => 10000, // Perfect
            1 => 50000, // On-point
            _ => 500000, // Miss
          };
          await tapAtDelta(tester, delta);
        }

        final RunState finalState = container.read(runControllerProvider);
        expect(finalState.lifePct, inInclusiveRange(0.0, 100.0));
        expect(finalState.lifePct.isNaN, isFalse);
        // 8 full Perfect/On-point/Miss groups (net +1 each) + 1 trailing
        // Perfect (i == 24): 50 + 8*1 + 3 = 61.
        expect(finalState.lifePct, 61.0);
      },
    );

    testWidgets(
      'life displayed in Zone A clamps at 100% under repeated Perfect taps',
      (tester) async {
        await pumpScreen(tester);
        // 50 -> 100 needs 17 Perfect taps (+3 each = 51 > 50, clamps at
        // 100 well before that many); run enough to guarantee clamp.
        for (int i = 0; i < 20; i++) {
          await tapAtDelta(tester, 10000); // Perfect every time
        }
        expect(find.textContaining('LIFE: 100%'), findsOneWidget);
        expect(container.read(runControllerProvider).lifePct, 100.0);
      },
    );

    testWidgets(
      'life displayed in Zone A clamps at 0% under repeated Miss taps',
      (tester) async {
        await pumpScreen(tester);
        for (int i = 0; i < 20; i++) {
          await tapAtDelta(tester, 500000); // Miss every time
        }
        expect(find.textContaining('LIFE: 0%'), findsOneWidget);
        expect(container.read(runControllerProvider).lifePct, 0.0);
      },
    );

    testWidgets(
      'a very large delta (far outside any band) is a Miss and does not throw',
      (tester) async {
        await pumpScreen(tester);
        // ~1000 seconds away from target.
        await tapAtDelta(tester, 1000000000);
        expect(find.textContaining('BAND: MISS'), findsOneWidget);
        expect(find.textContaining('DELTA: 1000000 ms'), findsOneWidget);
        expect(find.textContaining('LIFE: 46%'), findsOneWidget); // 50 - 4
      },
    );

    testWidgets(
      'two simultaneous pointers (multi-touch): both independently register '
      'as taps, and the second is scored against a target that already '
      're-rolled underneath it',
      (tester) async {
        await pumpScreen(tester);
        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros); // exact hit for the *first* pointer

        final Finder surface = find.byType(TapSurface);
        final Offset p1 = tester.getTopLeft(surface) + const Offset(20, 20);
        final Offset p2 =
            tester.getBottomRight(surface) - const Offset(20, 20);

        final TestGesture g1 = await tester.startGesture(p1, pointer: 101);
        final TestGesture g2 = await tester.startGesture(p2, pointer: 102);
        await tester.pump();
        await g1.up();
        await g2.up();

        // Two independent PointerDownEvents -> two registerTap() calls;
        // nothing in TapSurface/RunController deduplicates concurrent
        // pointers or debounces by pointer id. But it's *not* simply "the
        // same good tap counted twice": because RunController re-rolls
        // roundStartMicros/targetDurationMicros synchronously inside the
        // first registerTap() call, the second pointer's identical
        // timestamp is resolved against a brand-new target 3-20 *seconds*
        // away — i.e. it is deterministically scored a Miss no matter how
        // precisely the two touches land together. Net: +3 (first, Perfect)
        // - 4 (second, forced Miss) = -1 from a simultaneous double-touch,
        // not +6 as a naive "double-count" would suggest. See test report:
        // this is a real, reproducible side effect of instant target
        // re-roll with no pointer-identity/debounce guard, worth flagging
        // even though it's arguably out of scope to fix in the Days 1-2
        // skeleton.
        final RunState after = container.read(runControllerProvider);
        expect(after.lifePct, 49.0);
      },
    );
  });
}
