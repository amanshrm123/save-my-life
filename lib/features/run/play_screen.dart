import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` moved to the "legacy" import in Riverpod 3.x — still the
// right tool for a single trivial nullable value like the flash color (per
// docs/design/play-screen-gate1-v1.md §3), just no longer in the default
// export.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/sound_service.dart';
import 'countdown_view.dart';
import 'run_controller.dart';
import '../timing_engine/indicator_painter.dart';
import '../timing_engine/tap_surface.dart';
import '../timing_engine/timing_engine.dart';

/// Zone D's brief hit/miss flash color, or `null` when no flash is active.
/// Set (and cleared 120ms later by a plain `Timer`) **after** `registerTap`
/// resolves in `PlayScreen`'s `onTapMicros` — never inside `TapSurface`'s
/// `onPointerDown` or `timing_engine.resolve()`
/// (docs/design/play-screen-gate1-v1.md §3, hard rule).
final tapFlashColorProvider = StateProvider<Color?>((ref) => null);

const Color _healthyGreen = Color(0xFF4CAF50);
const Color _dangerRed = Color(0xFFE53935);
const Color _neutralGray = Color(0xFFDDDDDD);

/// Tracks the pending flash-clear timer so a rapid second tap can cancel
/// the first tap's clear instead of racing it — otherwise tap A's 120ms
/// timer fires mid-way through tap B's flash and cuts it short. `PlayScreen`
/// is the single root Play screen, so a module-level timer is safe.
Timer? _pendingFlashClearTimer;

/// The Play screen. Branches on `RunState.phase`: `countdown` renders the
/// full-screen 3-2-1 (`CountdownView`); `playing` renders the 4-zone
/// Column from the Days 1-2 skeleton (docs/design/play-screen-skeleton-v1.md
/// §1) — Zone A status strip (now with the life bar), Zone B indicator,
/// Zone C debug readout, Zone D tap surface (now with the hit/miss flash) —
/// per docs/design/play-screen-gate1-v1.md §§1-3. Plain widgets only
/// outside Zone B — no `AppBar`, no `AnimationController`/curve anywhere
/// (explicitly out of scope this phase).
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
    final Color? flashColor = ref.watch(tapFlashColorProvider);

    final double targetSeconds = runState.targetDurationMicros / 1000000;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Zone A — status strip (~20%, bumped from 15% to fit the life
            // bar; borrowed from Zone C per play-screen-gate1-v1.md §2).
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
                        Text('LIFE: ${runState.lifePct.round()}%'),
                        Text('TARGET: ${targetSeconds.toStringAsFixed(2)}s'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (runState.lifePct / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: runState.lifePct <= 25
                                  ? _dangerRed
                                  : _healthyGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Zone B — indicator, the one Ticker/CustomPaint element (~20%).
            Expanded(
              flex: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: IndicatorWidget(
                  clock: clock,
                  roundStartMicros: runState.roundStartMicros,
                  targetDurationMicros: runState.targetDurationMicros,
                ),
              ),
            ),

            // Zone C — debug readout (~10%, trimmed from 15% to make room
            // for Zone A's life bar). Holds prior tap's result until the
            // next tap overwrites it; shows "—" before the first tap.
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

            // Zone D — tap surface, bottom half of the screen (~50%).
            Expanded(
              flex: 50,
              child: TapSurface(
                clock: clock,
                onTapMicros: (int pressMicros) {
                  ref.read(runControllerProvider.notifier).registerTap(pressMicros);

                  // Flash/sound react to the already-resolved tap result —
                  // strictly after registerTap returns. Never move this
                  // into TapSurface.onPointerDown or timing_engine.resolve()
                  // (play-screen-gate1-v1.md §3, hard rule).
                  final TimingBand band =
                      ref.read(runControllerProvider).lastBand!;
                  final bool isHit = band != TimingBand.miss;

                  ref.read(tapFlashColorProvider.notifier).state =
                      isHit ? _healthyGreen : _dangerRed;
                  _pendingFlashClearTimer?.cancel();
                  _pendingFlashClearTimer =
                      Timer(const Duration(milliseconds: 120), () {
                    if (ref.context.mounted) {
                      ref.read(tapFlashColorProvider.notifier).state = null;
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
                child: Container(
                  width: double.infinity,
                  color: flashColor ?? _neutralGray,
                  child: const Center(
                    child: Text('TAP'),
                  ),
                ),
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
