import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sticker_button.dart';
import 'streak_bar.dart';

/// 6.2 streak-advanced (design v3 §5.2) — a Home *state* that wholesale
/// replaces the dashboard body, **not** a scrim overlay (unlike Play Loop's
/// Pause) — deliberately a different convention, per the design doc's
/// explicit call-out not to reuse the Pause visual pattern here.
///
/// Fires once, on the first Home build after `registerPlay` returns
/// `advanced`; the caller clears the transient flag once this is shown.
class StreakAdvancedView extends StatefulWidget {
  const StreakAdvancedView({super.key, required this.dayCount, required this.onPlay});

  final int dayCount;
  final VoidCallback onPlay;

  @override
  State<StreakAdvancedView> createState() => _StreakAdvancedViewState();
}

class _StreakAdvancedViewState extends State<StreakAdvancedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A definite celebratory beat (design v3 §8.2): the emoji does a quick
    // bounce/scale-in on entry, and the newly-filled week-bar segment
    // animates in via `StreakWeekBar`'s own `AnimatedContainer`.
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bounce = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: bounce,
              child: Semantics(
                label: 'fire',
                excludeSemantics: true,
                child: Text('🔥', style: TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Day ${widget.dayCount} — streak alive!',
              textAlign: TextAlign.center,
              style: AppTypography.headline,
            ),
            const SizedBox(height: 8),
            const Text(
              'You came back. Keep it going.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 16),
            StreakWeekBar(streakCount: widget.dayCount, segmentHeight: 8, borderWidth: 2),
            const SizedBox(height: 22),
            StickerButton(
              label: 'Play day ${widget.dayCount}',
              fill: AppColors.coral,
              labelShadow: AppColors.coralDark,
              onPressed: widget.onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
