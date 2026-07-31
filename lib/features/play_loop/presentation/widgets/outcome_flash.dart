import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/run_config.dart';
import '../../domain/run_state.dart';

/// The HIT/MISS flash pill (design spec v3 §6, revising v1 §1.4/§2.5-§2.6
/// for architecture v6's binary scoring). Only meaningful while
/// `state.phase == RunPhase.stopped`.
///
/// `HIT` is bare — no percentage, no "+0%" — for the same reason the legend
/// pill says "safe": there is no delta to report (architecture v6 §6.4).
/// The final-band terminal stop (design spec v1 §2.7's "missing frame",
/// filled in there) shows "SURVIVED"/"MISS" with no percentage label
/// instead, unchanged, even though a delta is now applied on that path too
/// (v6 §4.4) — that frame's job is to announce the ending, not the
/// arithmetic.
class OutcomeFlash extends StatelessWidget {
  const OutcomeFlash({super.key, required this.state, this.config = RunConfig.defaults});

  final RunState state;
  final RunConfig config;

  @override
  Widget build(BuildContext context) {
    final tier = state.lastTier;
    if (state.phase != RunPhase.stopped || tier == null) {
      return const SizedBox.shrink();
    }

    final String label;
    final bool good;
    if (state.lastStopWasFinalBand) {
      good = tier != StopTier.miss;
      label = good ? 'SURVIVED' : 'MISS';
    } else {
      good = tier != StopTier.miss;
      switch (tier) {
        case StopTier.hit:
          label = 'HIT';
        case StopTier.miss:
          label = 'MISS ${config.missDelta}%';
      }
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(state.attemptIndex),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: 0.85 + (0.15 * value.clamp(0, 1)), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        constraints: const BoxConstraints(minWidth: 90),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: good ? AppColors.green : AppColors.red,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.ink, width: 2.5),
          boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 4), blurRadius: 0)],
        ),
        child: Semantics(
          liveRegion: true,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
