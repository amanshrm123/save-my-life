import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/clock.dart';
import '../../core/theme.dart';

/// Zone B of the Play screen (docs/design/play-screen-skeleton-v1.md §1):
/// the one moving/time element on screen, driven by a single [Ticker] that
/// reads elapsed time from the *same* [MonotonicClock] instance the tap
/// measurement uses (architecture v1 §1.2) — so display latency is a
/// constant offset, not drifting noise.
///
/// A tick sweeping left-to-right across a bordered track as the current
/// round approaches its target time — the same paper/ink chrome as the
/// life bar and numplate (play-loop-v1.md §3), so it reads as a deliberate
/// progress lane rather than a stray floating line. player-reviewer
/// flagged the prior bare version (no track, no context) as looking like
/// unexplained render debris next to the now-chromed numplate. Still no
/// color ramps, no target-zone highlighting — that remains out of scope
/// (play-screen-skeleton-v1.md §3).
class IndicatorWidget extends StatefulWidget {
  const IndicatorWidget({
    super.key,
    required this.clock,
    required this.roundStartMicros,
    required this.targetDurationMicros,
  });

  final MonotonicClock clock;

  /// Elapsed-microseconds value (on [clock]) when the current round began.
  final int roundStartMicros;

  /// How many microseconds after [roundStartMicros] the target sits.
  final int targetDurationMicros;

  @override
  State<IndicatorWidget> createState() => _IndicatorWidgetState();
}

class _IndicatorWidgetState extends State<IndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// A `Listenable` bumped once per frame purely to trigger a repaint.
  /// The actual time value painted is always read fresh from
  /// [MonotonicClock.elapsedMicroseconds] inside [_IndicatorPainter.paint],
  /// never from the Ticker's own callback [Duration].
  final ValueNotifier<int> _repaintTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _repaintTick.value++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaintTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _IndicatorPainter(
        clock: widget.clock,
        roundStartMicros: widget.roundStartMicros,
        targetDurationMicros: widget.targetDurationMicros,
        repaint: _repaintTick,
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.clock,
    required this.roundStartMicros,
    required this.targetDurationMicros,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final MonotonicClock clock;
  final int roundStartMicros;
  final int targetDurationMicros;

  /// Lane height — a slim horizontal track centered in the available
  /// vertical space, matching the life bar's track thickness (§3.1) so the
  /// two bars read as part of the same visual system.
  static const double _laneHeight = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final int elapsedInRound = clock.elapsedMicroseconds - roundStartMicros;
    final double progress = targetDurationMicros <= 0
        ? 0.0
        : (elapsedInRound / targetDurationMicros).clamp(0.0, 1.0);

    final double laneTop = (size.height - _laneHeight) / 2;
    final Rect laneRect =
        Rect.fromLTWH(0, laneTop, size.width, _laneHeight);
    final RRect laneRRect =
        RRect.fromRectAndRadius(laneRect, const Radius.circular(999));

    final Paint trackFill = Paint()..color = AppColors.paper;
    final Paint trackBorder = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(laneRRect, trackFill);
    canvas.drawRRect(laneRRect, trackBorder);

    // The moving tick: a rounded vertical marker sliding along the lane,
    // clamped so it never draws outside the track's rounded ends.
    const double tickWidth = 6;
    final double x =
        (size.width * progress).clamp(tickWidth / 2, size.width - tickWidth / 2);
    final Rect tickRect = Rect.fromCenter(
      center: Offset(x, laneTop + _laneHeight / 2),
      width: tickWidth,
      height: _laneHeight - 4,
    );
    final Paint tickPaint = Paint()..color = AppColors.coral;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tickRect, const Radius.circular(3)),
      tickPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) => true;
}
