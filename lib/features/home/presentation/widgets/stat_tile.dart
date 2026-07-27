import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A dashboard stat tile (design v3 §5.1) — first appearance of this family:
/// paper fill, 2.5dp ink border, 14dp radius, 4dp shadow; bold value on top,
/// small mute label below. Plain platform tap feedback (not sticker-button
/// press-juice — these are navigational, not primary actions, design §9).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.ink,
    this.onTap,
  });

  final String value;
  final String label;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mute,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
