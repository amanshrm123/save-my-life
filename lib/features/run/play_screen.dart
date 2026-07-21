import 'dart:async';

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
import '../timing_engine/indicator_painter.dart';
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
/// full-screen 3-2-1 (`CountdownView`); `playing` renders the 4-zone
/// Column from the Days 1-2 skeleton (docs/design/play-screen-skeleton-v1.md
/// §1) — Zone A life meter, Zone B indicator + numplate, Zone C debug
/// readout, Zone D tap surface — reskinned per
/// docs/design/play-loop-v1.md §3 (paper/ink/flat-shadow chrome, floating
/// band-correct flash pill, three-tier life bar) on top of the
/// docs/design/play-screen-gate1-v1.md §§1-3 behavior. Zone proportions,
/// the `Listener`-based tap capture, and all timing/state logic in
/// `run_controller.dart`/`timing_engine.dart` are unchanged by this pass.
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
            // Zone A — life meter (play-loop-v1.md §3.1). Same ~20% flex
            // as Gate 1 — this pass only restyles the fill/track, it
            // doesn't touch proportions.
            Expanded(
              flex: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIFE: ${runState.lifePct.round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        // Fixed tolerance readout (§0.4/§3.1) — always the
                        // current fixed TimingConfig.onPointMs value, never
                        // varied with lifePct (adaptive tightening is
                        // disabled for v1; a narrowing readout would
                        // visually promise a mechanic that isn't live).
                        Text(
                          '±${TimingConfig.onPointMs}ms',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _LifeBar(lifePct: runState.lifePct),
                  ],
                ),
              ),
            ),

            // Zone B — indicator + numplate (play-loop-v1.md §3.2). The
            // floating flash pill is positioned here via Stack, roughly at
            // this zone's center, near the numplate it reacts to.
            Expanded(
              flex: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Numplate(targetSeconds: targetSeconds),
                        const SizedBox(height: 4),
                        Expanded(
                          child: IndicatorWidget(
                            clock: clock,
                            roundStartMicros: runState.roundStartMicros,
                            targetDurationMicros: runState.targetDurationMicros,
                          ),
                        ),
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

            // Zone C — debug readout (~10%), unchanged by this pass. Holds
            // prior tap's result until the next tap overwrites it; shows
            // "—" before the first tap.
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DELTA: ${runState.lastDeltaMs == null ? '—' : '${runState.lastDeltaMs} ms'}',
                    ),
                    Text('BAND: ${_bandLabel(runState.lastBand)}'),
                  ],
                ),
              ),
            ),

            // Zone D — tap surface, bottom half of the screen (~50%),
            // reskinned per play-loop-v1.md §3.3: mockup `.tapbtn` chrome
            // applied to the existing full-size Listener-wrapped Container
            // — Zone D's size/the Listener capture mechanism are untouched,
            // only decoration/child content changes.
            Expanded(
              flex: 50,
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

/// Zone A's life bar (play-loop-v1.md §3.1): `AppColors.paper` track, 2px
/// `AppColors.ink` border, fully round, ~1.5dp inner padding around the
/// fill — the same shape recipe `onboarding-flow-v1.md` §5.2 already used
/// for the splash preload bar, reused here for visual consistency between
/// the app's few bar widgets. Fill color is the three-tier read (§3.1's
/// table); width still snaps on rebuild, no animation (unchanged Gate 1
/// call, not required this pass either).
class _LifeBar extends StatelessWidget {
  const _LifeBar({required this.lifePct});

  final double lifePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
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

/// Zone B/C's numplate (play-loop-v1.md §3.2): replaces the bare
/// `TARGET: {n}s` debug text with `paper` fill, 2.5px ink border, radius
/// 18, flat shadow (0,4) ink, number 40sp/700 ink, a small "Tap at" label
/// above. Number keeps the exact same source/formatting as before
/// (`targetDurationMicros / 1e6`, `toStringAsFixed(2)`) — only the
/// container chrome around it changes.
class _Numplate extends StatelessWidget {
  const _Numplate({required this.targetSeconds});

  final double targetSeconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Tap at',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.mute,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            ),
          ),
        ),
      ],
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

/// Zone D's chrome + content (play-loop-v1.md §3.3) — the mockup's
/// `.tapbtn` visual recipe (border/shadow/radius/text-shadow) copied by
/// hand onto the *existing full-size* container (do not reuse
/// `StickerButton`: it wraps a `GestureDetector`, banned in the
/// tap-capture path — `play-screen-skeleton-v1.md` §1). This widget is
/// purely decorative/content; the `Listener` capture wrapping it in
/// `PlayScreen` is untouched.
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
            const SizedBox(height: 14),
            // Legend pills — static, unchanged regardless of run state,
            // sourced from TimingConfig (§0.4/§3.3), not the mockup's
            // literal "35%".
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendPill(
                  label:
                      'Hit ${_formatSignedLifeDelta(TimingConfig.onPointLifeDelta)}%',
                ),
                const SizedBox(width: 8),
                _LegendPill(
                  label:
                      'Miss ${_formatSignedLifeDelta(TimingConfig.missLifeDelta)}%',
                ),
              ],
            ),
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
