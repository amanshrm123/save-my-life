import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/run_config.dart';
import '../../domain/run_state.dart';

/// Top life bar + meta caption (design spec v1 §1.4/§3.4), covering
/// screens 2.3-2.7. Color-state rule (§3.4), resolved precisely:
/// 1. Baseline (Armed/Running): green fill, plain "Life N%", no arrow.
/// 2. Transient tier-tint (Stopped dwell only): green+▲ (good) or
///    coral-fill+red-▼ (miss) — clears the instant the dwell ends.
/// 3. Critical override (persistent while in the final band, including its
///    terminal Stopped dwell): red fill, combined "N% · next miss is fatal"
///    caption, replacing the arrow template. Always wins over rule 2.
class LifeBar extends StatelessWidget {
  const LifeBar({super.key, required this.state, this.config = RunConfig.defaults});

  final RunState state;
  final RunConfig config;

  bool get _isCritical =>
      state.isFinalBand || (state.phase == RunPhase.stopped && state.lastStopWasFinalBand);

  @override
  Widget build(BuildContext context) {
    final life = state.lifePercent.clamp(0, 100);
    final fraction = life / 100;

    Color fillColor;
    if (_isCritical) {
      fillColor = AppColors.red;
    } else if (state.phase == RunPhase.stopped && state.lastTier != null) {
      fillColor = state.lastTier == StopTier.miss ? AppColors.coral : AppColors.green;
    } else {
      fillColor = AppColors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          padding: const EdgeInsets.all(1.5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  width: constraints.maxWidth * fraction,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 5),
        _MetaCaption(state: state, config: config, isCritical: _isCritical),
      ],
    );
  }
}

class _MetaCaption extends StatelessWidget {
  const _MetaCaption({required this.state, required this.config, required this.isCritical});

  final RunState state;
  final RunConfig config;
  final bool isCritical;

  static const TextStyle _base = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 9,
    fontWeight: FontWeight.w600,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    if (isCritical) {
      return Text(
        '${state.lifePercent}% · next miss is fatal',
        style: _base.copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
      );
    }

    if (state.phase == RunPhase.stopped && state.lastTier != null) {
      final good = state.lastTier != StopTier.miss;
      return Text.rich(
        TextSpan(
          style: _base.copyWith(color: AppColors.hudMute),
          children: [
            TextSpan(text: 'Life ${state.lifePercent}% '),
            TextSpan(
              text: good ? '▲' : '▼',
              style: TextStyle(color: good ? AppColors.green : AppColors.red),
            ),
          ],
        ),
      );
    }

    return Text('Life ${state.lifePercent}%', style: _base.copyWith(color: AppColors.hudMute));
  }
}
