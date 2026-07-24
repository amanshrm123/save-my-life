import 'package:flutter/material.dart';

import '../../core/routing/app_page_transitions.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sticker_button.dart';
import '../play_loop/domain/run_state.dart';
import '../play_loop/presentation/play_loop_screen.dart';

/// Genuinely-working handoff target for a finished run (architecture v2 §8):
/// shows which of death / survived / eternal occurred, with "Again" (fresh
/// run) / "Home" actions. Real outcome cards (mockup Section 3) are
/// explicitly deferred — this stands in for them end-to-end.
class PlaceholderOutcomeScreen extends StatelessWidget {
  const PlaceholderOutcomeScreen({super.key, required this.outcome});

  final RunOutcome outcome;

  _OutcomeCopy get _copy {
    switch (outcome) {
      case RunOutcome.death:
        return const _OutcomeCopy(
          badge: 'DEATH',
          headline: "That's a wipe.",
          body: 'The clock got you this time. Every run teaches you the beat a little better.',
          color: AppColors.red,
        );
      case RunOutcome.survived:
        return const _OutcomeCopy(
          badge: 'SURVIVED',
          headline: 'One clean stop saved you.',
          body: 'You nailed the last-chance tap and walked away from sudden death.',
          color: AppColors.green,
        );
      case RunOutcome.eternal:
        return const _OutcomeCopy(
          badge: 'ETERNAL',
          headline: 'Three perfects, cold.',
          body: "You never even wobbled. That's as good as this game gets.",
          color: AppColors.gold,
        );
    }
  }

  void _again(BuildContext context) {
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(
        settings: const RouteSettings(name: AppRoutes.play),
        builder: (context) => const PlayLoopScreen(),
      ),
    );
  }

  void _home(BuildContext context) {
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == AppRoutes.placeholderHome);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: copy.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    copy.badge,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  copy.headline,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline,
                ),
                const SizedBox(height: 10),
                Text(copy.body, textAlign: TextAlign.center, style: AppTypography.body),
                const SizedBox(height: 24),
                StickerButton(
                  label: 'Again',
                  fill: AppColors.coral,
                  labelShadow: AppColors.coralDark,
                  onPressed: () => _again(context),
                ),
                const SizedBox(height: 12),
                StickerButton(
                  label: 'Home',
                  fill: AppColors.paper,
                  labelShadow: AppColors.ink,
                  textColor: AppColors.ink,
                  showLabelTextShadow: false,
                  height: 40,
                  borderRadius: 14,
                  fontSize: 13,
                  restShadowOffset: 4,
                  onPressed: () => _home(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeCopy {
  const _OutcomeCopy({
    required this.badge,
    required this.headline,
    required this.body,
    required this.color,
  });

  final String badge;
  final String headline;
  final String body;
  final Color color;
}
