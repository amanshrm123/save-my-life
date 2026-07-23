// Widget-level tests for the Play screen, from the Days 1-2 walking
// skeleton through the play-loop-v2.md pixel-fidelity pass and the v3
// founder-requested changes (docs/architecture/v3.md,
// docs/design/play-loop-v3.md).
//
// v3 adds a SECOND `TapSurface` (the numplate, item 3) alongside the
// bottom button, so `find.byType(TapSurface)` is no longer unique —
// wherever a test means specifically "the bottom button", it now uses
// `_findButtonTapSurface()` (an ancestor lookup off the button's existing
// `Key('zoneDContainer')`) rather than a bare type lookup.
//
// v3 also means every `ProviderContainer` that reaches `RunController`
// (directly or via `PlayScreen`) must override `profileRepositoryProvider`
// with a `FakeProfileRepository` AND await its `.future` before the first
// widget pump — `RunController.build()` now does a synchronous
// `.requireValue` read of that provider (architecture v3 §3.4), which
// throws if the provider is still `AsyncLoading` at that moment. This
// mirrors the real app's own precondition (`SplashScreen` already awaits
// this provider before `PlayScreen` is ever reached).
//
// The first test is the original smoke test (App() -> Play's zones
// render), using `AppShell` wrapped in an `UncontrolledProviderScope` with a
// fake, already-complete profile to swap in that fake so this test exercises
// the real top-level wiring end-to-end rather than a first-launch onboarding
// chain (that chain has its own dedicated tests in
// test/features/onboarding/onboarding_widget_test.dart). The rest of this
// file's tests drive the *real* `PlayScreen` — real `TapSurface`/`Listener`,
// real `RunController`, real `resolve()` — through actual simulated pointer
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
// (test/support/fake_monotonic_clock.dart). Everything downstream of the
// clock (TapSurface, RunController, resolve(), PlayScreen's text) is
// exercised unmodified.
//
// v3 item 4 (ranged Hit/Miss life-deltas) also means most life-value
// assertions below check band + range membership via
// `container.read(runControllerProvider)` rather than an exact hardcoded
// `Life NN%` string, since the actual rolled magnitude is not
// test-controllable through the public API (`RunController`'s `Random` is
// real, not injected) — exact-value roll->magnitude coverage lives in
// test/features/timing_engine/timing_engine_test.dart's `lifeDeltaFor`
// group instead.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timing_tap/app/app.dart';
import 'package:timing_tap/core/theme.dart';
import 'package:timing_tap/features/onboarding/name_validator.dart';
import 'package:timing_tap/features/persistence/hive_profile_repository.dart';
import 'package:timing_tap/features/persistence/profile_repository.dart';
import 'package:timing_tap/features/run/countdown_view.dart';
import 'package:timing_tap/features/run/run_controller.dart';
import 'package:timing_tap/features/timing_engine/tap_surface.dart';
import 'package:timing_tap/features/timing_engine/timing_engine.dart';

import 'support/fake_monotonic_clock.dart';
import 'support/fake_profile_repository.dart';

/// Locates specifically the bottom button's `TapSurface` — needed because
/// v3 item 3 adds a second `TapSurface` around the numplate, so a bare
/// `find.byType(TapSurface)` is no longer unique. Keyed off the button's
/// existing `Key('zoneDContainer')` (on `_TapZone`'s container), which is
/// only ever a descendant of the button's own `TapSurface`.
Finder _findButtonTapSurface() => find.ancestor(
  of: find.byKey(const Key('zoneDContainer')),
  matching: find.byType(TapSurface),
);

/// Locates the numplate's `TapSurface` — the other, first-in-tree-order
/// `TapSurface` once `_findButtonTapSurface()`'s target exists in the same
/// tree. There are only ever exactly two `TapSurface`s while
/// `phase == playing`, so "the one that isn't the button" is unambiguous.
Finder _findNumplateTapSurface() => find.byWidgetPredicate((widget) {
  if (widget is! TapSurface) return false;
  return true;
}).first;

/// Mirrors `play_screen.dart`'s private `_formatSignedLifeDelta` for the
/// life-delta values this suite asserts pill text against (architecture v4
/// §2) — every value involved is a whole-integer band bound
/// (`TimingConfig`'s `onPointLifeDeltaMin/Max`/`missLifeDeltaMin/Max`), so
/// this deliberately-simpler helper (no fractional-value branch) is
/// sufficient here without duplicating the production formatter's full
/// logic.
String _expectedSignedLifeDelta(double value) =>
    '${value < 0 ? '-' : '+'}${value.abs().toInt()}';

void main() {
  testWidgets('App() on a returning launch (onboarding already complete) shows '
      "Splash, then the countdown, then the Play zones once it finishes", (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWith(
          (ref) async =>
              FakeProfileRepository(isOnboardingComplete: true)
                  as ProfileRepository,
        ),
        nameValidatorProvider.overrideWith(
          (ref) async => NameValidator(const []),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AppShell()),
    );
    await tester.pump();

    // Splash is up first (§3.2 — every launch, not just the first).
    expect(find.text('3'), findsNothing);

    // Clear Splash's 900ms minimum-display window and let the
    // already-resolved init future's microtasks flush, then let the
    // push-replacement transition into PlayScreen settle.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    // RunController.build() now starts in RunPhase.countdown
    // (play-screen-gate1-v1.md §1) — the Play zones are not present yet.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('TAP'), findsNothing);

    // The countdown's Timer is real wall-clock pacing, captured by
    // flutter_test's fake-async zone, so advancing by its exact total
    // duration fires it deterministically.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.textContaining('Life '), findsOneWidget);
    expect(find.text('Tap at'), findsOneWidget);
    expect(find.textContaining('DELTA:'), findsOneWidget);
    expect(find.textContaining('BAND:'), findsOneWidget);
    expect(find.text('TAP'), findsOneWidget);
    // Run/Deaths chip row (play-loop-v2.md §2.1/§3.1) — real,
    // provider-backed values as of architecture v3 §3.2/item 1 (a fresh
    // profile has deathCount == 0, so Run == 1 / Deaths == 0).
    expect(find.text('Run '), findsOneWidget);
    expect(find.text('Deaths '), findsOneWidget);
  });

  group('Countdown (play-screen-gate1-v1.md §1)', () {
    testWidgets(
      'shows 3, then 2, then 1 for one second each, then swaps instantly '
      'to the Play zones — no transition frame',
      (WidgetTester tester) async {
        final FakeMonotonicClock clock = FakeMonotonicClock(0);
        final FakeProfileRepository repo = FakeProfileRepository();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            profileRepositoryProvider.overrideWith(
              (ref) async => repo as ProfileRepository,
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(profileRepositoryProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PlayScreen()),
          ),
        );
        await tester.pump();
        expect(find.text('3'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 999));
        expect(find.text('3'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('2'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        // Instant swap: the countdown screen is gone and the Play zones are
        // up, with no intermediate "GO"/fade frame. Asserting CountdownView
        // itself is gone (rather than the digit text '1' being absent) —
        // play-loop-v2.md's Run/Deaths chip row now legitimately renders a
        // "Run 1" value, so a bare find.text('1') would find that chip
        // instead of proving the countdown screen is really gone.
        expect(find.byType(CountdownView), findsNothing);
        expect(find.text('TAP'), findsOneWidget);
        expect(container.read(runControllerProvider).phase, RunPhase.playing);
      },
    );

    testWidgets(
      'countdown Timer is created while handling a post-frame callback, not '
      'synchronously during the initial build (regression for the '
      'on-device bug where a Timer started in initState raced a slow cold '
      'engine start and finished the whole countdown off-screen before '
      'anything was ever composited)',
      (WidgetTester tester) async {
        final FakeMonotonicClock clock = FakeMonotonicClock(0);
        final FakeProfileRepository repo = FakeProfileRepository();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            profileRepositoryProvider.overrideWith(
              (ref) async => repo as ProfileRepository,
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(profileRepositoryProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PlayScreen()),
          ),
        );
        await tester.pump();

        // `_CountdownViewState` is private, so it's accessed here via
        // `dynamic` rather than a named type — `debugTimerStartedDuringPhase`
        // itself is a public (test-only) member, so this resolves fine at
        // runtime despite the class being private to countdown_view.dart.
        final dynamic state = tester.state(find.byType(CountdownView));

        expect(
          state.debugTimerStartedDuringPhase,
          SchedulerPhase.postFrameCallbacks,
          reason:
              'the countdown Timer must be created while handling a '
              'post-frame callback (after the first frame has rendered), '
              'not synchronously during initState/build '
              '(SchedulerPhase.persistentCallbacks) — otherwise a slow cold '
              'start can burn through the whole 3-2-1 before anything is '
              'ever visible on screen.',
        );

        // Sanity check the countdown still behaves normally end-to-end.
        expect(find.text('3'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 999));
        expect(find.text('3'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('2'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.byType(CountdownView), findsNothing);
        expect(find.text('TAP'), findsOneWidget);
        expect(container.read(runControllerProvider).phase, RunPhase.playing);
      },
    );
  });

  group('Countdown header (play-loop-v1.md §2)', () {
    Future<ProviderContainer> pumpCountdown(
      WidgetTester tester, {
      required FakeProfileRepository repository,
    }) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FakeMonotonicClock(0)),
          profileRepositoryProvider.overrideWith(
            (ref) async => repository as ProfileRepository,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CountdownView()),
        ),
      );
      // Two pumps: the first builds with `profileRepositoryProvider` still
      // `AsyncLoading` (the fallback "Get ready" header, same as it would
      // render mid-resolution); the second flushes the already-resolved
      // fake repository's future and rebuilds with `AsyncData`.
      await tester.pump();
      await tester.pump();
      return container;
    }

    /// Unmounts the widget tree before the countdown's 1s `Timer.periodic`
    /// would otherwise fire mid-test — `CountdownView.dispose()` cancels it
    /// — so these header-only tests don't need to drain the full 3s
    /// sequence (unlike the timing-behavior tests in the group above) and
    /// don't leak a pending `Timer` into test teardown. `CountdownView`
    /// alone never reads `runControllerProvider` (only `beginPlaying()`
    /// would, at the end of the 3s sequence, which never fires here), so
    /// no `profileRepositoryProvider` resolution wait is needed before
    /// these tests' first pump.
    Future<void> tearDownCountdown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
    }

    testWidgets(
      'a named player sees "Hey {name}, get ready" with the name in a '
      'colored span',
      (tester) async {
        await pumpCountdown(
          tester,
          repository: FakeProfileRepository(name: 'Aman'),
        );

        expect(
          find.text('Hey Aman, get ready', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Get ready'), findsNothing);

        await tearDownCountdown(tester);
      },
    );

    testWidgets(
      'a no-name player sees a plain "Get ready" fallback, not a broken or '
      'partially-composed header',
      (tester) async {
        await pumpCountdown(tester, repository: FakeProfileRepository());

        expect(find.text('Get ready'), findsOneWidget);
        expect(find.textContaining('Hey'), findsNothing);

        await tearDownCountdown(tester);
      },
    );

    testWidgets(
      'the gold circle still shows the current countdown digit alongside '
      'the name-aware header',
      (tester) async {
        await pumpCountdown(
          tester,
          repository: FakeProfileRepository(name: 'Priya'),
        );

        expect(
          find.text('Hey Priya, get ready', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget);
        expect(
          find.text('First target drops when it hits zero.'),
          findsOneWidget,
        );

        await tearDownCountdown(tester);
      },
    );
  });

  group(
    'PlayScreen end-to-end tap flow (real Listener.onPointerDown path)',
    () {
      late FakeMonotonicClock clock;
      late FakeProfileRepository repo;
      late ProviderContainer container;

      setUp(() async {
        clock = FakeMonotonicClock(0);
        repo = FakeProfileRepository();
        container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            profileRepositoryProvider.overrideWith(
              (ref) async => repo as ProfileRepository,
            ),
          ],
        );
        await container.read(profileRepositoryProvider.future);
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

        // These tests exercise the Play zones/tap flow directly — the
        // countdown itself is covered by its own dedicated group above, so
        // skip straight past it exactly as `CountdownView` would once "1"
        // finishes (calling the same `beginPlaying()` the real countdown
        // calls, not a test-only shortcut around it).
        container.read(runControllerProvider.notifier).beginPlaying();
        await tester.pump();
      }

      /// Positions the fake clock so that a tap *right now* lands
      /// [deltaMicros] away from the current round's target, then dispatches
      /// a real simulated pointer-down/up through the bottom button's
      /// `TapSurface`, then pumps a frame so the rebuilt text reflects the
      /// new state.
      ///
      /// Also pumps past the tap flash's 120ms `Timer` (play-screen-gate1-v1
      /// §3) so it doesn't linger pending into the next tap/test teardown —
      /// this advances flutter_test's fake-async clock only, entirely
      /// separate from the `FakeMonotonicClock` used for timing/scoring, so
      /// it has no effect on band/life results.
      Future<void> tapAtDelta(WidgetTester tester, int deltaMicros) async {
        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + deltaMicros);
        await tester.tap(_findButtonTapSurface());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
      }

      testWidgets(
        'idle state before any tap shows placeholder DELTA/BAND and starting '
        'life at 100% (architecture v3 item 2)',
        (tester) async {
          await pumpScreen(tester);

          expect(find.textContaining('DELTA: —'), findsOneWidget);
          expect(find.textContaining('BAND: —'), findsOneWidget);
          expect(find.textContaining('Life 100%'), findsOneWidget);
        },
      );

      testWidgets(
        'Perfect -> On-point -> Miss -> Perfect sequence updates delta/band '
        'correctly after every tap, and life moves within the correct band '
        'range each time (architecture v3 item 4 — deltas are now ranged, so '
        'exact life% values are no longer asserted, only band membership)',
        (tester) async {
          await pumpScreen(tester);

          // Drive life down first so gains are observable (100-start would
          // otherwise clamp a Perfect/On-point tap to an unobservable 100%).
          // Two Miss taps guarantee enough headroom for the Perfect + On-point
          // steps below even in the worst-case roll (two min-magnitude -3
          // Misses -> life <= 94; +3 Perfect -> <= 97; +3 On-point -> <= 100,
          // never exceeding 100, so neither step's delta is ever clamped).
          await tapAtDelta(tester, 500000); // Miss
          await tapAtDelta(tester, 500000); // Miss
          double life = container.read(runControllerProvider).lifePct;
          expect(life, lessThan(100.0));

          // Round: Perfect (10ms, inside +-30ms) — fixed +3.
          double before = life;
          await tapAtDelta(tester, 10000);
          expect(find.textContaining('DELTA: 10 ms'), findsOneWidget);
          expect(find.textContaining('BAND: PERFECT'), findsOneWidget);
          life = container.read(runControllerProvider).lifePct;
          expect(life, before + 3.0);

          // Round: On-point (50ms, inside +-200ms, outside +-30ms) — ranged
          // [+2, +3].
          before = life;
          await tapAtDelta(tester, 50000);
          expect(find.textContaining('DELTA: 50 ms'), findsOneWidget);
          expect(find.textContaining('BAND: ON_POINT'), findsOneWidget);
          life = container.read(runControllerProvider).lifePct;
          expect(life - before, inInclusiveRange(2.0, 3.0));

          // Round: Miss (500ms, well outside +-200ms) — ranged [-5, -3].
          before = life;
          await tapAtDelta(tester, 500000);
          expect(find.textContaining('DELTA: 500 ms'), findsOneWidget);
          expect(find.textContaining('BAND: MISS'), findsOneWidget);
          life = container.read(runControllerProvider).lifePct;
          expect(before - life, inInclusiveRange(3.0, 5.0));

          // Round: Perfect again, on the negative side (press before target).
          before = life;
          await tapAtDelta(tester, -20000);
          expect(find.textContaining('DELTA: 20 ms'), findsOneWidget);
          expect(find.textContaining('BAND: PERFECT'), findsOneWidget);
          life = container.read(runControllerProvider).lifePct;
          expect(life, before + 3.0);
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
            seenTargets.add(
              container.read(runControllerProvider).targetDurationMicros,
            );
          }

          // Targets are drawn from a 17,000,000-microsecond-wide range; 9
          // draws landing on the exact same value would itself indicate the
          // roll isn't happening. Assert we actually saw more than one.
          expect(seenTargets.length, greaterThan(1));
        },
      );

      testWidgets(
        'rapid-fire taps: 25 taps in a tight loop do not throw and life stays '
        'within [0, 100] throughout (no double-counting or corruption); an '
        'exact final value is no longer asserted since deltas are ranged '
        '(architecture v3 item 4) and the run may end at 0 partway through',
        (tester) async {
          await pumpScreen(tester);

          for (int i = 0; i < 25; i++) {
            if (container.read(runControllerProvider).phase !=
                RunPhase.playing) {
              break;
            }
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
        },
      );

      testWidgets(
        'life displayed clamps at 100% under repeated Perfect taps (fixed '
        'delta, unaffected by item 4\'s ranging)',
        (tester) async {
          await pumpScreen(tester);
          for (int i = 0; i < 20; i++) {
            await tapAtDelta(tester, 10000); // Perfect every time
          }
          expect(find.textContaining('Life 100%'), findsOneWidget);
          expect(container.read(runControllerProvider).lifePct, 100.0);
        },
      );

      testWidgets(
        'repeated Miss taps eventually end the run at exactly 0%: the Play '
        'zones are replaced entirely by the death placeholder (architecture '
        'v3 §3.5, play-loop-v3.md §3) — this replaces the old "life clamps '
        'at 0% while still playing" test, which is no longer valid once '
        'Death ends the run',
        (tester) async {
          await pumpScreen(tester);
          // Enough taps to guarantee crossing zero regardless of which
          // magnitude each roll lands on (worst case -3 each; 40 * 3 == 120,
          // comfortably over the 100 starting life).
          for (int i = 0; i < 40; i++) {
            if (container.read(runControllerProvider).phase !=
                RunPhase.playing) {
              break;
            }
            await tapAtDelta(tester, 500000); // Miss every time
          }

          final RunState finalState = container.read(runControllerProvider);
          expect(finalState.phase, RunPhase.dead);
          expect(finalState.lifePct, 0.0);
          expect(find.text('You died'), findsOneWidget);
          expect(find.text('Play again'), findsOneWidget);
          expect(find.text('TAP'), findsNothing);
        },
      );

      testWidgets(
        'a very large delta (far outside any band) is a Miss, does not throw, '
        'and moves life within the Miss range',
        (tester) async {
          await pumpScreen(tester);
          final double before = container.read(runControllerProvider).lifePct;
          // ~1000 seconds away from target.
          await tapAtDelta(tester, 1000000000);
          expect(find.textContaining('BAND: MISS'), findsOneWidget);
          expect(find.textContaining('DELTA: 1000000 ms'), findsOneWidget);
          final double after = container.read(runControllerProvider).lifePct;
          expect(before - after, inInclusiveRange(3.0, 5.0));
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

          final Finder surface = _findButtonTapSurface();
          final Offset p1 = tester.getTopLeft(surface) + const Offset(20, 20);
          final Offset p2 =
              tester.getBottomRight(surface) - const Offset(20, 20);

          final TestGesture g1 = await tester.startGesture(p1, pointer: 101);
          final TestGesture g2 = await tester.startGesture(p2, pointer: 102);
          await tester.pump();
          await g1.up();
          await g2.up();
          // Drain the two 120ms flash-clear Timers (one per tap) so neither
          // lingers pending into test teardown.
          await tester.pump(const Duration(milliseconds: 120));

          // Two independent PointerDownEvents -> two registerTap() calls;
          // nothing in TapSurface/RunController deduplicates concurrent
          // pointers or debounces by pointer id. The first pointer lands a
          // Perfect (exact hit) which, from a 100%-start, clamps immediately
          // (unobservable). Because RunController re-rolls
          // roundStartMicros/targetDurationMicros synchronously inside the
          // first registerTap() call, the second pointer's identical
          // timestamp is resolved against a brand-new target 3-20 *seconds*
          // away — i.e. it is deterministically scored a Miss no matter how
          // precisely the two touches land together. Net: life stays at 100
          // from the first tap, then drops by the ranged Miss amount from
          // the second.
          final RunState after = container.read(runControllerProvider);
          expect(100.0 - after.lifePct, inInclusiveRange(3.0, 5.0));
        },
      );
    },
  );

  group(
    'Numplate as a non-scoring, still-tappable surface (architecture v4 §1, '
    'walking back v3 item 3/§6.2)',
    () {
      late FakeMonotonicClock clock;
      late ProviderContainer container;

      setUp(() async {
        clock = FakeMonotonicClock(0);
        final FakeProfileRepository repo = FakeProfileRepository();
        container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(clock),
            profileRepositoryProvider.overrideWith(
              (ref) async => repo as ProfileRepository,
            ),
          ],
        );
        await container.read(profileRepositoryProvider.future);
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
        container.read(runControllerProvider.notifier).beginPlaying();
        await tester.pump();
      }

      testWidgets(
        'tapping the numplate\'s tap surface produces zero scoring effect — '
        'no life change, no band/delta recorded, no flash, no flying pill; '
        'RunState is otherwise byte-for-byte unchanged (architecture v4 §1, '
        'gap 1 — the bottom TAP button is now the sole scoring input)',
        (tester) async {
          await pumpScreen(tester);
          final RunState before = container.read(runControllerProvider);
          final int targetMicros =
              before.roundStartMicros + before.targetDurationMicros;
          // Would resolve as a Perfect if this surface still scored — chosen
          // deliberately so a regression back to `_handleTap` is unmistakable.
          clock.setMicros(targetMicros + 10000);

          await tester.tap(_findNumplateTapSurface());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          final RunState after = container.read(runControllerProvider);
          expect(after.lifePct, before.lifePct);
          expect(after.phase, before.phase);
          expect(after.lastBand, before.lastBand);
          expect(after.lastDeltaMs, before.lastDeltaMs);
          expect(after.lastLifeDelta, before.lastLifeDelta);
          expect(after.lastHitLifeDelta, before.lastHitLifeDelta);
          expect(after.lastMissLifeDelta, before.lastMissLifeDelta);
          expect(after.roundStartMicros, before.roundStartMicros);
          expect(after.targetDurationMicros, before.targetDurationMicros);

          // No flash wash either — `tapFlashBandProvider` is set only inside
          // `_handleTap`, which the numplate's TapSurface never calls.
          expect(container.read(tapFlashBandProvider), isNull);
        },
      );

      testWidgets(
        'the bottom TAP button still scores normally on the same screen where '
        'the numplate is present but inert (architecture v4 §1 sanity check: '
        'gap 1 changes only the numplate\'s tap effect, not the button\'s)',
        (tester) async {
          await pumpScreen(tester);
          final RunState before = container.read(runControllerProvider);
          final int targetMicros =
              before.roundStartMicros + before.targetDurationMicros;
          clock.setMicros(targetMicros + 10000); // Perfect

          await tester.tap(_findButtonTapSurface());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));

          final RunState after = container.read(runControllerProvider);
          expect(after.lastBand, TimingBand.perfect);
          expect(after.lastDeltaMs, 10);
        },
      );

      // The v3-era "mid-flight pill doesn't block the numplate" test used to
      // prove `IgnorePointer` non-blocking by observing a *scored* tap land on
      // the numplate through the flying pill. That proof no longer works: the
      // numplate is now permanently inert (the assertion above), so a tap
      // landing on it — blocked by the flight layer or not — produces
      // identically "no effect" either way, making the property unobservable
      // through this surface (architecture v4 §3 / file-change-list note for
      // test/widget_test.dart). The flight's own launch/arrival anchors keep
      // the pill strictly above the bottom TAP button throughout the flight
      // (see `_launchFlight`'s `launchTop`/`arrivalTop` math), so it never
      // overlaps the button either, leaving no widget-level surface left to
      // reproduce this proof against. Dropped per v4's explicit "or drop it if
      // the IgnorePointer property is otherwise covered" allowance — the
      // `IgnorePointer` wrap itself is still present in `play_screen.dart` and
      // reviewable by inspection.
    },
  );

  group('Death placeholder (architecture v3 §3.5, play-loop-v3.md §3)', () {
    late FakeMonotonicClock clock;
    late FakeProfileRepository repo;
    late ProviderContainer container;

    setUp(() async {
      clock = FakeMonotonicClock(0);
      repo = FakeProfileRepository();
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          profileRepositoryProvider.overrideWith(
            (ref) async => repo as ProfileRepository,
          ),
        ],
      );
      await container.read(profileRepositoryProvider.future);
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> pumpScreenAndDie(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlayScreen()),
        ),
      );
      await tester.pump();
      container.read(runControllerProvider.notifier).beginPlaying();
      await tester.pump();

      for (int i = 0; i < 40; i++) {
        if (container.read(runControllerProvider).phase != RunPhase.playing) {
          break;
        }
        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 500000); // Miss
        await tester.tap(_findButtonTapSurface());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(container.read(runControllerProvider).phase, RunPhase.dead);
    }

    testWidgets(
      'shows "You died", the reused Deaths chip with the real persisted '
      'count, and a "Play again" link — no card chrome, no share',
      (tester) async {
        await pumpScreenAndDie(tester);

        expect(find.text('You died'), findsOneWidget);
        expect(
          find.text('Deaths '),
          findsOneWidget,
        ); // _Chip's label Text renders with a trailing space
        expect(find.text('1'), findsOneWidget); // one death so far
        expect(find.text('Play again'), findsOneWidget);
        expect(repo.incrementDeathCountCallCount, 1);
      },
    );

    testWidgets(
      'tapping "Play again" calls startNewCycle() and restarts into a '
      'fresh countdown at 100% life, preserving deathCount',
      (tester) async {
        await pumpScreenAndDie(tester);

        await tester.tap(find.text('Play again'));
        await tester.pump();

        final RunState afterRestart = container.read(runControllerProvider);
        expect(afterRestart.phase, RunPhase.countdown);
        expect(afterRestart.lifePct, 100.0);
        expect(afterRestart.deathCount, 1);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('You died'), findsNothing);
      },
    );
  });

  group('Zone D tap flash (play-screen-gate1-v1.md §3)', () {
    late FakeMonotonicClock clock;
    late ProviderContainer container;

    setUp(() async {
      clock = FakeMonotonicClock(0);
      final FakeProfileRepository repo = FakeProfileRepository();
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          profileRepositoryProvider.overrideWith(
            (ref) async => repo as ProfileRepository,
          ),
        ],
      );
      await container.read(profileRepositoryProvider.future);
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
      container.read(runControllerProvider.notifier).beginPlaying();
      await tester.pump();
    }

    // Zone D's chrome (play-loop-v1.md §3.3) renders via
    // `BoxDecoration.color` rather than `Container.color` directly (needed
    // for the border/shadow/radius chrome) — looked up by its dedicated
    // test key (`Key('zoneDContainer')`, `play_screen.dart`).
    Color? currentTapSurfaceColor(WidgetTester tester) {
      final Container container = tester.widget<Container>(
        find.byKey(const Key('zoneDContainer')),
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    // Regression: the "TAP" label's text-shadow must track the current
    // flash state, not stay a fixed coral tone that mismatches on a
    // green/red background (tester on-device finding, play-loop-v1.md §3.3).
    Color? currentTapLabelShadow(WidgetTester tester) {
      final Text tap = tester.widget<Text>(find.text('TAP'));
      return tap.style?.shadows?.first.color;
    }

    testWidgets(
      'flashes green on a hit and clears to neutral after exactly 120ms',
      (tester) async {
        await pumpScreen(tester);
        expect(currentTapSurfaceColor(tester), AppColors.coral);

        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 10000); // Perfect
        await tester.tap(_findButtonTapSurface());
        await tester.pump();

        expect(currentTapSurfaceColor(tester), AppColors.green);
        expect(currentTapLabelShadow(tester), AppColors.greenDark);
        // Perfect is fixed (architecture v3 §4.1), so its pill copy is
        // still an exact literal — unlike On-point/Miss, which are ranged.
        expect(find.text('PERFECT +3%'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 119));
        expect(currentTapSurfaceColor(tester), AppColors.green);

        await tester.pump(const Duration(milliseconds: 1));
        expect(currentTapSurfaceColor(tester), AppColors.coral);
      },
    );

    testWidgets('flashes red on a miss', (tester) async {
      await pumpScreen(tester);

      final RunState before = container.read(runControllerProvider);
      final int targetMicros =
          before.roundStartMicros + before.targetDurationMicros;
      clock.setMicros(targetMicros + 500000); // Miss
      await tester.tap(_findButtonTapSurface());
      await tester.pump();

      expect(currentTapSurfaceColor(tester), AppColors.red);
      expect(currentTapLabelShadow(tester), AppColors.redDark);
      // Miss is ranged (architecture v3 item 4) — construct the expected
      // pill text from the actual rolled value, sourced from RunState,
      // rather than a hardcoded TimingConfig constant (removed).
      final double? lastLifeDelta = container
          .read(runControllerProvider)
          .lastLifeDelta;
      expect(lastLifeDelta, isNotNull);
      expect(find.text('MISS ${lastLifeDelta!.toInt()}%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      expect(currentTapSurfaceColor(tester), AppColors.coral);
    });

    testWidgets(
      'flashes green on an on-point hit too (both Perfect and On-point '
      'collapse to the same hit color on Zone D, per Gate 1 §3 — only the '
      'floating flash pill (not this wash) distinguishes the two bands)',
      (tester) async {
        await pumpScreen(tester);

        final RunState before = container.read(runControllerProvider);
        final int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 50000); // On-point (inside +-200ms)
        await tester.tap(_findButtonTapSurface());
        await tester.pump();

        expect(currentTapSurfaceColor(tester), AppColors.green);
        expect(find.textContaining('ON POINT'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 120));
      },
    );
  });

  group('Zone A three-tier life bar (play-loop-v1.md §3.1)', () {
    late FakeMonotonicClock clock;
    late ProviderContainer container;

    setUp(() async {
      clock = FakeMonotonicClock(0);
      final FakeProfileRepository repo = FakeProfileRepository();
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          profileRepositoryProvider.overrideWith(
            (ref) async => repo as ProfileRepository,
          ),
        ],
      );
      await container.read(profileRepositoryProvider.future);
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
      container.read(runControllerProvider.notifier).beginPlaying();
      await tester.pump();
    }

    Color? lifeBarFillColor(WidgetTester tester) {
      final Container fill = tester.widget<Container>(
        find.byKey(const Key('lifeBarFill')),
      );
      return (fill.decoration as BoxDecoration?)?.color;
    }

    /// Mirrors `_lifeBarColor`'s tiering (play_screen.dart, private) for
    /// test-side expected-color computation.
    Color expectedTierColor(double lifePct) {
      if (lifePct > 50) return AppColors.green;
      if (lifePct > 25) return AppColors.coral;
      return AppColors.red;
    }

    /// Taps Miss repeatedly (draining each tap's 120ms flash timer) until
    /// `lifePct` first drops to/below [threshold], or the run ends —
    /// whichever comes first. Returns the resulting state. Needed because
    /// item 4's ranged Miss magnitude means the exact tap count to cross a
    /// given tier boundary isn't fixed the way flat `-4` was pre-v3.
    Future<RunState> tapMissUntilAtOrBelow(
      WidgetTester tester,
      double threshold,
    ) async {
      RunState state = container.read(runControllerProvider);
      int guard = 0;
      while (state.phase == RunPhase.playing &&
          state.lifePct > threshold &&
          guard < 60) {
        final int targetMicros =
            state.roundStartMicros + state.targetDurationMicros;
        clock.setMicros(targetMicros + 500000); // Miss
        await tester.tap(_findButtonTapSurface());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        state = container.read(runControllerProvider);
        guard++;
      }
      return state;
    }

    testWidgets(
      'life bar fills green at the 100% starting life (architecture v3 item 2)',
      (tester) async {
        await pumpScreen(tester);
        expect(container.read(runControllerProvider).lifePct, 100.0);
        expect(lifeBarFillColor(tester), AppColors.green);
      },
    );

    testWidgets('life bar fills coral once life drops into (25, 50]', (
      tester,
    ) async {
      await pumpScreen(tester);
      final RunState state = await tapMissUntilAtOrBelow(tester, 50.0);
      expect(
        state.phase,
        RunPhase.playing,
        reason: 'should not have died reaching this tier',
      );
      expect(state.lifePct, inInclusiveRange(25.0001, 50.0));
      expect(lifeBarFillColor(tester), expectedTierColor(state.lifePct));
      expect(lifeBarFillColor(tester), AppColors.coral);
    });

    testWidgets('life bar fills red once life drops to/below 25%', (
      tester,
    ) async {
      await pumpScreen(tester);
      final RunState state = await tapMissUntilAtOrBelow(tester, 25.0);
      expect(state.lifePct, lessThanOrEqualTo(25.0));
      if (state.lifePct > 0.0) {
        expect(lifeBarFillColor(tester), AppColors.red);
      } else {
        // Ran all the way to death instead — still red at 0%, but the Play
        // zones (and this life bar) no longer exist once phase == dead.
        expect(state.phase, RunPhase.dead);
      }
    });

    testWidgets(
      'life bar fills red at exactly 0% right before death replaces the screen',
      (tester) async {
        await pumpScreen(tester);
        final RunState state = await tapMissUntilAtOrBelow(tester, 0.0);
        expect(state.lifePct, 0.0);
        expect(state.phase, RunPhase.dead);
        // The life bar itself is gone now (death placeholder replaced the
        // whole screen) — assert the death UI instead.
        expect(find.text('You died'), findsOneWidget);
      },
    );

    testWidgets('life bar fills green at exactly 100%', (tester) async {
      await pumpScreen(tester);
      expect(container.read(runControllerProvider).lifePct, 100.0);
      expect(lifeBarFillColor(tester), AppColors.green);
    });
  });

  group('Play loop v2/v3 exact-fidelity rebuild', () {
    late FakeMonotonicClock clock;
    late ProviderContainer container;

    setUp(() async {
      clock = FakeMonotonicClock(0);
      final FakeProfileRepository repo = FakeProfileRepository();
      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          profileRepositoryProvider.overrideWith(
            (ref) async => repo as ProfileRepository,
          ),
        ],
      );
      await container.read(profileRepositoryProvider.future);
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
      container.read(runControllerProvider.notifier).beginPlaying();
      await tester.pump();
    }

    testWidgets(
      'Run/Deaths chips render real, provider-backed values (deathCount 0 '
      'on a fresh profile: Run 1 / Deaths 0) — architecture v3 §3.2/item 1 '
      'replaces the old hardcoded stub literals',
      (tester) async {
        await pumpScreen(tester);

        expect(find.text('Run '), findsOneWidget);
        expect(find.text('Deaths '), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      },
    );

    testWidgets(
      'legend pills sit in their own row above the tap button, not inside '
      'its widget subtree, and seed to each band\'s gentlest value before '
      'the first tap of a fresh run (architecture v4 §2)',
      (tester) async {
        await pumpScreen(tester);

        final Finder hitPill = find.textContaining('Hit ');
        final Finder missPill = find.textContaining('Miss ');
        expect(hitPill, findsOneWidget);
        expect(missPill, findsOneWidget);
        expect(find.text('Hit +2%'), findsOneWidget);
        expect(find.text('Miss -3%'), findsOneWidget);

        final Finder buttonSurface = _findButtonTapSurface();
        expect(
          find.descendant(of: buttonSurface, matching: hitPill),
          findsNothing,
        );
        expect(
          find.descendant(of: buttonSurface, matching: missPill),
          findsNothing,
        );

        // Positioned above the button: the pills' vertical offset is
        // strictly less than the button TapSurface's own top.
        final double pillTop = tester.getTopLeft(hitPill).dy;
        final double tapSurfaceTop = tester.getTopLeft(buttonSurface).dy;
        expect(pillTop, lessThan(tapSurfaceTop));
      },
    );

    testWidgets(
      'legend pills update live and independently per band: an On-point tap '
      'updates only the Hit pill, a Miss tap updates only the Miss pill, '
      'and a Perfect tap updates neither (architecture v4 §2.1/§2.5)',
      (tester) async {
        await pumpScreen(tester);
        final Finder buttonSurface = _findButtonTapSurface();

        // On-point tap: Hit pill moves off its seed, Miss pill stays.
        RunState before = container.read(runControllerProvider);
        int targetMicros =
            before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 50000); // 50ms -> On-point
        await tester.tap(buttonSurface);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        RunState state = container.read(runControllerProvider);
        expect(state.lastBand, TimingBand.onPoint);
        expect(
          find.text('Hit ${_expectedSignedLifeDelta(state.lastHitLifeDelta)}%'),
          findsOneWidget,
        );
        expect(find.text('Miss -3%'), findsOneWidget); // untouched, still seed
        final double hitPillValueAfterOnPoint = state.lastHitLifeDelta;

        // Miss tap: Miss pill moves off its seed, Hit pill stays at the
        // value the On-point tap above left it at (not the seed, and not
        // cleared by this Miss tap).
        before = container.read(runControllerProvider);
        targetMicros = before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 500000); // Miss
        await tester.tap(buttonSurface);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        state = container.read(runControllerProvider);
        expect(state.lastBand, TimingBand.miss);
        expect(
          find.text(
            'Hit ${_expectedSignedLifeDelta(hitPillValueAfterOnPoint)}%',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Miss ${_expectedSignedLifeDelta(state.lastMissLifeDelta)}%',
          ),
          findsOneWidget,
        );
        final double missPillValueAfterMiss = state.lastMissLifeDelta;

        // Perfect tap: touches neither pill.
        before = container.read(runControllerProvider);
        targetMicros = before.roundStartMicros + before.targetDurationMicros;
        clock.setMicros(targetMicros + 10000); // Perfect
        await tester.tap(buttonSurface);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        expect(
          container.read(runControllerProvider).lastBand,
          TimingBand.perfect,
        );
        expect(
          find.text(
            'Hit ${_expectedSignedLifeDelta(hitPillValueAfterOnPoint)}%',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Miss ${_expectedSignedLifeDelta(missPillValueAfterMiss)}%',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a fresh cycle (death -> startNewCycle() -> beginPlaying() again) '
      'reseeds both legend pills back to "Hit +2%" / "Miss -3%", discarding '
      'the previous cycle\'s rolled values (architecture v4 §2.4)',
      (tester) async {
        await pumpScreen(tester);
        final Finder buttonSurface = _findButtonTapSurface();

        // Take an On-point tap before driving the run to death — the roll
        // isn't test-controllable (real `Random`), so this may or may not
        // actually move the Hit pill off its seed, but it exercises the
        // reset regardless of the field's pre-restart value.
        RunState state = container.read(runControllerProvider);
        int targetMicros = state.roundStartMicros + state.targetDurationMicros;
        clock.setMicros(targetMicros + 50000); // On-point
        await tester.tap(buttonSurface);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        // Drive Miss taps until the run ends (phase == dead) — bounded so a
        // stalled loop fails loudly instead of hanging.
        state = container.read(runControllerProvider);
        int guard = 0;
        while (state.phase == RunPhase.playing && guard < 100) {
          targetMicros = state.roundStartMicros + state.targetDurationMicros;
          clock.setMicros(targetMicros + 1000000000); // ~1000s away -> Miss
          await tester.tap(buttonSurface);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          state = container.read(runControllerProvider);
          guard++;
        }
        expect(state.phase, RunPhase.dead);

        container.read(runControllerProvider.notifier).startNewCycle();
        container.read(runControllerProvider.notifier).beginPlaying();
        await tester.pump();

        expect(find.text('Hit +2%'), findsOneWidget);
        expect(find.text('Miss -3%'), findsOneWidget);
      },
    );

    testWidgets(
      'IndicatorWidget/_IndicatorPainter is never constructed anywhere in '
      'the Play screen render tree (§2.3 — removed entirely, no mockup '
      'counterpart at any state)',
      (tester) async {
        await pumpScreen(tester);

        // Checked by runtimeType name rather than an import, so this
        // assertion holds regardless of whether indicator_painter.dart was
        // deleted outright or merely left unreferenced.
        expect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == 'IndicatorWidget',
          ),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter?.runtimeType.toString() == '_IndicatorPainter',
          ),
          findsNothing,
        );
      },
    );
  });
}
