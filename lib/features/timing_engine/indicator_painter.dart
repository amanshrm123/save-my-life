import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/clock.dart';

/// Zone B of the Play screen (docs/design/play-screen-skeleton-v1.md §1):
/// the one moving/time element on screen, driven by a single [Ticker] that
/// reads elapsed time from the *same* [MonotonicClock] instance the tap
/// measurement uses (architecture v1 §1.2) — so display latency is a
/// constant offset, not drifting noise.
///
/// Bare form for this phase: a single vertical line sweeping left-to-right
/// across the zone as the current round approaches its target time. No
/// color ramps, no target-zone highlighting — that is explicitly Days 3-5
/// scope (play-screen-skeleton-v1.md §3).
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

  @override
  void paint(Canvas canvas, Size size) {
    final int elapsedInRound = clock.elapsedMicroseconds - roundStartMicros;
    final double progress = targetDurationMicros <= 0
        ? 0.0
        : (elapsedInRound / targetDurationMicros).clamp(0.0, 1.0);

    final double x = size.width * progress;
    final Paint linePaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) => true;
}
