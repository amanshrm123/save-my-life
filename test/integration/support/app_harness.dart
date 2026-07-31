import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/app.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/core/widgets/sticker_button.dart';
import 'package:timing_tap/features/notifications/application/reminder_service_noop.dart';
import 'package:timing_tap/features/notifications/state/reminder_providers.dart';
import 'package:timing_tap/features/home/presentation/widgets/stat_tile.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/play_loop_screen.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/primary_action_button.dart';
import 'package:timing_tap/features/play_loop/state/play_loop_providers.dart';

/// A `MockClient` that answers every request with an immediate 404 and no
/// real network I/O. Used as the default `httpClientProvider` override for
/// every integration test (see [realApp]) so pumping the real app — which
/// warms up the story pool from `SplashScreen` — never dials out to
/// `kStoryConfigUrl` (a genuine live endpoint as of 2026-07-31, so this
/// guard now matters more than ever — without it, tests would make real
/// outbound HTTPS calls). A 404 cleanly exercises
/// `StoryPoolRepository.refreshIfStale`'s "fetch failed, fall through to the
/// cached/bundled pool" path without any DNS/HTTPS round trip or "Timer is
/// still pending" teardown flake risk.
http.Client fakeHttpClient() =>
    MockClient((_) async => http.Response('not found', 404));

/// Shared plumbing for the cross-feature integration tests (see
/// `test/integration/*_test.dart`). Every real-app scenario in this project
/// is built from these same primitives, so the wiring lives in exactly one
/// place rather than being re-derived per file.
///
/// ## Why a real `App()`, not a per-screen `MaterialApp(home: ...)`
/// The whole point of this test group is to catch bugs that only show up
/// when features interact through the *actual* named-route table
/// (`AppRoutes`/`app.dart`), not a synthetic stand-in. Every helper here
/// therefore pumps the genuine `App` widget with only the unavoidable
/// platform-channel seams overridden (prefs backing store, the Android
/// notification plugin) — never a hand-rolled route table.

/// Seeds `SharedPreferences.setMockInitialValues` and constructs the real
/// [PreferencesService] over it — the one and only backing store for a test.
Future<PreferencesService> mockPrefsService([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return PreferencesService.create();
}

/// The real `App()` widget, wrapped in a `ProviderScope` whose only
/// overrides are the platform-channel seams every test needs regardless of
/// scenario:
///   - `preferencesServiceProvider` -> the given (mock-backed) service.
///   - `reminderServiceProvider` -> `NoopReminderService`, since real
///     `flutter_local_notifications` platform channels aren't available
///     under `flutter test` (matches `settings_screen_test.dart`'s existing
///     pattern). The reminder toggle defaults to off, so this is a pure
///     defensive measure — no scenario here relies on real scheduling.
///   - `httpClientProvider` -> [fakeHttpClient], since `SplashScreen` warms
///     up the story pool (`storyPoolProvider`) on every real-app pump; a
///     scenario that needs to assert on a specific fetch/refresh outcome can
///     still pass its own `httpClientProvider` override via
///     [extraOverrides] (later entries win — see `Riverpod`'s override
///     resolution).
Widget realApp(
  PreferencesService service, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      preferencesServiceProvider.overrideWithValue(service),
      reminderServiceProvider.overrideWithValue(const NoopReminderService()),
      httpClientProvider.overrideWithValue(fakeHttpClient()),
      ...extraOverrides,
    ],
    child: const App(),
  );
}

/// Pumps the real app and settles past the splash screen's brand-beat delay
/// (1400ms progress + 175ms hold, `splash_screen.dart`) onto whatever screen
/// the seeded prefs route to (onboarding or Home).
Future<void> pumpRealAppPastSplash(
  WidgetTester tester,
  PreferencesService service, {
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(realApp(service, extraOverrides: extraOverrides));
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

/// Runs the full 4-page onboarding flow (teach x3 + name capture) ending on
/// "Start playing" with [name], or "Skip for now" if [name] is null/empty.
/// Assumes `OnboardingScreen` is already the current screen.
Future<void> completeOnboarding(WidgetTester tester, {String? name}) async {
  await tester.tap(find.widgetWithText(StickerButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(StickerButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(StickerButton, 'Got it'));
  await tester.pumpAndSettle();

  if (name == null || name.isEmpty) {
    await tester.tap(find.text('Skip for now'));
  } else {
    await tester.enterText(find.byType(TextField), name);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(StickerButton, 'Start playing'));
  }
  await tester.pumpAndSettle();
}

/// Taps Home's big "Play" button and settles into the Play Loop countdown.
Future<void> tapPlayFromHome(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(StickerButton, 'Play'));
  await tester.pumpAndSettle();
}

/// Reads Home's `StatTile` value for the given [label] (e.g. `'Deaths'`,
/// `'Eternal'`, `'Survived'`) by inspecting the real widget property
/// directly, rather than the rendered `Semantics` label — this project's
/// `StatTile` sets an explicit `Semantics(label: '$label $value')` without
/// `mergeDescendants`, but the tile's own child `Text` widgets still
/// contribute their own separate (unmerged) semantics nodes, so matching on
/// the parent's exact semantics string is fragile; the widget's `value`
/// field is not.
String statTileValue(WidgetTester tester, String label) {
  final tile = tester
      .widgetList<StatTile>(find.byType(StatTile))
      .firstWhere(
        (t) => t.label == label,
        orElse: () => throw StateError('no StatTile labelled "$label" found'),
      );
  return tile.value;
}

/// Locates the single live `RunController` from wherever `PlayLoopScreen`
/// currently sits in the tree (works across repeated Play entries, since
/// each is a fresh widget instance found fresh every call).
RunController runControllerOf(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlayLoopScreen)),
  );
  return container.read(runControllerProvider.notifier);
}

/// Pumps past the full 3-2-1 countdown into `armed` (`RunConfig.defaults`:
/// countdownSteps=3 * countdownStepMs=700 = 2100ms) — same technique as
/// `play_loop_screen_test.dart`.
Future<void> pumpPastCountdown(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2200));
  await tester.pumpAndSettle();
}

/// Burns real wall-clock time so `GameClock`'s underlying real `Stopwatch`
/// (never faked — architecture v2 G1) reads meaningfully past
/// `RunConfig.minStopElapsedMs` — a `tester.pump(duration)` does not advance
/// it — before a deliberately-forced "genuine" stop, so the fast-double-tap
/// guard can never mistake an intentional forced stop for a suppressed one.
/// Shared across `test/integration/*_test.dart` (not just this file), for
/// any real-tap sequence that wants its stop tap to actually register.
void burnPastMinStopElapsed() {
  final spin = Stopwatch()..start();
  while (spin.elapsedMilliseconds <= RunConfig.defaults.minStopElapsedMs) {}
}

/// Forces a stop whose `|error|` is deterministically `offset` from the
/// controller's current live elapsed time, via the REAL `registerStop()` —
/// the sanctioned `@visibleForTesting` `state`-setter technique this
/// project's `run_controller_test.dart`/`play_loop_screen_test.dart` already
/// use. Reserved for whenever a precise tier (Hit/Miss) is required, since
/// real wall-clock tap-to-tap timing cannot reliably land inside the single
/// 180ms band (architecture v6 D2). Assumes the run just went live
/// (`startRunning()` called immediately before this).
StopTier forceStop(RunController c, Duration offset) {
  burnPastMinStopElapsed();
  final base = c.liveElapsed;
  c.state = c.state.copyWith(target: base + offset);
  c.registerStop();
  return c.state.lastTier!;
}

const hitOffset = Duration(milliseconds: 100);
const missOffset = Duration(seconds: 5);

/// Flushes the screen's post-stop flash-dwell timer (`RunConfig.flashDwellMs`
/// = 600ms) so `advanceAfterDwell()` actually fires and the phase advances
/// (re-arm / final-band / ended-and-handoff-to-outcome).
Future<void> flushDwell(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Drives whatever run is currently live to a **death**, via genuine real
/// taps on the arm plate and STOP button — deliberately real-time-driven,
/// not the state-setter for the *timing* itself: real tap-to-tap latency in
/// a test is always far below the `2.00s`-`4.90s` target range, so a Miss
/// (and, with life pre-set low, a consequent death) is reachable
/// non-flakily without ever needing to pin `target`. Exercises the real
/// `Listener`/`GestureDetector` input wiring at least once per call.
///
/// Assumes `PlayLoopScreen` is current and past the countdown (call
/// `pumpPastCountdown` first if starting fresh).
Future<void> tapThroughToQuickDeath(WidgetTester tester) async {
  final c = runControllerOf(tester);
  // Any Miss is fatal from here — guarantees termination regardless of the
  // randomized target, without pinning the target itself. 10% is a
  // genuinely reachable life value under the v6 economy (50/40/30/20/10/0),
  // unlike the old 5%.
  c.state = c.state.copyWith(lifePercent: 10);
  await tester.pump();

  // Both the start tap and the stop tap now land on the same merged
  // `PrimaryActionButton` (design spec v2 §3) — arm-then-stop is two taps
  // on the same widget, one before and one after it reskins in place.
  await tester.tap(find.byType(PrimaryActionButton));
  await tester.pump();
  // Burn real wall-clock time past `RunConfig.minStopElapsedMs` between the
  // start tap and the stop tap: unlike a genuine fast double-tap, this
  // helper wants the stop tap to actually register, not be suppressed by
  // the fast-double-tap guard (`tester.pump(duration)` does not advance the
  // real `Stopwatch` `GameClock` reads).
  burnPastMinStopElapsed();
  await tester.tap(find.byType(PrimaryActionButton));
  await tester.pump();

  await flushDwell(tester);
}

/// Forces the CURRENT run to end as `survived`, via the final-band
/// sudden-death path: pins phase to `finalBandArmed` at the (now reachable)
/// 10% final-band life value, then a Hit stop (via `forceStop` — real-time
/// timing cannot reliably land inside the 180ms Hit band).
Future<void> forceEndSurvived(WidgetTester tester) async {
  final c = runControllerOf(tester);
  c.state = c.state.copyWith(phase: RunPhase.finalBandArmed, lifePercent: 10);
  await tester.pump();
  c.startRunning();
  forceStop(c, hitOffset);
  await flushDwell(tester);
}

/// Forces the CURRENT run to end as `eternal`: `eternalHitCount` (12) Hit
/// attempts in a row from a fresh `armed` state (architecture v6 D9/§5 —
/// "first N attempts, none a Miss", redefined from the retired
/// Perfect-streak mechanic). Must be called on a genuinely fresh run
/// (attemptIndex == 0).
Future<void> forceEndEternal(WidgetTester tester) async {
  final c = runControllerOf(tester);
  if (c.state.phase != RunPhase.armed) {
    c.state = c.state.copyWith(phase: RunPhase.armed);
    await tester.pump();
  }
  for (var i = 0; i < RunConfig.defaults.eternalHitCount; i++) {
    c.startRunning();
    forceStop(c, hitOffset);
    await flushDwell(tester);
  }
}

/// Forces the CURRENT run to end as `death` directly via the state machine
/// (a Miss that drains life to 0), without relying on real-tap timing. 10%
/// is a genuinely reachable life value under the v6 economy
/// (50/40/30/20/10/0), unlike the old 5%.
Future<void> forceEndDeath(WidgetTester tester) async {
  final c = runControllerOf(tester);
  c.state = c.state.copyWith(lifePercent: 10, phase: RunPhase.armed);
  await tester.pump();
  c.startRunning();
  forceStop(c, missOffset);
  await flushDwell(tester);
}
