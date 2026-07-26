import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sticker_button.dart';

/// 7.3 Reset confirm (design v3 §6.4) — reuses Play Loop's pause-modal
/// pattern (scrim, `bg` card, 3dp border, 22dp radius, 8dp shadow) plus a
/// leading 30dp "⚠️" emoji. Primary is red (`red` fill, `redDark` text
/// shadow — the same pair as the final-band STOP button); secondary is a
/// plain `.ghostbtn` "Cancel."
///
/// Copy trimmed from the mockup's "streak, stats, and collection" to
/// "streak and stats" (design v3 §6.4) — the card-collection feature is out
/// of scope this pass, so there is no collection data to honestly reference.
Future<bool> showResetConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (context) => const ResetConfirmDialog(),
  );
  return result ?? false;
}

class ResetConfirmDialog extends StatelessWidget {
  const ResetConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 8), blurRadius: 0)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 10),
            const Text(
              'Reset everything?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Deletes your streak and stats. Can't be undone.",
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 16),
            StickerButton(
              label: 'Yes, reset',
              fill: AppColors.red,
              labelShadow: AppColors.redDark,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            StickerButton(
              label: 'Cancel',
              fill: AppColors.paper,
              labelShadow: AppColors.ink,
              textColor: AppColors.ink,
              showLabelTextShadow: false,
              height: 40,
              borderRadius: 14,
              fontSize: 13,
              restShadowOffset: 4,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
