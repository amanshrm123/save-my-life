import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/audio_service.dart';
import '../../../core/feedback/feedback.dart';
import '../../../core/routing/app_page_transitions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/state/onboarding_providers.dart';
import '../../outcome/presentation/outcome_card_screen.dart';
import '../domain/clock_format.dart';
import '../domain/run_config.dart';
import '../domain/run_state.dart';
import '../state/play_loop_providers.dart';
import 'countdown_view.dart';
import 'widgets/legend_pills.dart';
import 'widgets/life_bar.dart';
import 'widgets/outcome_flash.dart';
import 'widgets/pause_overlay.dart';
import 'widgets/run_chips.dart';
import 'widgets/stop_button.dart';
import 'widgets/stopwatch_plate.dart';
import 'widgets/target_arm_button.dart';

/// Hosts the whole Play Loop phase machine (architecture v2 §5/§7): the
/// `GameClock` access (via `RunController`), the display `Ticker`, the raw
/// `Listener` STOP wiring, the phase switch, the `WidgetsBindingObserver`
/// auto-pause (architecture v2 §9 risk 1), and the pause overlay host.
///
/// Only two real `Navigator` transitions touch this screen: it is pushed
/// from Home, and it `pushReplacement`s to `OutcomeCardScreen` once
/// (architecture v2 §9 risk 5; v3 §3) when `phase == ended`.
class PlayLoopScreen extends ConsumerStatefulWidget {
  const PlayLoopScreen({super.key});

  @override
  ConsumerState<PlayLoopScreen> createState() => _PlayLoopScreenState();
}

class _PlayLoopScreenState extends ConsumerState<PlayLoopScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const RunConfig _config = RunConfig.defaults;

  late final Ticker _ticker;
  final ValueNotifier<Duration> _elapsedNotifier = ValueNotifier(Duration.zero);

  ProviderSubscription<RunState>? _subscription;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    _subscription = ref.listenManual<RunState>(runControllerProvider, _onStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _ticker.dispose();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  static bool _isLive(RunPhase phase) =>
      phase == RunPhase.running || phase == RunPhase.finalBandRunning;

  void _onTick(Duration _) {
    _elapsedNotifier.value = ref.read(runControllerProvider.notifier).liveElapsed;
  }

  void _onStateChanged(RunState? previous, RunState next) {
    final isLive = _isLive(next.phase);
    if (isLive && !_ticker.isTicking) {
      _ticker.start();
    } else if (!isLive && _ticker.isTicking) {
      _ticker.stop();
    }

    if (next.phase == RunPhase.stopped && previous?.phase != RunPhase.stopped) {
      _onStopped(next);
    }

    if (next.phase == RunPhase.finalBandArmed && previous?.phase != RunPhase.finalBandArmed) {
      AppFeedback.heavyImpactIfEnabled();
    }

    if (next.phase == RunPhase.ended && next.outcome != null) {
      _handOffToOutcome(next.outcome!);
    }
  }

  void _onStopped(RunState state) {
    final audio = ref.read(audioServiceProvider);
    switch (state.lastTier) {
      case StopTier.perfect:
      case StopTier.hit:
        AppFeedback.mediumImpactIfEnabled();
        unawaited(audio.playHit());
      case StopTier.miss:
        AppFeedback.heavyImpactIfEnabled();
        unawaited(audio.playMiss());
      case null:
        break;
    }
    Future.delayed(Duration(milliseconds: _config.flashDwellMs), () {
      if (!mounted) return;
      ref.read(runControllerProvider.notifier).advanceAfterDwell();
    });
  }

  void _handOffToOutcome(RunOutcome outcome) {
    if (_handedOff) return;
    _handedOff = true;
    final summary = ref.read(runControllerProvider.notifier).buildSummary();
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(
        settings: const RouteSettings(name: '/play/outcome'),
        builder: (context) => OutcomeCardScreen(summary: summary),
      ),
    );
  }

  void _onPause() => ref.read(runControllerProvider.notifier).pause();
  void _onResume() => ref.read(runControllerProvider.notifier).resume();
  void _onRestart() => ref.read(runControllerProvider.notifier).restartRun();
  void _onQuit() => Navigator.of(context).popUntil((r) => r.settings.name == AppRoutes.home);

  void _onArm() {
    unawaited(ref.read(audioServiceProvider).playTap());
    ref.read(runControllerProvider.notifier).startRunning();
  }

  void _onStopTap() => ref.read(runControllerProvider.notifier).registerStop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Architecture v2 §9 risk 1 — the headline memory-safety issue: a
    // backgrounded `Stopwatch` must never yield a stop-time. Auto-pause
    // discards any in-flight attempt rather than risk a corrupt read.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final phase = ref.read(runControllerProvider).phase;
      if (_isLive(phase)) {
        ref.read(runControllerProvider.notifier).pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(runControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back-button semantics (design spec v1 §3.7): live phase -> open
        // pause; paused -> resume. `pause()`/`resume()` already no-op for
        // any other phase, so this single call is always safe.
        if (state.phase == RunPhase.paused) {
          _onResume();
        } else {
          _onPause();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Stack(
            children: [
              if (state.phase == RunPhase.countdown)
                const CountdownView()
              else
                _Hud(
                  state: state,
                  elapsedNotifier: _elapsedNotifier,
                  onPause: _onPause,
                  onArm: _onArm,
                  onStopTap: _onStopTap,
                ),
              if (state.phase == RunPhase.paused)
                PauseOverlay(onResume: _onResume, onRestart: _onRestart, onQuit: _onQuit),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gameplay chrome for every non-countdown phase (design spec v1 §1.3:
/// 14dp horizontal inset, distinct from onboarding's 20dp). Renders using
/// `state.phaseBeforePause` while paused so the HUD underneath the overlay
/// reflects the frozen live phase, not a blank "paused" state.
class _Hud extends ConsumerWidget {
  const _Hud({
    required this.state,
    required this.elapsedNotifier,
    required this.onPause,
    required this.onArm,
    required this.onStopTap,
  });

  final RunState state;
  final ValueNotifier<Duration> elapsedNotifier;
  final VoidCallback onPause;
  final VoidCallback onArm;
  final VoidCallback onStopTap;

  RunPhase get _displayPhase =>
      state.phase == RunPhase.paused ? (state.phaseBeforePause ?? RunPhase.armed) : state.phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayPhase = _displayPhase;
    final finalBand = displayPhase == RunPhase.finalBandArmed ||
        displayPhase == RunPhase.finalBandRunning ||
        (displayPhase == RunPhase.stopped && state.lastStopWasFinalBand);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        children: [
          RunChips(runNumber: state.runNumber, deaths: state.deaths, onPause: onPause),
          const SizedBox(height: 10),
          LifeBar(state: state),
          Expanded(
            child: Center(
              child: _CenterContent(
                displayPhase: displayPhase,
                state: state,
                elapsedNotifier: elapsedNotifier,
                onArm: onArm,
              ),
            ),
          ),
          LegendPills(finalBand: finalBand),
          const SizedBox(height: 14),
          StopButton(
            mainLabel: 'STOP',
            subLabel: _stopSubLabel(displayPhase, state.target, finalBand),
            enabled: displayPhase == RunPhase.running || displayPhase == RunPhase.finalBandRunning,
            finalBand: finalBand,
            onStopTap: onStopTap,
          ),
        ],
      ),
    );
  }

  String _stopSubLabel(RunPhase phase, Duration target, bool finalBand) {
    if (phase == RunPhase.armed || phase == RunPhase.finalBandArmed) {
      return 'tap "Stop at" first to start';
    }
    if (finalBand) {
      return 'one clean stop saves you';
    }
    return 'stop as close to ${formatClock(target)} as you can';
  }
}

class _CenterContent extends ConsumerWidget {
  const _CenterContent({
    required this.displayPhase,
    required this.state,
    required this.elapsedNotifier,
    required this.onArm,
  });

  final RunPhase displayPhase;
  final RunState state;
  final ValueNotifier<Duration> elapsedNotifier;
  final VoidCallback onArm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (displayPhase) {
      case RunPhase.armed:
      case RunPhase.finalBandArmed:
        return TargetArmButton(target: state.target, onArm: onArm);

      case RunPhase.running:
        return _RunningContent(target: state.target, elapsedNotifier: elapsedNotifier, finalBand: false);

      case RunPhase.finalBandRunning:
        return _RunningContent(target: state.target, elapsedNotifier: elapsedNotifier, finalBand: true);

      case RunPhase.stopped:
        return _StoppedContent(state: state);

      case RunPhase.countdown:
      case RunPhase.paused:
      case RunPhase.ended:
        return const SizedBox.shrink();
    }
  }
}

class _RunningContent extends ConsumerWidget {
  const _RunningContent({
    required this.target,
    required this.elapsedNotifier,
    required this.finalBand,
  });

  final Duration target;
  final ValueNotifier<Duration> elapsedNotifier;
  final bool finalBand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = finalBand ? AppColors.red : AppColors.greenDark;
    final name = finalBand
        ? ref.watch(playerProfileProvider).maybeWhen(
            data: (p) => p.isAnonymous ? null : p.name,
            orElse: () => null,
          )
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (finalBand)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              name == null ? 'Last chance' : '$name, last chance',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
                height: 1.1,
              ),
            ),
          ),
        Text(
          'Target ${formatClock(target)}',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: finalBand ? AppColors.red.withValues(alpha: 0.75) : AppColors.mute,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Running…',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04 * 9,
            color: finalBand ? AppColors.red : AppColors.greenDark,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        StopwatchPlate(filled: false, tint: tint, liveElapsed: elapsedNotifier),
      ],
    );
  }
}

class _StoppedContent extends StatelessWidget {
  const _StoppedContent({required this.state});

  final RunState state;

  @override
  Widget build(BuildContext context) {
    final tier = state.lastTier;
    final good = tier != null && tier != StopTier.miss;
    final tint = good ? AppColors.green : AppColors.red;
    final labelColor = good ? AppColors.greenDark : AppColors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Target ${formatClock(state.target)}',
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.mute,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _statusLabel(tier),
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04 * 9,
            color: labelColor,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        StopwatchPlate(filled: true, tint: tint, staticValue: state.lastStopElapsed ?? Duration.zero),
        const SizedBox(height: 10),
        OutcomeFlash(state: state),
      ],
    );
  }

  /// "Stopped" for Perfect/Hit, or a final-band terminal stop (design v1
  /// §2.7's gap-fill keeps that frame's label plain, matching its SURVIVED/
  /// MISS flash with no percentage). A normal Miss restores the mockup's
  /// literal "Stopped · off by X" gap readout (design v1 §2.6, re-resolved
  /// under `SS:CC`) — the absolute error in seconds, 2 decimal places.
  String _statusLabel(StopTier? tier) {
    if (tier != StopTier.miss || state.lastStopWasFinalBand) return 'Stopped';
    final stopped = state.lastStopElapsed ?? Duration.zero;
    final gapMs = (stopped - state.target).inMilliseconds.abs();
    final gapSeconds = (gapMs / 1000).toStringAsFixed(2);
    return 'Stopped · off by $gapSeconds';
  }
}
