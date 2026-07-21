import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'run_controller.dart';

/// Full-screen 3-2-1 countdown shown while `RunState.phase` is
/// `RunPhase.countdown` (docs/design/play-screen-gate1-v1.md §1).
///
/// Paced by a plain `Timer.periodic` — deliberately **not** the shared
/// `MonotonicClock`. The architecture's monotonic-clock-only rule governs
/// the tap-timing measurement path only; this is wall-clock UI pacing, not
/// a scored measurement, so a real-time `Timer` is correct here.
///
/// Sequence (spec §1, exact): "3" for 1000ms, "2" for 1000ms, "1" for
/// 1000ms, then `RunController.beginPlaying()` — no per-digit animation,
/// no transition into the Play layout.
class CountdownView extends ConsumerStatefulWidget {
  const CountdownView({super.key});

  @override
  ConsumerState<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends ConsumerState<CountdownView> {
  static const List<String> _labels = ['3', '2', '1'];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (_index == _labels.length - 1) {
      // "1" has now shown for its full second — done.
      timer.cancel();
      ref.read(runControllerProvider.notifier).beginPlaying();
      return;
    }
    setState(() {
      _index++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            _labels[_index],
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
