import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/run/run_controller.dart';
import '../features/timing_engine/indicator_painter.dart';
import '../features/timing_engine/tap_surface.dart';
import '../features/timing_engine/timing_engine.dart';

/// Root widget: `ProviderScope` + the one Play screen for this phase.
/// No router, no other screens (architecture v1 §3, Days 1-2: "One bare
/// Play screen").
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'Timing Tap',
        debugShowCheckedModeBanner: false,
        home: PlayScreen(),
      ),
    );
  }
}

/// The walking-skeleton Play screen. Component hierarchy and zones follow
/// docs/design/play-screen-skeleton-v1.md §1 exactly:
/// Zone A status strip, Zone B indicator, Zone C debug readout, Zone D tap
/// surface. Plain widgets only outside Zone B — no `AppBar`, no navigation,
/// no juice/animation/sound (explicitly out of scope this phase).
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RunState runState = ref.watch(runControllerProvider);
    final clock = ref.watch(clockProvider);

    final double targetSeconds = runState.targetDurationMicros / 1000000;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Zone A — status strip (~15%).
            Expanded(
              flex: 15,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LIFE: ${runState.lifePct.round()}%'),
                    Text('TARGET: ${targetSeconds.toStringAsFixed(2)}s'),
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

            // Zone C — debug readout (~15%). Holds prior tap's result until
            // the next tap overwrites it; shows "—" before the first tap.
            Expanded(
              flex: 15,
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
                },
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFDDDDDD),
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
