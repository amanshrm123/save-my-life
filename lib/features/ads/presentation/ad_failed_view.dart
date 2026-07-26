import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sticker_button.dart';

/// 8.3 ad-failed (design v3 §4.6) — a state substitution shown in place of
/// whichever ad screen would have appeared, whenever `AdService` resolves
/// to `failedToLoad`. "Maybe later" always continues the flow (architecture
/// §5 — never strands the player mid-loop).
class AdFailedView extends StatelessWidget {
  const AdFailedView({super.key, required this.onRetry, required this.onMaybeLater});

  final VoidCallback onRetry;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'no signal',
                  excludeSemantics: true,
                  child: Text('📶', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 14),
                const Text("Ad didn't load", textAlign: TextAlign.center, style: AppTypography.headline),
                const SizedBox(height: 10),
                const Text(
                  "Couldn't fetch an ad right now. Try again in a moment.",
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 22),
                StickerButton(
                  label: 'Retry',
                  fill: AppColors.green,
                  labelShadow: AppColors.greenDark,
                  onPressed: onRetry,
                ),
                const SizedBox(height: 10),
                StickerButton(
                  label: 'Maybe later',
                  fill: AppColors.paper,
                  labelShadow: AppColors.ink,
                  textColor: AppColors.ink,
                  showLabelTextShadow: false,
                  height: 40,
                  borderRadius: 14,
                  fontSize: 13,
                  restShadowOffset: 4,
                  onPressed: onMaybeLater,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
