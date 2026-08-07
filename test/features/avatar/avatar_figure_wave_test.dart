import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/avatar/domain/avatar_catalog.dart';
import 'package:timing_tap/features/avatar/presentation/widgets/avatar_figure.dart';

/// Coverage for juice spec effect 1 (`AvatarFigure.continuousWave`), added
/// per a code-review pass that flagged two gaps:
///   1. HIGH #1's fix itself — the wavy fill's top edge must never be
///      sampled outside the vessel's own vertical bounds
///      (`[_shoulderY, _baseY]` = `[60, 100]`), regardless of amplitude or
///      how low `fillPercent` is — otherwise the silhouette could flicker
///      to fully "empty" (near-death) or show a gap at the very top
///      (near-full). Exercised directly against `avatarWaveYClamped`, the
///      `@visibleForTesting` pure function `_wavyFillPath` was refactored to
///      delegate to, since `_AvatarFigurePainter` itself is a private class
///      not reachable from this library.
///   2. Reduce Motion (`MediaQuery.disableAnimations`) with `continuousWave:
///      true` — zero prior coverage anywhere in the repo (confirmed via
///      grep). This exercises `AvatarFigure` end-to-end through rapid
///      `fillPercent` churn under Reduce Motion and asserts it never
///      crashes; the "amplitude forced to zero" claim itself is proven at
///      the pure-function level below (an amplitude of exactly `0` collapses
///      `avatarWaveYClamped` to the flat `fillTop`, which is what
///      `_AvatarFigureState.build` actually passes once
///      `MediaQuery.disableAnimations` is true).
void main() {
  group('avatarWaveYClamped (code-review fix HIGH #1)', () {
    // Mirrors `_AvatarFigurePainter`'s own private constants exactly —
    // duplicated here deliberately (rather than importing them, which isn't
    // possible for a private class) since this test's whole point is to
    // pin the PUBLIC contract of the exposed pure function against the
    // vessel's real geometry.
    const shoulderY = 60.0;
    const baseY = 100.0;
    const unitWidth = 84.0;

    test(
      'critical-life fill (near _baseY) + boosted wave amplitude never '
      'samples below _shoulderY or above _baseY — the exact "silhouette '
      'disappears near death" bug this pass fixed',
      () {
        // fillPercent 3-6%, floored by the painter's own
        // `_kMinVisibleFillPercent` (6) before `_fillTop()` computes this:
        // fillTop = baseY - vesselHeight(40) * 0.06 = 97.6.
        const criticalFillTop = 97.6;
        // Base (2.5) + boost (3.0) amplitude, i.e. a fill change actively
        // "sloshing" while the avatar is nearly dead.
        const boostedAmplitude = 2.5 + 3.0;

        // Sanity check FIRST: without the clamp, this exact scenario WOULD
        // overshoot _baseY (proving the test scenario genuinely stresses
        // the fix, not just trivially staying in-bounds already). The
        // secondary sine can add up to 40% more on top of the primary.
        final worstCaseUnclamped = criticalFillTop + boostedAmplitude * 1.4;
        expect(
          worstCaseUnclamped,
          greaterThan(baseY),
          reason:
              'this scenario must genuinely be capable of pushing the raw '
              'sample past _baseY, otherwise the clamp below proves nothing',
        );

        for (var phaseStep = 0; phaseStep < 40; phaseStep++) {
          final wavePhase = phaseStep / 40 * 2 * pi;
          for (var xStep = 0; xStep <= 20; xStep++) {
            final x = unitWidth * xStep / 20;
            final y = avatarWaveYClamped(
              fillTop: criticalFillTop,
              waveAmplitude: boostedAmplitude,
              wavePhase: wavePhase,
              x: x,
              unitWidth: unitWidth,
              shoulderY: shoulderY,
              baseY: baseY,
            );
            expect(
              y,
              inInclusiveRange(shoulderY, baseY),
              reason:
                  'waveY($x) at phase $wavePhase escaped [_shoulderY, _baseY] for a '
                  'critical, boosted fill — the fill silhouette would visibly '
                  'disappear/gap',
            );
          }
        }
      },
    );

    test(
      'near-full fill (near _shoulderY) + boosted wave amplitude never '
      'samples below _shoulderY or above _baseY — the mirror-image "gap at '
      'the top" case',
      () {
        // fillPercent 100 -> fillTop = _shoulderY exactly.
        const nearFullFillTop = shoulderY;
        const boostedAmplitude = 2.5 + 3.0;

        final worstCaseUnclamped = nearFullFillTop - boostedAmplitude * 1.4;
        expect(
          worstCaseUnclamped,
          lessThan(shoulderY),
          reason:
              'this scenario must genuinely be capable of pushing the raw '
              'sample past _shoulderY, otherwise the clamp below proves nothing',
        );

        for (var phaseStep = 0; phaseStep < 40; phaseStep++) {
          final wavePhase = phaseStep / 40 * 2 * pi;
          for (var xStep = 0; xStep <= 20; xStep++) {
            final x = unitWidth * xStep / 20;
            final y = avatarWaveYClamped(
              fillTop: nearFullFillTop,
              waveAmplitude: boostedAmplitude,
              wavePhase: wavePhase,
              x: x,
              unitWidth: unitWidth,
              shoulderY: shoulderY,
              baseY: baseY,
            );
            expect(y, inInclusiveRange(shoulderY, baseY));
          }
        }
      },
    );

    test(
      'zero amplitude (Reduce Motion) collapses to exactly the flat fillTop '
      '— i.e. Reduce Motion genuinely removes the wave rather than merely '
      'shrinking it',
      () {
        const fillTop = 82.3;
        for (var xStep = 0; xStep <= 10; xStep++) {
          final x = unitWidth * xStep / 10;
          final y = avatarWaveYClamped(
            fillTop: fillTop,
            waveAmplitude: 0,
            wavePhase: 1.2345, // arbitrary — must not matter at amplitude 0
            x: x,
            unitWidth: unitWidth,
            shoulderY: shoulderY,
            baseY: baseY,
          );
          expect(y, fillTop);
        }
      },
    );
  });

  group('AvatarFigure(continuousWave: true) under Reduce Motion', () {
    testWidgets(
      'rapid fillPercent churn (including a very low, near-death value) '
      'never crashes with MediaQuery.disableAnimations true — zero prior '
      'coverage of this combination anywhere in the repo',
      (tester) async {
        final spec = AvatarCatalog.byId(0);

        Widget build(int fillPercent) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 84,
                  height: 104,
                  child: AvatarFigure(
                    spec: spec,
                    fillPercent: fillPercent,
                    continuousWave: true,
                  ),
                ),
              ),
            ),
          ),
        );

        // Settle at a normal fill, then churn down to a critical/near-death
        // fill and back up while a fill-ease "slosh" would otherwise be in
        // flight (`fillController.isAnimating`) — the exact combination the
        // wave-boost logic exists for, just under Reduce Motion.
        await tester.pumpWidget(build(80));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(build(4));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(build(95));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(build(4));
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(AvatarFigure),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
