import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../persistence/hive_profile_repository.dart';
import 'run_controller.dart';

/// Full-screen 3-2-1 countdown shown while `RunState.phase` is
/// `RunPhase.countdown` (docs/design/play-screen-gate1-v1.md §1), reskinned
/// per docs/design/play-loop-v1.md §2 with a name-aware header and a gold
/// circle around the number.
///
/// Paced by a plain `Timer.periodic` — deliberately **not** the shared
/// `MonotonicClock`. The architecture's monotonic-clock-only rule governs
/// the tap-timing measurement path only; this is wall-clock UI pacing, not
/// a scored measurement, so a real-time `Timer` is correct here.
///
/// Sequence (spec §1, exact): "3" for 1000ms, "2" for 1000ms, "1" for
/// 1000ms, then `RunController.beginPlaying()` — no per-digit animation,
/// no transition into the Play layout. play-loop-v1.md §2 is a cosmetic
/// wrap only — none of this timing mechanism changes.
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
    // Safe synchronous read (play-loop-v1.md §2): `profileRepositoryProvider`
    // is a `FutureProvider` that `SplashScreen` already awaits before routing
    // anywhere, and `CountdownView` is only ever reached after Splash has
    // resolved and routed — so by the time this widget builds, the provider
    // is always already-resolved `AsyncData`. No loading branch needed.
    final String? name = ref.watch(profileRepositoryProvider).value?.name;

    // Caption max-width as a fraction of screen width with a ~230dp cap
    // (§8's responsive rule / onboarding-flow-v1.md §7), not a hardcoded dp
    // value.
    final double captionMaxWidth =
        math.min(MediaQuery.of(context).size.width * 0.62, 230);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountdownHeader(name: name),
              const SizedBox(height: 32),
              _GoldCircle(label: _labels[_index]),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: captionMaxWidth),
                child: const Text(
                  'First target drops when it hits zero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.teachBody,
                    height: 1.45,
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

/// Name-aware header above the countdown circle (play-loop-v1.md §2): "Hey
/// {name}, get ready" with `{name}` in `AppColors.coral`, or a plain "Get
/// ready" fallback (no colored span, same weight/size) when no name was
/// captured. Same conditional-composition-on-one-widget pattern
/// `onboarding-flow-v1.md` §3.4/§5.6 already established for no-name
/// fallbacks, and the same `RichText`/`TextSpan` style `splash_screen.dart`'s
/// "Stay **Alive!**" already uses — reused verbatim, not reinvented.
class _CountdownHeader extends StatelessWidget {
  const _CountdownHeader({required this.name});

  final String? name;

  static const TextStyle _baseStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    if (name == null || name!.isEmpty) {
      return const Text('Get ready', style: _baseStyle);
    }
    return RichText(
      text: TextSpan(
        style: _baseStyle,
        children: [
          const TextSpan(text: 'Hey '),
          TextSpan(
            text: name,
            style: const TextStyle(color: AppColors.coral),
          ),
          const TextSpan(text: ', get ready'),
        ],
      ),
    );
  }
}

/// The countdown number's chrome (play-loop-v1.md §2): a 140dp gold circle,
/// 3.5dp ink border, flat zero-blur `BoxShadow(offset: Offset(0, 6))` — the
/// same flat-shadow recipe `onboarding-flow-v1.md` §2.3 already established,
/// just a bigger offset to match this element specifically. No animation on
/// digit change, per the existing hard "no per-digit bounce/scale" rule.
class _GoldCircle extends StatelessWidget {
  const _GoldCircle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 3.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
