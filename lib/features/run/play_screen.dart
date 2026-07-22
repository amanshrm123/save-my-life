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
/// resolves in `PlayScreen`'s tap handler — never inside `TapSurface`'s
/// `onPointerDown` or `timing_engine.resolve()`
/// (docs/design/play-screen-gate1-v1.md §3, hard rule — still unchanged by
/// the v2/v3 visual passes). This wash is fully independent of the v3 flying
/// result pill's own 460ms animation clock (play-loop-v3.md §1.4) — they're
/// two separate triggers reading the same tap result.
final tapFlashBandProvider = StateProvider<TimingBand?>((ref) => null);

/// Life% tier thresholds (docs/design/play-loop-v1.md §3.1): a three-tier
/// read replacing the old binary >25%/<=25% threshold. `> 50` green,
/// `25 < life <= 50` coral, `<= 25` red — a life%-driven tier, not an
/// event-driven transient, so it needs no new state beyond `lifePct` itself.
Color _lifeBarColor(double lifePct) {
  if (lifePct > 50) return AppColors.green;
  if (lifePct > 25) return AppColors.coral;
  return AppColors.red;
}

/// Formats a life-delta value as compact signed copy matching the mockup's
/// "+3%"/"-4%" style (§3.2/§3.3 — "render the sign, e.g. 'MISS -4%' — don't
/// drop it"). Whole-number values print without a trailing ".0"; any
/// genuinely fractional value keeps its decimal. Since architecture v3 §4
/// made On-point/Miss deltas ranged, callers now pass the *actual* rolled
/// value (`RunState.lastLifeDelta`) rather than a `TimingConfig` constant —
/// this formatter itself is unchanged, only what's passed to it.
String _formatSignedLifeDelta(double value) {
  final double magnitude = value.abs();
  final String magnitudeText = magnitude == magnitude.roundToDouble()
      ? magnitude.toInt().toString()
      : magnitude.toString();
  return '${value < 0 ? '-' : '+'}$magnitudeText';
}

/// The Play screen. Branches on `RunState.phase`: `countdown` renders the
/// full-screen 3-2-1 (`CountdownView`); `dead` renders the minimal
/// `_DeathPlaceholder` (architecture v3 §3.5, play-loop-v3.md §3) — a
/// full-screen replacement, not a modal overlay, structurally identical to
/// the `countdown` early-return; `playing` renders the exact-fidelity
/// rebuild from docs/design/play-loop-v2.md §3, extended by v3: chips now
/// read the real persisted `deathCount` (item 1), life starts at 100%
/// (item 2), Hit/Miss deltas are rolled within ranges and the flash pill
/// shows the actual rolled value (item 4), and the result pill flies from
/// the tap button to the numplate via a `Stack` overlay +
/// `AnimationController` (item 5, play-loop-v3.md §1) — the one element the
/// Gate-1 animation ban is lifted for (architecture v3 §7). v4 walks back
/// v3 item 3 (architecture v4 §1): the numplate keeps its `TapSurface` but
/// the callback is now an inert no-op — the bottom TAP button is the sole
/// scoring input — and the legend pills (v4 §2) now show each band's live
/// most-recent rolled value instead of a static range.
///
/// Promoted from `ConsumerWidget` to `ConsumerStatefulWidget` (architecture
/// v3 §7.3's suggested structure) purely to own the flight
/// `AnimationController` and the `GlobalKey`s the flight math needs; no
/// other behavior depends on this being stateful.
///
/// Reached either from a fresh onboarding completion (§3.3's
/// `submitName`/`skipNaming`) or, on a returning launch, via the
/// **temporary Home shim** in `app/router.dart` (Home itself is a separate,
/// not-yet-built spec — see that file for the marked hand-off point).
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with SingleTickerProviderStateMixin {
  /// Tracks the pending flash-clear timer so a rapid second tap can cancel
  /// the first tap's clear instead of racing it — otherwise tap A's 120ms
  /// timer fires mid-way through tap B's flash and cuts it short. Moved
  /// from a module-level variable to an instance field now that `PlayScreen`
  /// is stateful (one `PlayScreen` instance per screen, same lifetime
  /// guarantee as before).
  Timer? _pendingFlashClearTimer;

  /// Drives the flying result pill (play-loop-v3.md §1) — the one place in
  /// the codebase the Gate-1 `AnimationController` ban is lifted
  /// (architecture v3 §7). 460ms total: launch/travel overlap 0-260ms, dwell
  /// 260-370ms, fade-out 370-460ms (§1.2).
  late final AnimationController _flightController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Opacity: fade in 0-50ms (weight 10.9), hold, fade out 370-460ms
  /// (weight 19.6) — play-loop-v3.md §1.2, weights match the ms breakdown
  /// exactly (10.9 / 69.5 / 19.6).
  late final Animation<double> _opacityAnimation = TweenSequence<double>([
    TweenSequenceItem(
      weight: 10.9,
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
    ),
    TweenSequenceItem(weight: 69.5, tween: ConstantTween(1.0)),
    TweenSequenceItem(
      weight: 19.6,
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
    ),
  ]).animate(_flightController);

  /// Scale: 0.85 -> 1.0 over the launch window only, then pinned at 1.0
  /// (play-loop-v3.md §1.2).
  late final Animation<double> _scaleAnimation = TweenSequence<double>([
    TweenSequenceItem(
      weight: 10.9,
      tween: Tween(
        begin: 0.85,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
    ),
    TweenSequenceItem(weight: 89.1, tween: ConstantTween(1.0)),
  ]).animate(_flightController);

  /// The single, screen-lifetime `CurvedAnimation` behind
  /// [_positionAnimation]. `CurvedAnimation`'s constructor calls
  /// `parent.addStatusListener(...)` and the only way to remove that
  /// listener is `CurvedAnimation.dispose()` — constructing a fresh one on
  /// every tap (as [_launchFlight] used to) would leak one status listener
  /// per scored tap onto `_flightController` for the rest of the run, since
  /// nothing ever disposes the old ones. Built once here (parented to
  /// `_flightController` with the fixed travel `Interval`, play-loop-v3.md
  /// §1.2/§1.3) and disposed alongside the controller in [dispose]; each tap
  /// only rebuilds the `Tween<double>` (the begin/end anchors, which do
  /// change per tap) and re-`animate()`s it onto this one reused curve.
  late final CurvedAnimation _flightCurve = CurvedAnimation(
    parent: _flightController,
    // 0.565 * 460ms ~= 260ms travel window (play-loop-v3.md §1.2); Interval
    // pins its output at 1.0 for any t past 0.565, so the position is
    // automatically held at the arrival point for the dwell/fade-out phases
    // with no extra clamping logic needed.
    curve: const Interval(0.0, 0.565, curve: Curves.easeOut),
  );

  /// Position (Y only — button and numplate share the same horizontal
  /// center in this single-column layout, so the general `Tween<Offset>`
  /// architecture frames this as collapses to one dimension, play-loop-v3.md
  /// §1.3). The `Tween` itself is rebuilt fresh on every tap in
  /// [_launchFlight] since the begin/end anchors are only known once
  /// `registerTap` has resolved and the real `RenderBox` positions can be
  /// measured — but it's always re-`animate()`d onto the single reused
  /// [_flightCurve], never a fresh `CurvedAnimation`. `null` before the
  /// first tap of the run — the flight layer simply isn't visible yet
  /// (opacity starts at the controller's rest value, 0).
  Animation<double>? _positionAnimation;

  /// Fallback top position used only before [_positionAnimation] exists
  /// (pre-first-tap). Never visible (opacity is 0 at rest) — just avoids a
  /// null-position edge case in the `AnimatedBuilder`.
  double _flightRestTop = 0;

  /// Anchor for the button's visible content box (its `SizedBox(height:
  /// 88)`), read via `RenderBox` — never a hardcoded pixel offset
  /// (play-loop-v3.md §1.3).
  final GlobalKey _buttonKey = GlobalKey();

  /// Anchor for `_Numplate`'s own container.
  final GlobalKey _numplateKey = GlobalKey();

  /// The overlay `Stack`'s own box — the coordinate space every anchor is
  /// converted into before building the position `Tween`.
  final GlobalKey _overlayKey = GlobalKey();

  /// The flying pill's own box — measured for its height only (constant
  /// across all three band labels, play-loop-v3.md §1.3; only width varies
  /// with text length), used to convert the spec's bottom-edge anchors into
  /// the `Positioned.top` value this `Tween` actually animates.
  final GlobalKey _pillKey = GlobalKey();

  @override
  void dispose() {
    _pendingFlashClearTimer?.cancel();
    _flightCurve.dispose();
    _flightController.dispose();
    super.dispose();
  }

  /// Tap handler for the bottom TAP button's `TapSurface` — as of v4 gap 1
  /// (architecture v4 §1), it is the **sole scoring input**: the numplate's
  /// `TapSurface` is intentionally wired to an empty no-op callback instead
  /// of this handler (see the `_Numplate` `TapSurface` below). Each
  /// `TapSurface` still captures its own timestamp in its own
  /// `onPointerDown` (the per-`Listener` hard rule is unchanged).
  void _handleTap(int pressMicros) {
    // Captured before calling registerTap so the no-op check below is
    // independent of `lastBand` (which persists across taps — only
    // `startNewCycle()` clears it — and so cannot distinguish "this tap
    // was a no-op" from "the *previous* tap already set a band"). Checking
    // the phase directly matches the exact guard `registerTap` itself uses
    // (architecture v3 §3.3: `if (state.phase != RunPhase.playing) return`),
    // so this stays correct even if a future change to widget structure ever
    // let the button's `TapSurface` outlive `phase == playing`.
    final RunPhase phaseBeforeTap = ref.read(runControllerProvider).phase;
    ref.read(runControllerProvider.notifier).registerTap(pressMicros);

    if (phaseBeforeTap != RunPhase.playing) {
      // registerTap is a no-op when phase != playing (architecture v3
      // §3.3) — the button's TapSurface only exists while phase ==
      // playing, so this shouldn't be reachable, but guard rather than
      // crash.
      return;
    }

    // Flash/animation react to the already-resolved tap result — strictly
    // after registerTap returns. Never move this into TapSurface's
    // onPointerDown or timing_engine.resolve() (play-screen-gate1-v1.md §3 /
    // architecture v3 §7.2, hard rule, unchanged).
    final RunState afterTap = ref.read(runControllerProvider);
    // Non-null: registerTap always sets lastBand whenever it actually
    // processes a tap (phaseBeforeTap == playing, checked above).
    final TimingBand band = afterTap.lastBand!;
    final bool isHit = band != TimingBand.miss;

    ref.read(tapFlashBandProvider.notifier).state = band;
    _pendingFlashClearTimer?.cancel();
    _pendingFlashClearTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        ref.read(tapFlashBandProvider.notifier).state = null;
      }
    });

    // The flying pill is a second, fully independent trigger reading the
    // same tap result at the same moment — its own 460ms clock, never
    // coupled to the 120ms wash timer above (play-loop-v3.md §1.4).
    _launchFlight();

    // Fire-and-forget — never await in the tap callback.
    final SoundService soundService = ref.read(soundServiceProvider);
    if (isHit) {
      soundService.playHit();
    } else {
      soundService.playMiss();
    }
  }

  /// Measures the button/numplate/pill anchors via their `GlobalKey`s and
  /// (re)starts the flight animation from the button towards the numplate.
  /// Called only from [_handleTap], strictly after `registerTap` has
  /// resolved (architecture v3 §7.2).
  void _launchFlight() {
    final RenderBox? overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? numplateBox =
        _numplateKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? pillBox =
        _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null ||
        buttonBox == null ||
        numplateBox == null ||
        pillBox == null) {
      // Not yet laid out (shouldn't happen once phase == playing has ever
      // rendered a frame) — skip this flight rather than crash.
      return;
    }

    final double pillHeight = pillBox.size.height;
    final double buttonTopY = overlayBox
        .globalToLocal(buttonBox.localToGlobal(Offset.zero))
        .dy;
    final double numplateTopY = overlayBox
        .globalToLocal(numplateBox.localToGlobal(Offset.zero))
        .dy;

    // Anchors measured from the pill's own bottom edge (play-loop-v3.md
    // §1.3): launch 4dp above the button's top edge ("popping off the
    // button"), arrival 40dp above the numplate's top edge (clears the
    // whole "Tap at" + numplate cluster with margin).
    final double launchTop = buttonTopY - 4 - pillHeight;
    final double arrivalTop = numplateTopY - 40 - pillHeight;
    _flightRestTop = launchTop;

    // Reuses the single screen-lifetime [_flightCurve] — never construct a
    // fresh `CurvedAnimation` here (that would add another status listener
    // to `_flightController` on every tap with no way to remove it; see
    // [_flightCurve]'s doc comment). Only the `Tween`'s begin/end anchors
    // are rebuilt per tap.
    _positionAnimation = Tween<double>(
      begin: launchTop,
      end: arrivalTop,
    ).animate(_flightCurve);

    // Snap-away restart, never queued or blended: forward(from: 0.0)
    // unconditionally resets the controller regardless of its current
    // status (play-loop-v3.md §1.5) — a mid-flight pill's opacity/position
    // snap back to the launch anchor within the same frame, then the same
    // 460ms sequence begins again for the new tap's result.
    _flightController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final RunState runState = ref.watch(runControllerProvider);

    if (runState.phase == RunPhase.countdown) {
      return const CountdownView();
    }

    if (runState.phase == RunPhase.dead) {
      return _DeathPlaceholder(deathCount: runState.deathCount);
    }

    final clock = ref.watch(clockProvider);
    final TimingBand? flashBand = ref.watch(tapFlashBandProvider);

    final double targetSeconds = runState.targetDurationMicros / 1000000;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          key: _overlayKey,
          children: [
            Column(
              children: [
                // Chips row (play-loop-v2.md §2.1/§3.1, values now real per
                // architecture v3 §3.2/item 1): `Run` = deathCount + 1 (the
                // attempt currently being played), `Deaths` = deathCount
                // (lifetime, seeded from `ProfileRepository` and
                // incremented in-memory on death). Content-hugging, not
                // Expanded.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Chip(label: 'Run', value: '${runState.deathCount + 1}'),
                      _Chip(label: 'Deaths', value: '${runState.deathCount}'),
                    ],
                  ),
                ),

                // Life bar block (play-loop-v2.md §2.4/§3.2). Track
                // thickness 12dp. The meta row ("Life {n}%" / "±{n}ms") sits
                // below the bar. Content-hugging, not Expanded.
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
                          // Fixed tolerance readout, always the current
                          // fixed TimingConfig.onPointMs value, never varied
                          // with lifePct (adaptive tightening is disabled).
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

                // Center content zone (play-loop-v2.md §2.3/§3.3, extended
                // by v3 item 3/§5, walked back by v4 §1): the numplate is
                // still wrapped in a second `TapSurface` (play-loop-v3.md
                // §2.2's exact `28h/24v` padding, a generous, forgiving hit
                // area) but that surface's callback is now an inert no-op —
                // see the `onTapMicros` comment below — the bottom TAP
                // button is the sole scoring input as of v4. No new visual
                // affordance on the numplate itself. The old static
                // `Positioned(top: 0, _FlashPill(...))` is gone entirely —
                // the flight layer (below, in the outer Stack) is now the
                // only place the result pill renders, so this zone no
                // longer needs its own `Stack`. The debug DELTA/BAND
                // readout is still kDebugMode-gated.
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tap at',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teachBody,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TapSurface(
                          clock: clock,
                          // v4 gap 1: the numplate is deliberately
                          // tappable-but-INERT this phase. It MUST NOT
                          // score — no registerTap, no life change, no
                          // flash, no flight. The bottom TAP button is the
                          // sole scoring input (architecture v4 §1). This
                          // empty callback is intentional and load-bearing,
                          // NOT half-wired/dead code: the TapSurface is
                          // kept so the number still absorbs touches (a tap
                          // on the number reads as "pressed but nothing
                          // happened", never falls through to a surface
                          // behind it) and as a forward-compatible
                          // placeholder for a possible future *non-scoring*
                          // numplate action. Do not "fix" this by wiring it
                          // back to _handleTap.
                          onTapMicros: (_) {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 24,
                            ),
                            child: _Numplate(
                              key: _numplateKey,
                              targetSeconds: targetSeconds,
                            ),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          Text(
                            'DELTA: ${runState.lastDeltaMs == null ? '—' : '${runState.lastDeltaMs} ms'}',
                          ),
                          Text('BAND: ${_bandLabel(runState.lastBand)}'),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom control bar (play-loop-v2.md §2.2/§3.4) — legend
                // pills above the compact 88dp tap button, unchanged in
                // shape by v3/v4 (v3 item 4 first changed the pills' *text*
                // to a static range; v4 §2 changes it again, to each band's
                // live most-recent rolled value — the pill chrome itself is
                // still untouched). The button's own `Listener`-based tap
                // capture is untouched.
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
                                'Hit ${_formatSignedLifeDelta(runState.lastHitLifeDelta)}%',
                          ),
                          const SizedBox(width: 10),
                          _LegendPill(
                            label:
                                'Miss ${_formatSignedLifeDelta(runState.lastMissLifeDelta)}%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        key: _buttonKey,
                        height: 88,
                        width: double.infinity,
                        child: TapSurface(
                          clock: clock,
                          onTapMicros: _handleTap,
                          child: _TapZone(flashBand: flashBand),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // The flying result pill (play-loop-v3.md §1) — layered above
            // the Column so it can travel across regions that belong to
            // different parts of it (the button and the numplate). Wrapped
            // in `IgnorePointer` so a mid-flight pill drifting over the
            // numplate's tap-target region never silently eats a tap meant
            // for it (play-loop-v3.md §1.6, load-bearing).
            AnimatedBuilder(
              animation: _flightController,
              builder: (context, _) {
                final double top = _positionAnimation?.value ?? _flightRestTop;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: _FlashPill(
                            key: _pillKey,
                            band: runState.lastBand ?? TimingBand.onPoint,
                            lifeDelta: runState.lastLifeDelta ?? 0.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
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

/// The minimal death-cycle placeholder (architecture v3 §3.5, play-loop-v3.md
/// §3) — a full-screen replacement (matching the eventual Days 6-11 outcome
/// card's own full-screen structure), NOT a modal overlay. Deliberately
/// un-designed: no death-line copy pool, no art, no share, no badge/skull
/// chrome — those are the real outcome card's job. `ConsumerWidget` rather
/// than the doc's illustrative `StatelessWidget` sketch, since it needs
/// `ref` to call `startNewCycle()`.
class _DeathPlaceholder extends ConsumerWidget {
  const _DeathPlaceholder({required this.deathCount});

  final int deathCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You died',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              // Reused verbatim — same widget class already built for the
              // top bar's chip row, zero new visual vocabulary.
              _Chip(label: 'Deaths', value: '$deathCount'),
              const SizedBox(height: 32),
              GestureDetector(
                // Ordinary UI navigation, not the latency-critical
                // tap-capture path — `GestureDetector` is correct here, the
                // `Listener`-only rule doesn't apply (play-loop-v3.md §3.2).
                onTap: () =>
                    ref.read(runControllerProvider.notifier).startNewCycle(),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Text(
                    'Play again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The life bar's track (play-loop-v1.md §3.1, thickness corrected by
/// play-loop-v2.md §2.4): `AppColors.paper` track, 2px `AppColors.ink`
/// border, fully round, ~1.5dp inner padding around the fill. Fill color is
/// the three-tier read (§3.1's table); width still snaps on rebuild, no
/// animation.
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
/// shadow (0,4) ink, number 40sp/700 ink. v3 item 3 (architecture v3 §6.2,
/// play-loop-v3.md §2.1) wrapped this in an outer `TapSurface` + padding in
/// `PlayScreen`'s build() to make it a real tap target; v4 gap 1
/// (architecture v4 §1) keeps that `TapSurface` wrapper but makes its
/// callback an inert no-op — the numplate stays touch-responsive but no
/// longer scores. This widget's own chrome is deliberately unchanged either
/// way (no pressed-state affordance, per play-loop-v3.md §2.1's explicit
/// call).
class _Numplate extends StatelessWidget {
  const _Numplate({super.key, required this.targetSeconds});

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
/// `paper` fill, 2dp ink border, fully round, a plain label + a bold value.
/// Values are now provider-backed (architecture v3 §3.2/item 1) instead of
/// hardcoded literals; the chip shell itself is unchanged. Also reused
/// verbatim by `_DeathPlaceholder` for its "Deaths" readout
/// (play-loop-v3.md §3.2).
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

/// The hit/miss result pill's chrome (play-loop-v1.md §3.2, play-loop-v3.md
/// §1.1) — reused *verbatim*, unrestyled, as both the static chrome
/// reference and the widget that now flies from the tap button to the
/// numplate (`_PlayScreenState`'s `AnimatedBuilder` wraps this in
/// `Opacity`/`Transform.scale`/`Positioned`, but never changes this widget's
/// own decoration). [lifeDelta] is the *actual* rolled value for this tap
/// (`RunState.lastLifeDelta`), not a `TimingConfig` constant — architecture
/// v3 §4.3, since On-point/Miss deltas are now ranged.
class _FlashPill extends StatelessWidget {
  const _FlashPill({super.key, required this.band, required this.lifeDelta});

  final TimingBand band;
  final double lifeDelta;

  static String _copy(TimingBand band, double lifeDelta) {
    switch (band) {
      case TimingBand.perfect:
        return 'PERFECT ${_formatSignedLifeDelta(lifeDelta)}%';
      case TimingBand.onPoint:
        return 'ON POINT ${_formatSignedLifeDelta(lifeDelta)}%';
      case TimingBand.miss:
        return 'MISS ${_formatSignedLifeDelta(lifeDelta)}%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = band == TimingBand.miss
        ? AppColors.red
        : AppColors.green;
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
        _copy(band, lifeDelta),
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
/// `.tapbtn` visual recipe copied by hand onto the Listener-wrapped
/// container (do not reuse `StickerButton`: it wraps a `GestureDetector`,
/// banned in the tap-capture path). Unchanged by v3 — item 3 adds a
/// *second* tap surface elsewhere; this button and its wash stay exactly as
/// they were.
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
        : (flashBand == TimingBand.miss
              ? AppColors.redDark
              : AppColors.greenDark);

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
          ],
        ),
      ),
    );
  }
}

/// A single legend pill (play-loop-v1.md §3.3): `AppColors.paper` pill
/// chrome, now-live informational text. v3 item 4 (architecture v3 §4.3,
/// play-loop-v3.md §4) first changed the label from a single fixed number
/// to a static range; v4 §2 changes it again, to each band's live
/// most-recent rolled value (`RunState.lastHitLifeDelta`/
/// `lastMissLifeDelta`) — this widget's own chrome is unchanged by either.
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
