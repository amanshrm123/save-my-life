import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The 7-segment weekly streak bar (design v3 §5.1) — a single configurable
/// widget with a size parameter, since Home's mini bar (6dp/1.5dp-border)
/// and the Streak-Advanced celebration's larger bar (8dp/2dp-border) are
/// genuinely different sizes, not one fixed instance reused verbatim.
///
/// Segment count beyond 7 days is capped: `min(streakCount, 7)` filled
/// segments (design v3 §5.1's resolved recommendation — no calendar-week
/// alignment, no wrap-around animation).
class StreakWeekBar extends StatelessWidget {
  const StreakWeekBar({
    super.key,
    required this.streakCount,
    this.segmentHeight = 6,
    this.borderWidth = 1.5,
  });

  final int streakCount;
  final double segmentHeight;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final filled = streakCount.clamp(0, 7);
    return Row(
      children: List.generate(7, (i) {
        final isFilled = i < filled;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: segmentHeight,
              decoration: BoxDecoration(
                color: isFilled ? AppColors.coral : AppColors.paper2,
                borderRadius: BorderRadius.circular(segmentHeight / 2),
                border: Border.all(color: AppColors.ink, width: borderWidth),
              ),
            ),
          ),
        );
      }),
    );
  }
}
