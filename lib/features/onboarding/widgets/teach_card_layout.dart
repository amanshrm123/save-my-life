import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/dot_progress.dart';
import '../../../core/widgets/sticker_button.dart';
import 'skip_link.dart';

/// Shared icon/heading/body/dots/button column backing 1.2/1.3/1.4
/// (docs/design/onboarding-flow-v1.md §5.3). Onboarding-specific — nothing
/// outside onboarding reuses this exact composition, unlike `StickerButton`/
/// `DotProgress` which live in `core/widgets/`.
class TeachCard extends StatelessWidget {
  const TeachCard({
    super.key,
    required this.icon,
    required this.heading,
    required this.body,
    required this.buttonLabel,
    required this.dotIndex,
    required this.pageController,
    required this.onPrimary,
    required this.onSkip,
  });

  /// Per-card icon. Rendered via the OS system emoji font — no bundling, no
  /// network (§5.3 note).
  final String icon;
  final String heading;
  final String body;

  /// "Next" (1.2/1.3) or "Got it" (1.4) — the label is the only thing that
  /// varies about the primary button between cards.
  final String buttonLabel;

  /// This card's own 0-based dot position (0, 1, or 2 of 3) — the fallback
  /// used before [pageController] has laid out and reported a live `page`
  /// value.
  final int dotIndex;

  /// The shared `PageView`'s controller. The dot row is driven from its
  /// live `page` value directly (§5.4: "no separate state needed, this is
  /// a pure function of the controller's next()/skipToName() calls having
  /// already fired") so a manual swipe mid-drag is reflected too, not just
  /// a discrete jump on page-settle.
  final PageController pageController;

  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Body max-width as a fraction of screen width with a ~230dp cap (§7),
    // not a hardcoded dp value, so it doesn't clip on the smallest
    // supported phone width.
    final double bodyMaxWidth =
        math.min(MediaQuery.of(context).size.width * 0.62, 230);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SkipLink(label: 'Skip', onTap: onSkip),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 20),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: bodyMaxWidth),
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.teachBody,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: pageController,
                    builder: (context, _) {
                      final double? livePage =
                          pageController.hasClients ? pageController.page : null;
                      final int active =
                          livePage != null ? livePage.round() : dotIndex;
                      return DotProgress(activeIndex: active);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: SizedBox(
                width: double.infinity,
                child: StickerButton(
                  label: buttonLabel,
                  fillColor: AppColors.green,
                  textShadowColor: AppColors.greenDark,
                  onPressed: onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
