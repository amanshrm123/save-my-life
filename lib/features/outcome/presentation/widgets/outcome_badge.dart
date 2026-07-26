import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The centered pill badge atop every outcome card (design v3 §2.1): 2.5dp
/// ink border, 3dp offset ink shadow, 11/700 label.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge({super.key, required this.label, required this.fill, required this.textColor});

  final String label;
  final Color fill;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3), blurRadius: 0)],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.1,
        ),
      ),
    );
  }
}
