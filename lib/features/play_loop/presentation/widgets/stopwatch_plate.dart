import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/clock_format.dart';

/// The live/frozen stopwatch readout (design spec v1 §1.4/§3.3), one
/// parametrized widget covering every instance in the loop:
/// - **Running = outlined**: paper background, colored border/shadow/digits.
/// - **Stopped = filled**: solid color fill, white digits.
///
/// The "gameplay-actual" override size (14x18dp padding / 40dp digits,
/// re-sized by design spec v3 §4.3 for the 7-glyph `M:SS.CC` readout, was
/// 14x30dp/52dp under the retired 4-glyph `SS:CC` format) is used
/// unconditionally — design spec v1 §1.4 notes the base mock class's
/// smaller defaults are never actually used in this feature.
class StopwatchPlate extends StatelessWidget {
  const StopwatchPlate({
    super.key,
    required this.filled,
    required this.tint,
    this.liveElapsed,
    this.staticValue,
  }) : assert(
         (liveElapsed != null) != (staticValue != null),
         'Provide exactly one of liveElapsed (running) or staticValue (stopped).',
       );

  /// Filled (solid color, white digits) = Stopped. Outlined (paper bg,
  /// colored border/digits) = Running.
  final bool filled;

  /// Border/shadow/digit tint (outlined) or the solid fill color (filled).
  final Color tint;

  /// Live count-up source, bypassing Riverpod (architecture v2 §1/§9.6) —
  /// only this widget listens to it, at 60fps, via [ValueListenableBuilder].
  final ValueListenable<Duration>? liveElapsed;

  /// Frozen value to render once stopped.
  final Duration? staticValue;

  static const TextStyle _digits = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: filled ? tint : AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: tint, width: 2.5),
      boxShadow: [BoxShadow(color: tint, offset: const Offset(0, 4), blurRadius: 0)],
    );
    final digitColor = filled ? Colors.white : tint;
    final digitStyle = _digits.copyWith(color: digitColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: decoration,
      child: liveElapsed != null
          ? ValueListenableBuilder<Duration>(
              valueListenable: liveElapsed!,
              builder: (context, value, _) {
                return Text(formatClock(value), style: digitStyle);
              },
            )
          : Text(formatClock(staticValue!), style: digitStyle),
    );
  }
}
