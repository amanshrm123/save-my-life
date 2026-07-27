import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/clock_format.dart';

/// The center "STOP AT `<target>`" gold plate (design spec v1 §1.5) — the
/// **only** way to start a run (`RunController.startRunning()`). Built as
/// its own widget rather than a `StickerButton` variant: its shadow color
/// deviates from the standard "shadow is always ink" rule (gold-d instead)
/// and its overline + big-number internal layout is unique to this button.
///
/// Not latency-critical (only the STOP tap is, per architecture G2), so a
/// normal `GestureDetector`-driven press animation — matching the rest of
/// the app's sticker-button juice — is appropriate here.
class TargetArmButton extends StatefulWidget {
  const TargetArmButton({super.key, required this.target, required this.onArm});

  final Duration target;
  final VoidCallback onArm;

  @override
  State<TargetArmButton> createState() => _TargetArmButtonState();
}

class _TargetArmButtonState extends State<TargetArmButton>
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

  void _onTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    _controller.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _onTapEnd() {
    _controller.animateTo(0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: (_) => _onTapEnd(),
      onTapCancel: _onTapEnd,
      onTap: widget.onArm,
      behavior: HitTestBehavior.opaque,
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
                height: 100,
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 260),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: AppColors.goldDark, offset: Offset(0, shadowOffset)),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
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
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
