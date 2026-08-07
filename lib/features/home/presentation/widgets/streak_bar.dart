import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../../../../core/feedback/feedback.dart';
import '../../../../core/theme/app_theme.dart';

/// The 7-segment weekly streak bar (design v3 §5.1) — a single configurable
/// widget with a size parameter, since Home's mini bar (6dp/1.5dp-border)
/// and the Streak-Advanced celebration's larger bar (8dp/2dp-border) are
/// genuinely different sizes, not one fixed instance reused verbatim.
///
/// Segment count beyond 7 days is capped: `min(streakCount, 7)` filled
/// segments (design v3 §5.1's resolved recommendation — no calendar-week
/// alignment, no wrap-around animation).
///
/// [animateEntrance] (juice spec effect 5, default `false`) opts into a
/// staggered "punch fill" — each filled pip scales/rotates in with an
/// elastic overshoot, one after another — instead of every existing call
/// site's plain `AnimatedContainer` color/height fade. Only
/// `StreakAdvancedView` passes `true`; every other call site (Home's
/// dashboard mini-bar, etc.) keeps the default and renders byte-for-byte as
/// before.
class StreakWeekBar extends StatefulWidget {
  const StreakWeekBar({
    super.key,
    required this.streakCount,
    this.segmentHeight = 6,
    this.borderWidth = 1.5,
    this.animateEntrance = false,
  });

  final int streakCount;
  final double segmentHeight;
  final double borderWidth;
  final bool animateEntrance;

  @override
  State<StreakWeekBar> createState() => _StreakWeekBarState();
}

class _StreakWeekBarState extends State<StreakWeekBar>
    with SingleTickerProviderStateMixin {
  /// Stagger between consecutive pips' punch starting (juice spec effect 5).
  static const int _kStaggerMs = 150;

  /// Each individual pip's own punch duration (the LAST pip's interval is
  /// exactly this long; every earlier pip's interval is this long too, just
  /// starting [_kStaggerMs] earlier than the next).
  static const int _kPunchDurationMs = 400;

  /// Starting rotation, in degrees (settles at 0deg) — see the `t`-reuse
  /// comment in `build` for why this alone (not a separate keyframe pair)
  /// is enough to get the spec's "-20deg -> +8deg -> 0deg" overshoot shape.
  static const double _kRotateFromDegrees = 20;

  AnimationController? _controller;
  int _filled = 0;
  bool _reduceMotion = false;

  /// Guards the one-shot entrance kickoff in [didChangeDependencies] so it
  /// never re-fires on a later, unrelated dependency change.
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.animateEntrance) {
      _setUpEntrance();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animateEntrance || _entranceStarted) return;
    // `MediaQuery` (needed to decide whether Reduce Motion applies) isn't
    // reliably available in `initState`, hence deferred to here — still
    // fires exactly once, before the first real `build()`.
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _entranceStarted = true;
    if (!_reduceMotion && _controller != null) {
      _scheduleHapticsAndStart();
    }
  }

  void _setUpEntrance() {
    _filled = widget.streakCount.clamp(0, 7);
    if (_filled == 0) return;
    final totalMs = (_filled - 1) * _kStaggerMs + _kPunchDurationMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
  }

  /// Fires `AppFeedback.lightImpactIfEnabled()` once per pip, exactly when
  /// that pip's own punch interval begins — scheduled via `Timer` (not bare
  /// `Future.delayed`) so a screen disposed mid-celebration never leaves a
  /// pending callback referencing this (by-then-disposed) `State`.
  final List<Timer> _hapticTimers = [];

  void _scheduleHapticsAndStart() {
    for (var i = 0; i < _filled; i++) {
      _hapticTimers.add(
        Timer(Duration(milliseconds: i * _kStaggerMs), () {
          if (!mounted) return;
          AppFeedback.lightImpactIfEnabled();
        }),
      );
    }
    _controller!.forward();
  }

  @override
  void dispose() {
    for (final timer in _hapticTimers) {
      timer.cancel();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animateEntrance) {
      return _StaticStreakRow(
        streakCount: widget.streakCount,
        segmentHeight: widget.segmentHeight,
        borderWidth: widget.borderWidth,
      );
    }

    if (_reduceMotion || _filled == 0) {
      // Reduce Motion (or nothing to celebrate): every completed pip renders
      // already filled, no punch/stagger/haptic at all.
      return _StaticStreakRow(
        streakCount: widget.streakCount,
        segmentHeight: widget.segmentHeight,
        borderWidth: widget.borderWidth,
      );
    }

    final controller = _controller!;
    final totalMs = controller.duration!.inMilliseconds;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          children: List.generate(7, (i) {
            final isFilled = i < _filled;
            Widget pip = _Pip(
              isFilled: isFilled,
              segmentHeight: widget.segmentHeight,
              borderWidth: widget.borderWidth,
            );
            if (isFilled) {
              final startMs = i * _kStaggerMs;
              final endMs = startMs + _kPunchDurationMs;
              final interval = Interval(
                startMs / totalMs,
                (endMs / totalMs).clamp(0.0, 1.0),
                curve: Curves.elasticOut,
              );
              // `elasticOut`'s own transient overshoot (0 -> briefly past 1
              // -> settles at 1) is exactly the "0->1.4->1.0" scale shape
              // the juice spec calls for once fed straight into a plain
              // 0..1 `Tween` — no separate keyframe sequence needed. Reusing
              // that SAME eased value for rotation (-20deg .. 0deg) gets the
              // matching "-20 -> briefly past 0 -> settles at 0" overshoot
              // for free, one shared `Interval`/curve driving both, per spec.
              final t = interval.transform(controller.value);
              final degrees = -_kRotateFromDegrees + _kRotateFromDegrees * t;
              pip = Transform.rotate(
                angle: degrees * pi / 180,
                child: Transform.scale(scale: t, child: pip),
              );
            }
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
                child: pip,
              ),
            );
          }),
        );
      },
    );
  }
}

/// The plain, non-animated row — [StreakWeekBar]'s existing
/// `animateEntrance: false` output, kept byte-for-byte identical to before
/// this widget grew an entrance-animation mode.
class _StaticStreakRow extends StatelessWidget {
  const _StaticStreakRow({
    required this.streakCount,
    required this.segmentHeight,
    required this.borderWidth,
  });

  final int streakCount;
  final double segmentHeight;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final filled = streakCount.clamp(0, 7);
    return Row(
      children: List.generate(7, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: segmentHeight,
              decoration: BoxDecoration(
                color: isFilled ? AppColors.coral : AppColors.paper2,
                borderRadius: BorderRadius.circular(segmentHeight / 2),
                border: Border.all(color: AppColors.ink, width: borderWidth),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// One pip's static box (no animation of its own — the punch transform is
/// applied by the caller via `Transform.scale`/`Transform.rotate`).
class _Pip extends StatelessWidget {
  const _Pip({
    required this.isFilled,
    required this.segmentHeight,
    required this.borderWidth,
  });

  final bool isFilled;
  final double segmentHeight;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: segmentHeight,
      decoration: BoxDecoration(
        color: isFilled ? AppColors.coral : AppColors.paper2,
        borderRadius: BorderRadius.circular(segmentHeight / 2),
        border: Border.all(color: AppColors.ink, width: borderWidth),
      ),
    );
  }
}
