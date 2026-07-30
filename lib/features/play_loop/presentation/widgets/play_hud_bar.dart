import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/run_state.dart';
import 'life_avatar.dart';
import 'run_chips.dart';

/// The new combined top HUD row (design spec v2 §1.2), replacing v1's
/// two-row chrome (`RunChips` + `LifeBar`, 64dp total) with a single 72dp
/// row: the player's own avatar figure as a life-meter, beside a flexible
/// text column (Run chip + pause button on one line, the life-meta caption
/// below it).
class PlayHudBar extends StatelessWidget {
  const PlayHudBar({
    super.key,
    required this.state,
    required this.onPause,
  });

  final RunState state;
  final VoidCallback onPause;

  bool get _isCritical =>
      state.isFinalBand || (state.phase == RunPhase.stopped && state.lastStopWasFinalBand);

  @override
  Widget build(BuildContext context) {
    return Row(
      // The avatar (72dp) is the tallest element; the text stack beside it
      // (chip/pause line + 5dp gap + caption line, ~46dp) is vertically
      // centered against it (design spec v2 §1.2 table, judgment call: the
      // architect's spec doesn't pin vertical alignment).
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LifeAvatar(lifePercent: state.lifePercent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RunChips(runNumber: state.runNumber, onPause: onPause),
              const SizedBox(height: 5),
              _MetaCaption(state: state, isCritical: _isCritical),
            ],
          ),
        ),
      ],
    );
  }
}

/// Relocated verbatim from `life_bar.dart` (design spec v2 §1.4): same 3
/// copy/style variants, just given `maxLines: 1` + ellipsis since the
/// column is now narrower, sharing width with the chip/pause line above it.
class _MetaCaption extends StatelessWidget {
  const _MetaCaption({required this.state, required this.isCritical});

  final RunState state;
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      'Life ${state.lifePercent}%',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _base.copyWith(color: AppColors.hudMute),
    );
  }
}
