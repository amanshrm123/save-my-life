import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The bottom-docked STOP button (design spec v1 §1.5) — the single most
/// latency-critical input in the app (architecture G2).
///
/// Deliberately **not** built on `StickerButton`/`GestureDetector`: the
/// design doc's widget-reuse map (§7) suggests "extend `StickerButton`" for
/// its taller/two-line/color-variant look, but architecture G2 and platform
/// conventions (§5) are explicit that the STOP tap must be captured via a
/// raw `Listener.onPointerDown`, never `GestureDetector`/`InkWell` — the two
/// asks conflict, and the mandatory latency rule wins. This widget
/// replicates `StickerButton`'s visual language by hand and drives *both*
/// the score-capture call and the (purely cosmetic) press animation off the
/// same `Listener` pointer callbacks, so nothing about the juice can gate
/// or delay the underlying `onStopTap` call.
class StopButton extends StatefulWidget {
  const StopButton({
    super.key,
    required this.mainLabel,
    required this.subLabel,
    required this.enabled,
    required this.finalBand,
    required this.onStopTap,
  });

  final String mainLabel;
  final String subLabel;

  /// Visual affordance only (dims per design spec v1 §3.5) — the real
  /// double-tap/phase guard lives in `RunController.registerStop()`.
  final bool enabled;

  /// Final-band reskin (design spec v1 §2.7): fill -> red, text-shadow ->
  /// `redDark` token, ink border unchanged.
  final bool finalBand;

  /// Invoked synchronously from `onPointerDown` — the literal first thing
  /// that happens on a stop tap, before any animation or rebuild.
  final VoidCallback onStopTap;

  @override
  State<StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<StopButton> with SingleTickerProviderStateMixin {
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
    // The literal first statement on a stop tap (architecture G2) — the
    // cosmetic press animation below runs *after* and never gates or delays
    // this call.
    widget.onStopTap();
    if (widget.enabled) {
      _controller.animateTo(1, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _controller.animateTo(0, duration: const Duration(milliseconds: 140), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.finalBand ? AppColors.red : AppColors.coral;
    final labelShadow = widget.finalBand ? AppColors.redDark : AppColors.coralDark;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
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
                  height: 78,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                    boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, shadowOffset))],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.mainLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [Shadow(color: labelShadow, offset: const Offset(0, 1.5))],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
