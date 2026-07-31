import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider;
import 'package:timing_tap/features/play_loop/domain/run_config.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/legend_pills.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/outcome_flash.dart';
import 'package:timing_tap/features/play_loop/presentation/widgets/play_hud_bar.dart';

/// Widget-level coverage for the architecture v6 binary hit/miss copy
/// changes (§6, §12 tester flag 10) that don't need a full `PlayLoopScreen`
/// pump — `LegendPills`, `OutcomeFlash`, and `PlayHudBar` are pure,
/// state-in/widget-out, so they're tested directly against hand-built
/// `RunState`s here.
///
/// Also carries regression coverage for two bugs a code-review pass just
/// fixed in `play_hud_bar.dart` (not in the architecture doc, found during
/// review):
///   (a) a Hit no longer renders any life-change arrow glyph (previously a
///       false green ▲ appeared, since life never actually moved on a Hit).
///   (b) the "N% · next miss is fatal" critical caption no longer renders
///       once life has hit exactly 0 (previously showed the nonsensical
///       "0% · next miss is fatal" on every death) — while the genuine
///       pre-fatal-attempt warning (life at 10%, final band armed, before
///       the attempt) still does show it.
void main() {
  RunState baseState({
    required RunPhase phase,
    required int lifePercent,
    StopTier? lastTier,
    bool lastStopWasFinalBand = false,
  }) {
    return RunState(
      phase: phase,
      lifePercent: lifePercent,
      target: const Duration(seconds: 3),
      runNumber: 1,
      deaths: 0,
      attemptIndex: 1,
      hitStreakIntact: true,
      peakLifePercent: 50,
      minLifePercent: lifePercent,
      lastTier: lastTier,
      lastStopElapsed: lastTier == null ? null : const Duration(seconds: 3),
      lastStopWasFinalBand: lastStopWasFinalBand,
    );
  }

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesServiceProvider.overrideWithValue(service)],
        child: MaterialApp(home: Material(child: child)),
      ),
    );
  }

  group('LegendPills (design spec v3 §3, architecture v6 D14) — exactly two '
      'pills, exact strings', () {
    testWidgets('renders exactly "Hit: safe" and "Miss: -10%", no third '
        'pill, no percentage on the Hit pill', (tester) async {
      await pumpWidget(
        tester,
        const LegendPills(finalBand: false, config: RunConfig.defaults),
      );

      expect(find.text('Hit: safe'), findsOneWidget);
      expect(find.text('Miss: -10%'), findsOneWidget);
      expect(find.textContaining('Perfect'), findsNothing);
    });

    testWidgets('the Miss pill interpolates from config.missDelta, never a '
        'hardcoded -10%', (tester) async {
      await pumpWidget(
        tester,
        const LegendPills(
          finalBand: false,
          config: RunConfig(missDelta: -25, finalBandThresholdPercent: 25),
        ),
      );

      expect(find.text('Miss: -25%'), findsOneWidget);
      expect(find.text('Miss: -10%'), findsNothing);
    });

    testWidgets('the final band replaces the two-pill row with the single '
        '"Nail it → Survive" pill', (tester) async {
      await pumpWidget(
        tester,
        const LegendPills(finalBand: true, config: RunConfig.defaults),
      );

      expect(find.text('Hit: safe'), findsNothing);
      expect(find.textContaining('Miss:'), findsNothing);
      expect(find.text('Nail it → Survive'), findsOneWidget);
    });
  });

  group('OutcomeFlash (design spec v3 §6, architecture v6 §6.4) — bare HIT, '
      'interpolated MISS', () {
    testWidgets('a normal Hit shows bare "HIT", no percentage at all', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        OutcomeFlash(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 50,
            lastTier: StopTier.hit,
          ),
        ),
      );

      expect(find.text('HIT'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a normal Miss shows "MISS -10%", interpolated from '
        'config.missDelta', (tester) async {
      await pumpWidget(
        tester,
        OutcomeFlash(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 40,
            lastTier: StopTier.miss,
          ),
        ),
      );

      expect(find.text('MISS -10%'), findsOneWidget);
    });

    testWidgets('a final-band non-miss shows "SURVIVED" with no percentage', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        OutcomeFlash(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 10,
            lastTier: StopTier.hit,
            lastStopWasFinalBand: true,
          ),
        ),
      );

      expect(find.text('SURVIVED'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a final-band Miss shows plain "MISS", no percentage even '
        'though a delta is now applied on that path (v6 §4.4)', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        OutcomeFlash(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 0,
            lastTier: StopTier.miss,
            lastStopWasFinalBand: true,
          ),
        ),
      );

      expect(find.text('MISS'), findsOneWidget);
      expect(find.text('MISS -10%'), findsNothing);
    });
  });

  group('PlayHudBar — REGRESSION (a): a Hit renders no life-change arrow '
      'glyph at all (previously a false green ▲, since life never moves on '
      'a Hit)', () {
    testWidgets('after a Hit, neither ▲ nor ▼ renders', (tester) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 50,
            lastTier: StopTier.hit,
          ),
          onPause: () {},
        ),
      );

      expect(find.textContaining('▲'), findsNothing);
      expect(find.textContaining('▼'), findsNothing);
    });

    testWidgets('after a Miss, the ▼ glyph still renders (unaffected by the '
        'Hit-arrow fix)', (tester) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 40,
            lastTier: StopTier.miss,
          ),
          onPause: () {},
        ),
      );

      expect(find.textContaining('▼'), findsOneWidget);
      expect(find.textContaining('▲'), findsNothing);
    });
  });

  group('PlayHudBar — REGRESSION (b): the critical "next miss is fatal" '
      'caption no longer renders once life has hit exactly 0', () {
    testWidgets('a death (final-band Miss landing on 0%) shows a plain '
        'caption, not the critical one', (tester) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 0,
            lastTier: StopTier.miss,
            lastStopWasFinalBand: true,
          ),
          onPause: () {},
        ),
      );

      expect(
        find.textContaining('next miss is fatal'),
        findsNothing,
        reason: 'a death caption reading "0% . next miss is fatal" is '
            'nonsensical — the run is already over',
      );
    });

    testWidgets('the genuine pre-fatal-attempt warning (life at 10%, final '
        'band armed, before the attempt) still shows the critical caption', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.finalBandArmed,
            lifePercent: 10,
          ),
          onPause: () {},
        ),
      );

      expect(find.textContaining('next miss is fatal'), findsOneWidget);
    });

    testWidgets('the genuine pre-fatal-attempt warning also shows while '
        'finalBandRunning (still before the outcome is known)', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.finalBandRunning,
            lifePercent: 10,
          ),
          onPause: () {},
        ),
      );

      expect(find.textContaining('next miss is fatal'), findsOneWidget);
    });

    testWidgets('a survived stop (final-band Hit, life stays at 10%, still '
        '> 0) legitimately still shows the critical caption in that '
        'terminal stopped frame', (tester) async {
      await pumpWidget(
        tester,
        PlayHudBar(
          state: baseState(
            phase: RunPhase.stopped,
            lifePercent: 10,
            lastTier: StopTier.hit,
            lastStopWasFinalBand: true,
          ),
          onPause: () {},
        ),
      );

      expect(find.textContaining('next miss is fatal'), findsOneWidget);
    });
  });
}
