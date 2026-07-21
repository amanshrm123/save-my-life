import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` moved to the "legacy" import in Riverpod 3.x — still the
// right tool for a single trivial nullable value like the flash band (per
// docs/design/play-screen-gate1-v1.md §3), just no longer in the default
// export.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/sound_service.dart';
import '../../core/theme.dart';
import '../../core/timing_config.dart';
import 'countdown_view.dart';
import 'run_controller.dart';
import '../timing_engine/tap_surface.dart';
import '../timing_engine/timing_engine.dart';

/// Zone D's brief hit/miss flash, or `null` when no flash is active.
/// Holds the resolved [TimingBand] (not just a color) so the floating flash
/// pill (docs/design/play-loop-v1.md §3.2) can render band-correct copy
/// (Perfect vs On-point vs Miss each have their own text/percentage) while
/// Zone D's wash still only needs the collapsed hit/miss color.
///
/// Set (and cleared 120ms later by a plain `Timer`) **after** `registerTap`
/// resolves in `PlayScreen`'s `onTapMicros` — never inside `TapSurface`'s
/// `onPointerDown` or `timing_engine.resolve()`
/// (docs/design/play-screen-gate1-v1.md §3, hard rule — still unchanged by
/// the play-loop-v1.md visual reskin).
final tapFlashBandProvider = StateProvider<TimingBand?>((ref) => null);

/// Tracks the pending flash-clear timer so a rapid second tap can cancel
/// the first tap's clear instead of racing it — otherwise tap A's 120ms
/// timer fires mid-way through tap B's flash and cuts it short. `PlayScreen`
/// is the single root Play screen, so a module-level timer is safe.
Timer? _pendingFlashClearTimer;

/// Life% tier thresholds (docs/design/play-loop-v1.md §3.1): a three-tier
/// read replacing the old binary >25%/<=25% threshold. `> 50` green,
/// `25 < life <= 50` coral, `<= 25` red — a life%-driven tier, not an
/// event-driven transient, so it needs no new state beyond `lifePct` itself.
Color _lifeBarColor(double lifePct) {
  if (lifePct > 50) return AppColors.green;
  if (lifePct > 25) return AppColors.coral;
  return AppColors.red;
}

/// Formats a `TimingConfig` life-delta as compact signed copy matching the
/// mockup's "+3%"/"-4%" style (§3.2/§3.3 — "render the sign, e.g. 'MISS
/// -4%' — don't drop it"). Whole-number values print without a trailing
/// ".0"; any genuinely fractional value keeps its decimal.
String _formatSignedLifeDelta(double value) {
  final double magnitude = value.abs();
  final String magnitudeText = magnitude == magnitude.roundToDouble()
      ? magnitude.toInt().toString()
      : magnitude.toString();
  return '${value < 0 ? '-' : '+'}$magnitudeText';
}

/// The Play screen. Branches on `RunState.phase`: `countdown` renders the
/// full-screen 3-2-1 (`CountdownView`); `playing` renders the exact-fidelity
/// rebuild from docs/design/play-loop-v2.md §3 — a content-hugging chips
/// row, a content-hugging life bar block, a single `Expanded(flex: 1)`
/// center zone (numplate + debug readout + flash pill), and a
/// content-hugging bottom control bar (legend pills + the compact tap
/// button). This replaces the prior four-way `Expanded(flex: 20/20/10/50)`
/// Column (docs/design/play-screen-skeleton-v1.md §1 /
/// docs/design/play-loop-v1.md §3) entirely — see play-loop-v2.md §3 for
/// the founder-directed rationale (fidelity over the old ergonomic/
/// data-availability calls). The `Listener`-based tap capture and all
/// timing/state logic in `run_controller.dart`/`timing_engine.dart` are
/// unchanged by this pass (play-loop-v2.md §0).
///
/// Reached either from a fresh onboarding completion (§3.3's
/// `submitName`/`skipNaming`) or, on a returning launch, via the
/// **temporary Home shim** in `app/router.dart` (Home itself is a separate,
/// not-yet-built spec — see that file for the marked hand-off point).
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RunState runState = ref.watch(runControllerProvider);

    if (runState.phase == RunPhase.countdown) {
      return const CountdownView();
    }

    final clock = ref.watch(clockProvider);
    final TimingBand? flashBand = ref.watch(tapFlashBandProvider);

    final double targetSeconds = runState.targetDurationMicros / 1000000;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Chips row (play-loop-v2.md §2.1/§3.1) — hardcoded literal
            // stub values, not a provider or counter: there is no
            // restart/death logic anywhere yet (`RunPhase` only has
            // countdown/playing, a run never ends today), so a "counter"
            // would just sit permanently at its initial value identically
            // to a literal. Days 6-11 (outcome_resolver.dart +
            // hive_profile_repository.dart lifetime counters) replaces
            // these with real values; the chip's visual shell doesn't need
            // to change when that happens. Content-hugging, not Expanded.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _Chip(label: 'Run', value: '1'),
                  _Chip(label: 'Deaths', value: '0'),
                ],
              ),
            ),

            // Life bar block (play-loop-v2.md §2.4/§3.2). Track thickness
            // 12dp (was 20 — too thick vs the mockup's `.lifebar`). The
            // meta row ("Life {n}%" / "±{n}ms") now sits BELOW the bar,
            // matching the mockup's `.lifemeta` order (the old build had it
            // above, inverted). Content-hugging, not Expanded.
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
              child: Column(
                children: [
                  _LifeBar(lifePct: runState.lifePct),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Life ${runState.lifePct.round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.splashTagline,
                        ),
                      ),
                      // Fixed tolerance readout (§0.4/§3.1 of play-loop-v1,
                      // reconfirmed unchanged by play-loop-v2.md §2.4) —
                      // always the current fixed TimingConfig.onPointMs
                      // value, never varied with lifePct (adaptive
                      // tightening is disabled; a narrowing readout would
                      // visually promise a mechanic that isn't live). The
                      // mockup's own "±64ms"/"±58ms" are illustrative
                      // static copy — do not hardcode them.
                      Text(
                        '±${TimingConfig.onPointMs}ms',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.splashTagline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Center content zone (play-loop-v2.md §2.3/§3.3) — the ONLY
            // Expanded in this Column, replacing the old Zone B (indicator +
            // numplate) and Zone C (debug readout) split. `IndicatorWidget`/
            // `_IndicatorPainter` are removed from the tree entirely (no
            // mockup counterpart at any state, and the ticker fed nothing
            // into RunController/timing_engine — see play-loop-v2.md §2.3
            // for the full removal rationale). The debug DELTA/BAND readout
            // is folded in here, still kDebugMode-gated, so release builds
            // render nothing where it was (matching the mockup exactly) and
            // debug builds keep the telemetry available.
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tap at',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            // was AppColors.mute — the mockup's "Tap at"
                            // label color is #4a5f5a, which is
                            // AppColors.teachBody, not AppColors.mute
                            // (#7b8a86) (play-loop-v2.md §3.3).
                            color: AppColors.teachBody,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _Numplate(targetSeconds: targetSeconds),
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          Text(
                            'DELTA: ${runState.lastDeltaMs == null ? '—' : '${runState.lastDeltaMs} ms'}',
                          ),
                          Text('BAND: ${_bandLabel(runState.lastBand)}'),
                        ],
                      ],
                    ),
                    if (flashBand != null)
                      Positioned(
                        top: 0,
                        child: _FlashPill(band: flashBand),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom control bar (play-loop-v2.md §2.2/§3.4) — legend
            // pills now live in their own Row, ABOVE the tap button, not
            // inside its content column. The button itself shrinks to a
            // fixed 88dp height, full width (was Expanded(flex: 50), the
            // former ~half-screen block) — a deliberate, founder-directed
            // reversal of the earlier "Zone D must stay full-size" rule
            // (play-loop-v2.md §2.2, not re-litigated here). The
            // `Listener`-based tap capture mechanism inside `TapSurface` is
            // untouched — only the container wrapping it resizes.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendPill(
                        label:
                            'Hit ${_formatSignedLifeDelta(TimingConfig.onPointLifeDelta)}%',
                      ),
                      const SizedBox(width: 10),
                      _LegendPill(
                        label:
                            'Miss ${_formatSignedLifeDelta(TimingConfig.missLifeDelta)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 88,
                    width: double.infinity,
                    child: TapSurface(
                      clock: clock,
                      onTapMicros: (int pressMicros) {
                        ref.read(runControllerProvider.notifier).registerTap(pressMicros);

                        // Flash reacts to the already-resolved tap result —
                        // strictly after registerTap returns. Never move this
                        // into TapSurface.onPointerDown or timing_engine.resolve()
                        // (play-screen-gate1-v1.md §3, hard rule).
                        final TimingBand band =
                            ref.read(runControllerProvider).lastBand!;
                        final bool isHit = band != TimingBand.miss;

                        ref.read(tapFlashBandProvider.notifier).state = band;
                        _pendingFlashClearTimer?.cancel();
                        _pendingFlashClearTimer =
                            Timer(const Duration(milliseconds: 120), () {
                          if (ref.context.mounted) {
                            ref.read(tapFlashBandProvider.notifier).state = null;
                          }
                        });

                        // Fire-and-forget — never await in the tap callback.
                        final SoundService soundService = ref.read(soundServiceProvider);
                        if (isHit) {
                          soundService.playHit();
                        } else {
                          soundService.playMiss();
                        }
                      },
                      child: _TapZone(flashBand: flashBand),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _bandLabel(TimingBand? band) {
    switch (band) {
      case TimingBand.perfect:
        return 'PERFECT';
      case TimingBand.onPoint:
        return 'ON_POINT';
      case TimingBand.miss:
        return 'MISS';
      case null:
        return '—';
    }
  }
}

/// The life bar's track (play-loop-v1.md §3.1, thickness corrected by
/// play-loop-v2.md §2.4): `AppColors.paper` track, 2px `AppColors.ink`
/// border, fully round, ~1.5dp inner padding around the fill — the same
/// shape recipe `onboarding-flow-v1.md` §5.2 already used for the splash
/// preload bar, reused here for visual consistency between the app's few
/// bar widgets. Fill color is the three-tier read (§3.1's table); width
/// still snaps on rebuild, no animation (unchanged Gate 1 call, not
/// required this pass either). Height 12dp (was 20 — thicker than the
/// mockup's `.lifebar`, confirmed and fixed per play-loop-v2.md §2.4).
class _LifeBar extends StatelessWidget {
  const _LifeBar({required this.lifePct});

  final double lifePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: (lifePct / 100).clamp(0.0, 1.0),
          child: Container(
            key: const Key('lifeBarFill'),
            decoration: BoxDecoration(
              color: _lifeBarColor(lifePct),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

/// The numplate (play-loop-v1.md §3.2, padding/line-height corrected by
/// play-loop-v2.md §2.5): `paper` fill, 2.5px ink border, radius 18, flat
/// shadow (0,4) ink, number 40sp/700 ink. The "Tap at" label above it is no
/// longer this widget's own child — play-loop-v2.md §3.3 hoists it up into
/// the center zone's outer Column, as a sibling, not a child of the
/// numplate. Number keeps the exact same source/formatting as before
/// (`targetDurationMicros / 1e6`, `toStringAsFixed(2)`) — only the
/// container chrome around it changes. Padding corrected to `horizontal:
/// 22, vertical: 9` (was `20, 6` — vertical too tight, horizontal slightly
/// under vs the mockup's `.numplate`); `height: 1.0` added to the number's
/// `TextStyle` (Flutter's default line-height is taller than 1, which
/// visually unbalanced the padding above even with the padding itself
/// fixed).
class _Numplate extends StatelessWidget {
  const _Numplate({required this.targetSeconds});

  final double targetSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Text(
        targetSeconds.toStringAsFixed(2),
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The Run/Deaths chip row's individual chip (play-loop-v2.md §2.1/§3.1):
/// `paper` fill, 2dp ink border (deliberately not the 1.5dp
/// `_LegendPill` uses — the mockup's `.chip`/`.pill` are both literally
/// `border:2px`; not in scope to retrofit `_LegendPill` this pass, flagged
/// only), fully round, a plain label + a bold value. Both this pass's
/// chips (`Run`/`1`, `Deaths`/`0`) are hardcoded literal stub values, not
/// backed by a provider or counter — see the build() doc comment above the
/// chips row for why.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating hit/miss result pill (play-loop-v1.md §3.2) — relocated
/// from Gate 1's whole-tap-zone color wash to a small pill near the
/// numplate. Band-correct copy/percentages sourced directly from
/// `TimingConfig` (never hardcoded digits — §0.4 flags the mockup's own
/// copy as inconsistent with real config values). Same 120ms hard-cut, no
/// fade, show/hide mechanics as before — only the container and position
/// changed; the "must fire strictly after registerTap resolves" rule
/// governing when this appears is unchanged (owned by `PlayScreen`, not
/// this widget).
class _FlashPill extends StatelessWidget {
  const _FlashPill({required this.band});

  final TimingBand band;

  static String _copy(TimingBand band) {
    switch (band) {
      case TimingBand.perfect:
        return 'PERFECT ${_formatSignedLifeDelta(TimingConfig.perfectLifeDelta)}%';
      case TimingBand.onPoint:
        return 'ON POINT ${_formatSignedLifeDelta(TimingConfig.onPointLifeDelta)}%';
      case TimingBand.miss:
        return 'MISS ${_formatSignedLifeDelta(TimingConfig.missLifeDelta)}%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = band == TimingBand.miss ? AppColors.red : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Text(
        _copy(band),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The tap button's chrome + content (play-loop-v1.md §3.3) — the mockup's
/// `.tapbtn` visual recipe (border/shadow/radius/text-shadow) copied by
/// hand onto the Listener-wrapped container (do not reuse
/// `StickerButton`: it wraps a `GestureDetector`, banned in the
/// tap-capture path — `play-screen-skeleton-v1.md` §1). This widget is
/// purely decorative/content; the `Listener` capture wrapping it in
/// `PlayScreen` is untouched. Per play-loop-v2.md §2.2/§3.4, this widget no
/// longer renders the Hit/Miss legend pills as its own trailing content —
/// they've moved out into their own `Row` above the (now compact, 88dp
/// fixed-height) button in `PlayScreen`'s bottom control bar. Everything
/// else about this widget's decoration (coral fill / flash-color-on-tap,
/// 2.5dp ink border, radius 22, flat shadow, "TAP" + shadowed text, "land
/// on the number" caption) is unchanged.
class _TapZone extends StatelessWidget {
  const _TapZone({required this.flashBand});

  final TimingBand? flashBand;

  @override
  Widget build(BuildContext context) {
    final Color fill = flashBand == null
        ? AppColors.coral
        : (flashBand == TimingBand.miss ? AppColors.red : AppColors.green);
    // The "TAP" label's text-shadow must match the current fill, not stay
    // a fixed coral tone — a coral shadow on a green/red flash background
    // reads as a mismatch (tester pass, on-device finding).
    final Color labelShadow = flashBand == null
        ? AppColors.coralDark
        : (flashBand == TimingBand.miss ? AppColors.redDark : AppColors.greenDark);

    return Container(
      key: const Key('zoneDContainer'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 6), blurRadius: 0),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TAP',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: [
                  Shadow(color: labelShadow, offset: const Offset(0, 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'land on the number',
              style: TextStyle(fontSize: 9, color: Colors.white70),
            ),
            // NOTE: no legend pills here anymore — moved to their own Row
            // above the button in PlayScreen's bottom control bar, per
            // play-loop-v2.md §2.2/§3.4.
          ],
        ),
      ),
    );
  }
}

/// A single legend pill (play-loop-v1.md §3.3): `AppColors.paper` pill
/// chrome, static informational text.
class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
