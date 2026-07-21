import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
///
/// The timer is deliberately **not** started in `initState`. There can be a
/// real, sometimes multi-second, gap between "the Dart widget tree has been
/// built" and "the OS has actually composited a frame the user can see"
/// (cold engine/GL-surface startup on Android is the main culprit). A timer
/// started in `initState` doesn't know or care about that gap, so it can —
/// and on a slow cold start, did — run out entirely before anything was
/// visible on screen, silently skipping the countdown. Starting it in
/// `addPostFrameCallback` instead defers it until after the first frame has
/// actually been rendered, so the visible "3-2-1" always gets its full 3
/// seconds on screen regardless of how long startup took beforehand.
class CountdownView extends ConsumerStatefulWidget {
  const CountdownView({super.key});

  @override
  ConsumerState<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends ConsumerState<CountdownView> {
  static const List<String> _labels = ['3', '2', '1'];

  int _index = 0;
  Timer? _timer;

  /// Test-only hook: records which `SchedulerPhase` was active at the
  /// moment the countdown `Timer` was actually created. Not read by
  /// production code — it exists so a widget test can assert the timer is
  /// created while handling a post-frame callback (`SchedulerPhase
  /// .postFrameCallbacks`) rather than synchronously during the initial
  /// build (`SchedulerPhase.persistentCallbacks`, which is what `initState`
  /// would show), i.e. that the fix for the on-device countdown-skipping
  /// bug is actually in effect and not just a no-op refactor.
  @visibleForTesting
  SchedulerPhase? debugTimerStartedDuringPhase;

  @override
  void initState() {
    super.initState();
    // Defer starting the countdown until after the first frame has actually
    // been rendered, rather than starting it here (as soon as the Dart
    // widget builds) — see the class doc comment for why.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugTimerStartedDuringPhase = SchedulerBinding.instance.schedulerPhase;
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    });
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
