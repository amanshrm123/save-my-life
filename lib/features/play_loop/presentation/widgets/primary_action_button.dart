import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/clock_format.dart';

/// The four visual "looks" of the merged bottom action button (design spec
/// v2 §3.3), driven by run phase:
/// - [armStart]: gold, "STOP AT `<target>`" — `armed`/`finalBandArmed`.
/// - [stopNormal]: coral, "STOP" — `running`.
/// - [stopFinal]: red, "STOP" — `finalBandRunning`.
/// - [dwellDimmed]: gold, next target frozen, inert — `stopped`.
enum PrimaryActionLook { armStart, stopNormal, stopFinal, dwellDimmed }

/// The single bottom-docked primary action button (design spec v2 §3) — the
/// founder's fix for "hunting for a different button": one widget, one
/// screen position, that reskins in place across all four [PrimaryActionLook]
/// states, replacing v1's separate `TargetArmButton` (center gold plate) and
/// `StopButton` (bottom coral/red button).
///
/// Built on a raw `Listener.onPointerDown`, in **every** look/phase, with no
/// exceptions — never a `GestureDetector`/`InkWell` (architecture G2). Even
/// though only the STOP-phase taps are latency-critical, this merge means
/// the whole widget adopts the stricter rule rather than special-casing by
/// look, since a single `Listener` drives every look uniformly.
///
/// [onTap] is invoked synchronously from `onPointerDown` — the literal first
/// thing that happens on any tap, before any animation or rebuild — exactly
/// mirroring the old `stop_button.dart`'s pattern. Any cosmetic side effect
/// the caller wants alongside a genuine tap (haptic, tap sound) must be
/// threaded into [onTap] itself by the caller, invoked strictly *after* the
/// real controller call it wraps returns (see `play_loop_screen.dart`'s
/// `_Hud`, which resolves the tap sound only for a start-tap).
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.look,
    required this.target,
    required this.onTap,
  });

  final PrimaryActionLook look;

  /// The current attempt's target — shown big on [armStart]/[dwellDimmed];
  /// interpolated into the [stopNormal] sub-label.
  final Duration target;

  /// Invoked synchronously from `onPointerDown`, for every [look] including
  /// [PrimaryActionLook.dwellDimmed] — the controller-level phase guard (not
  /// this widget) is the real protection against a stray tap in that window
  /// (design spec v2 §3.3).
  final VoidCallback onTap;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  static const double _restShadowOffset = 6;
  static const double _pressedShadowOffset = 2;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // The literal first thing that happens on any tap (architecture G2) —
    // the cosmetic press animation below runs *after* and never gates or
    // delays this call.
    widget.onTap();
    _controller.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _onPointerEnd(PointerEvent event) {
    _controller.animateTo(0, duration: const Duration(milliseconds: 140), curve: Curves.easeOutBack);
  }

  Color get _fill {
    switch (widget.look) {
      case PrimaryActionLook.armStart:
      case PrimaryActionLook.dwellDimmed:
        return AppColors.gold;
      case PrimaryActionLook.stopNormal:
        return AppColors.coral;
      case PrimaryActionLook.stopFinal:
        return AppColors.red;
    }
  }

  String get _semanticsLabel {
    switch (widget.look) {
      case PrimaryActionLook.armStart:
        return 'Stop at ${formatClock(widget.target)}';
      case PrimaryActionLook.stopNormal:
      case PrimaryActionLook.stopFinal:
        return 'Stop';
      case PrimaryActionLook.dwellDimmed:
        return 'Next target ${formatClock(widget.target)}';
    }
  }

  Widget _buildContent() {
    switch (widget.look) {
      case PrimaryActionLook.armStart:
      case PrimaryActionLook.dwellDimmed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STOP AT',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06 * 11,
                color: AppColors.ink.withValues(alpha: 0.85),
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatClock(widget.target),
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                height: 1,
              ),
            ),
          ],
        );

      case PrimaryActionLook.stopNormal:
      case PrimaryActionLook.stopFinal:
        final isFinal = widget.look == PrimaryActionLook.stopFinal;
        final labelShadow = isFinal ? AppColors.redDark : AppColors.coralDark;
        final subLabel = isFinal
            ? 'one clean stop saves you'
            : 'stop as close to ${formatClock(widget.target)} as you can';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STOP',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                shadows: [Shadow(color: labelShadow, offset: const Offset(0, 1.5))],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Confirmed cap (design spec v2 §3.1) — not a literal uncapped 1/3
    // screen.
    final height = (MediaQuery.sizeOf(context).height / 3).clamp(150.0, 260.0);

    return Semantics(
      button: true,
      label: _semanticsLabel,
      onTap: widget.onTap,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final shadowOffset = ui.lerpDouble(
              _restShadowOffset,
              _pressedShadowOffset,
              _controller.value,
            )!;
            final translateY = _restShadowOffset - shadowOffset;
            return Padding(
              padding: const EdgeInsets.only(bottom: _restShadowOffset),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Container(
                  height: height,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: _fill,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                    // One shared shadow rule (design spec v2 §3.2): every
                    // look uses an ink shadow, including armStart — a
                    // deliberate departure from v1's gold-d-shadowed plate.
                    boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, shadowOffset))],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(fit: BoxFit.scaleDown, child: _buildContent()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
