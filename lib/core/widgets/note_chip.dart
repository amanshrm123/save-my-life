import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "note" chip (design v3 §1.3/§10) — one widget, two color variants.
/// Positive/neutral (streak-broken hint, 6.3) and error (onboarding's
/// inline name-rejection note, reused as-is by Settings' edit-name dialog)
/// share the same shape, differing only in color.
class NoteChip extends StatelessWidget {
  const NoteChip({
    super.key,
    required this.text,
    required this.bg,
    required this.textColor,
    this.border,
    this.shrinkWrap = false,
  });

  factory NoteChip.positive({Key? key, required String text}) {
    return NoteChip(key: key, text: text, bg: AppColors.noteBg, textColor: AppColors.noteText);
  }

  factory NoteChip.error({Key? key, required String text}) {
    return NoteChip(key: key, text: text, bg: AppColors.errorNoteBg, textColor: AppColors.red);
  }

  /// The avatar-card "Pick your look" hint's third variant (design
  /// `home-avatars-v1.md` §2.6): bordered rather than solid-filled, so it
  /// reads as a hint, not a button, on the same `bg` background the card
  /// itself sits on. Design §2.6 calls this a "pill", not a full-width
  /// banner, so — unlike the other two variants — it shrink-wraps to its
  /// own content instead of stretching to fill the ambient width.
  factory NoteChip.hint({Key? key, required String text}) {
    return NoteChip(
      key: key,
      text: text,
      bg: AppColors.paper,
      textColor: AppColors.coral,
      border: Border.all(color: AppColors.coral, width: 1.5),
      shrinkWrap: true,
    );
  }

  final String text;
  final Color bg;
  final Color textColor;
  final BoxBorder? border;

  /// When true, sizes to the text's own content instead of stretching to
  /// fill the incoming width (`NoteChip.hint`'s "pill" treatment).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: shrinkWrap ? null : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: border),
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
