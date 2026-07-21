import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// The bare-text "Skip" / "Skip for now" link shared by the teaching cards
/// (top-right, §3.4) and the name-capture screen (bottom, §5.5) — identical
/// styling (`mute`, underlined, 12sp/600, no background/border) so it never
/// competes visually with the primary CTA. Scoped to `onboarding/` since
/// nothing outside onboarding reuses this exact styling.
class SkipLink extends StatelessWidget {
  const SkipLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.mute,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.mute,
        ),
      ),
    );
  }
}
