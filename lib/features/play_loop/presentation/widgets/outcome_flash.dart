import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/run_config.dart';
import '../../domain/run_state.dart';
import '../../domain/scoring.dart';

/// The PERFECT/HIT/MISS flash pill (design spec v1 §1.4, §2.5/§2.6). Only
/// meaningful while `state.phase == RunPhase.stopped`.
///
/// Perfect and Hit share the identical "good" visual (green pill) per
/// design spec v1 §2.5 — the mock's `.flash` CSS has no third variant, they
/// differ only in label text. The final-band terminal stop (design spec v1
/// §2.7's "missing frame", filled in there) shows "SURVIVED"/"MISS" with no
/// percentage label instead, since no incremental life delta is applied in
/// sudden death — and unlike a normal attempt, only a Perfect earns
/// "SURVIVED" there ([survivesFinalBand]); a Hit flashes "MISS" too.
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
      good = survivesFinalBand(tier);
      label = good ? 'SURVIVED' : 'MISS';
    } else {
      good = tier != StopTier.miss;
      switch (tier) {
        case StopTier.perfect:
          label = 'PERFECT +${config.perfectDelta}%';
        case StopTier.hit:
          label = 'HIT +${config.hitDelta}%';
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
