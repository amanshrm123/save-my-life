import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The 38x22dp pill toggle (design v3 §6.2) — 2dp ink border; on: green
/// fill, off: `paper2` fill; a 16dp white knob (1.5dp ink border) inset 1px
/// from the active edge. The knob slide is animated (~150-200ms) — treated
/// as a near-required polish item per the design doc, not optional.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _width = 38;
  static const double _height = 22;
  static const double _knobSize = 16;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: value ? 'On' : 'Off',
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: value ? AppColors.green : AppColors.paper2,
            borderRadius: BorderRadius.circular(_height / 2),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _knobSize,
              height: _knobSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
