import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "note" chip (design v3 §1.3/§10) — one widget, two color variants.
/// Positive/neutral (streak-broken hint, 6.3) and error (onboarding's
/// inline name-rejection note, reused as-is by Settings' edit-name dialog)
/// share the same shape, differing only in color.
class NoteChip extends StatelessWidget {
  const NoteChip({super.key, required this.text, required this.bg, required this.textColor});

  factory NoteChip.positive({Key? key, required String text}) {
    return NoteChip(key: key, text: text, bg: AppColors.noteBg, textColor: AppColors.noteText);
  }

  factory NoteChip.error({Key? key, required String text}) {
    return NoteChip(key: key, text: text, bg: AppColors.errorNoteBg, textColor: AppColors.red);
  }

  final String text;
  final Color bg;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.35,
        ),
      ),
    );
  }
}
