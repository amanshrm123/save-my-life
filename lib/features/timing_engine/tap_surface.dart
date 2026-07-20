import 'package:flutter/widgets.dart';

import '../../core/clock.dart';

/// The tap zone. Wraps a [Listener] (NOT `GestureDetector`, NOT `InkWell`/
/// `ElevatedButton`) so the press timestamp is read directly off the raw
/// pointer event with no gesture-arena resolution delay — architecture v1
/// §1.2, hard rule.
///
/// [onTapMicros] is called with the elapsed-microsecond timestamp, read as
/// the very first statement inside `onPointerDown`.
class TapSurface extends StatelessWidget {
  const TapSurface({
    super.key,
    required this.clock,
    required this.onTapMicros,
    this.child,
  });

  final MonotonicClock clock;
  final ValueChanged<int> onTapMicros;
  final Widget? child;

  void _handlePointerDown(PointerDownEvent event) {
    final int pressMicros = clock.elapsedMicroseconds; // first statement
    onTapMicros(pressMicros);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
