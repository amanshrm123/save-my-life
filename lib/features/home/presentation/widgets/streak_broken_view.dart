import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/note_chip.dart';
import '../../../../core/widgets/sticker_button.dart';

/// 6.3 streak-broken (design v3 §5.3) — same "Home state, not overlay"
/// pattern as 6.2. Shown at Home-open when `isBrokenAtOpen` is true and the
/// player hasn't played today yet.
class StreakBrokenView extends StatelessWidget {
  const StreakBrokenView({
    super.key,
    required this.previousStreak,
    required this.onStartNewStreak,
  });

  final int previousStreak;
  final VoidCallback onStartNewStreak;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'broken heart',
              excludeSemantics: true,
              child: Text('💔', style: TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 12),
            const Text('Your streak broke', textAlign: TextAlign.center, style: AppTypography.headline),
            const SizedBox(height: 8),
            Text(
              '$previousStreak ${previousStreak == 1 ? 'day' : 'days'}, gone. '
              'Play today to start again.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 14),
            NoteChip.positive(text: 'Come back tomorrow to keep the next one alive'),
            const SizedBox(height: 22),
            StickerButton(
              label: 'Start a new streak',
              fill: AppColors.coral,
              labelShadow: AppColors.coralDark,
              onPressed: onStartNewStreak,
            ),
          ],
        ),
      ),
    );
  }
}
