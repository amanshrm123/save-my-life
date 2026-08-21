import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_dots.dart';
import '../../../../core/widgets/sticker_button.dart';
import '../../domain/tour_step.dart';

/// The tour's floating "coach mark" (design v1 §3.2): the boxed paper card
/// (emoji + headline, body, dots + CTA) plus the `Skip the tour` link that
/// sits on the scrim just below it. Reuses the app's existing card chrome
/// verbatim — no new visual vocabulary.
class CoachMarkCard extends StatelessWidget {
  const CoachMarkCard({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.onAdvance,
    required this.onSkip,
  });

  final TourStep step;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onAdvance;

  /// `null` on the last step — "Got it" is the only exit there and a skip
  /// link would be redundant (design v1 §3.2).
  final VoidCallback? onSkip;

  bool get _isLastStep => stepIndex == stepCount - 1;

  static const TextStyle _headlineStyle = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 5), blurRadius: 0)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(step.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step.headline, style: _headlineStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(step.body, style: AppTypography.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PageDots(activeIndex: stepIndex, count: stepCount),
                    StickerButton(
                      label: _isLastStep ? 'Got it' : 'Next',
                      fill: AppColors.green,
                      labelShadow: AppColors.greenDark,
                      height: 36,
                      fontSize: 12,
                      restShadowOffset: 4,
                      onPressed: onAdvance,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (onSkip != null) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Skip the tour',
            child: GestureDetector(
              onTap: onSkip,
              behavior: HitTestBehavior.opaque,
              child: const Text('Skip the tour', style: AppTypography.ghostLink),
            ),
          ),
        ],
      ],
    );
  }
}
