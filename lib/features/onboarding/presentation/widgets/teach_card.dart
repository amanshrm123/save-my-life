import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/page_dots.dart';
import '../../../../core/widgets/sticker_button.dart';

/// Reusable teach-card body (design spec v1 §2.2-2.4): emoji mark, headline,
/// description, dot indicator, and a single green sticker-button CTA whose
/// label changes ("Next" on cards 1-2, "Got it" on card 3) — same widget,
/// same color/shadow/radius, only the string differs.
///
/// Deliberately a stateless, cheap widget: PageView pages must not opt into
/// `AutomaticKeepAliveClientMixin` (architecture v1 §8.9) — nothing here
/// needs to survive being scrolled off-screen.
class TeachCard extends StatelessWidget {
  const TeachCard({
    super.key,
    required this.emoji,
    required this.emojiSemanticLabel,
    required this.headline,
    required this.body,
    required this.dotIndex,
    required this.buttonLabel,
    required this.onButtonPressed,
  });

  final String emoji;
  final String emojiSemanticLabel;
  final String headline;
  final String body;
  final int dotIndex;
  final String buttonLabel;
  final VoidCallback onButtonPressed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bodyMaxWidth = (screenWidth * 0.78).clamp(0, 320).toDouble();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: emojiSemanticLabel,
                  excludeSemantics: true,
                  child: Text(emoji, style: const TextStyle(fontSize: 38)),
                ),
                const SizedBox(height: 10),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bodyMaxWidth),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                ),
                const SizedBox(height: 10),
                PageDots(activeIndex: dotIndex),
                const SizedBox(height: 10),
                StickerButton(
                  label: buttonLabel,
                  fill: AppColors.green,
                  labelShadow: AppColors.greenDark,
                  onPressed: onButtonPressed,
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
