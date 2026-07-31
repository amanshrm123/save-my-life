import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's one toast-pill visual — a dark `AppColors.ink` rounded pill,
/// white 11dp/w600 Fredoka text. Originally the outcome screen's private
/// `_ShareToast` (the "✓ Shared" post-share confirm); promoted here
/// (architecture v5 / design share-target-sheet-v1 §8.2) so
/// `ShareTargetSheet`'s two new error-copy toasts can reuse the exact same
/// widget with different text instead of a second color/shape language —
/// this app deliberately keeps exactly one toast treatment app-wide.
class ToastPill extends StatelessWidget {
  const ToastPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
