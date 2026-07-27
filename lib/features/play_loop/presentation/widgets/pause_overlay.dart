import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sticker_button.dart';

/// The pause modal (design spec v1 §1.6/§2.8) — the first modal in the app,
/// setting the house style for every future one: full-screen scrim
/// (absorbs all taps so the HUD beneath can't be interacted with),
/// `bg`-colored card (not `paper` — "the app itself coming forward"),
/// thicker 3dp border, 22dp radius, 8dp offset shadow.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // absorb taps — nothing beneath the scrim is reachable.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, t, child) {
            return Container(
              color: AppColors.ink.withValues(alpha: 0.55 * t),
              alignment: Alignment.center,
              child: Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.92 + (0.08 * t), child: child),
              ),
            );
          },
          child: _PauseCard(onResume: onResume, onRestart: onRestart, onQuit: onQuit),
        ),
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  const _PauseCard({required this.onResume, required this.onRestart, required this.onQuit});

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Paused',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your run is safe. Take your time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.bodyMute,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          StickerButton(
            label: 'Resume',
            fill: AppColors.green,
            labelShadow: AppColors.greenDark,
            onPressed: onResume,
          ),
          const SizedBox(height: 10),
          StickerButton(
            label: 'Restart run',
            fill: AppColors.paper,
            labelShadow: AppColors.ink,
            textColor: AppColors.ink,
            showLabelTextShadow: false,
            height: 40,
            borderRadius: 14,
            fontSize: 13,
            restShadowOffset: 4,
            onPressed: onRestart,
          ),
          const SizedBox(height: 10),
          StickerButton(
            label: 'Quit to home',
            fill: AppColors.paper,
            labelShadow: AppColors.ink,
            textColor: AppColors.ink,
            showLabelTextShadow: false,
            height: 40,
            borderRadius: 14,
            fontSize: 13,
            restShadowOffset: 4,
            onPressed: onQuit,
          ),
        ],
      ),
    );
  }
}
