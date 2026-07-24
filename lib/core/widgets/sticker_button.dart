import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The "sticker button" pattern (design spec v1 §1.4): a thick ink-bordered,
/// zero-blur hard-offset-shadow button — deliberately *not* a Material
/// `ElevatedButton`, whose elevation/shape model fights this effect.
///
/// Reused across the whole app (not just onboarding), so it lives in
/// `core/widgets/`, but is kept intentionally small — just the shape +
/// press-juice this feature needs today.
class StickerButton extends StatefulWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.fill,
    required this.labelShadow,
    required this.onPressed,
    this.enabled = true,
    this.height = 44,
    this.borderRadius = 14,
    this.restShadowOffset = 5,
    this.pressedShadowOffset = 2,
    this.textColor = Colors.white,
    this.showLabelTextShadow = true,
    this.fontSize,
  });

  final String label;
  final Color fill;
  final Color labelShadow;
  final VoidCallback? onPressed;
  final bool enabled;
  final double height;
  final double borderRadius;
  final double restShadowOffset;
  final double pressedShadowOffset;

  /// Label text color — white by default (every onboarding usage), but the
  /// Play Loop `.ghostbtn` variant (design spec v1 §1.6) needs ink text on a
  /// paper fill instead.
  final Color textColor;

  /// The `.ghostbtn` variant has no white text-shadow at all (only the
  /// button's own box shadow) — set false to suppress it.
  final bool showLabelTextShadow;

  /// Overrides `AppTypography.buttonLabel`'s 14dp default when a caller
  /// needs a distinct size (e.g. the pause modal's `.ghostbtn`, 13dp).
  final double? fontSize;

  @override
  State<StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<StickerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _interactive => widget.enabled && widget.onPressed != null;

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
    if (!_interactive) return;
    HapticFeedback.lightImpact();
    _controller.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _onTapUp(TapUpDetails details) {
    if (!_interactive) return;
    _controller.animateTo(0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutBack);
  }

  void _onTapCancel() {
    if (!_interactive) return;
    _controller.animateTo(0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shadowOffset = ui.lerpDouble(
          widget.restShadowOffset,
          widget.pressedShadowOffset,
          _controller.value,
        )!;
        final translateY = widget.restShadowOffset - shadowOffset;
        return Padding(
          // Reserve room below for the shelf shadow so it never overlaps
          // the next element in a column (design spec v1 §1.4).
          padding: EdgeInsets.only(bottom: widget.restShadowOffset),
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.fill,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: AppColors.ink, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(0, shadowOffset),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: AppTypography.buttonLabel.copyWith(
                  color: widget.textColor,
                  fontSize: widget.fontSize,
                  shadows: widget.showLabelTextShadow
                      ? [
                          Shadow(
                            color: widget.labelShadow,
                            offset: const Offset(0, 1.5),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );

    return Opacity(
      opacity: _interactive ? 1 : 0.45,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _interactive ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}
