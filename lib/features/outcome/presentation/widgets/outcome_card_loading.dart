import 'package:flutter/material.dart';

import '../../../play_loop/domain/run_state.dart';
import 'card_footer.dart';
import 'outcome_card_shell.dart';

/// Shared triangle-wave-through-`easeInOut` helper (design v1 §7.2): both
/// the heartbeat pulse and the dot bounce are the same shape, just at
/// different periods/phases/offsets — extracted once rather than duplicated
/// verbatim in `_OutcomeCardLoadingState` and `_DotsRow`.
double _triangleWave(double phase) {
  final raw = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return Curves.easeInOut.transform(raw);
}

/// Tier-themed branded loader (design v1 §7) shown every time before the
/// card resolves (min 2s, enforced one layer up by `outcomeStoryProvider`).
/// Shares `OutcomeCardShell`'s 9:16 silhouette with the resolved card so
/// nothing shifts on resolve, and already uses the final tier palette
/// (architecture v4 §4) so there's no colour flip when the loader swaps out.
///
/// Owns exactly one `AnimationController` (`repeat()`), driving BOTH the
/// heartbeat pulse (1s cycle) and the three staggered dots (0.9s cycle,
/// 0/.15/.3s offsets) off its real elapsed time — one `Ticker`, not four
/// (architecture v4 §8 risk 2). Disposed in `dispose()`; because this widget
/// only exists inside `AsyncValue.when(loading: ...)`, it unmounts (and
/// tears its ticker down) automatically the instant content resolves.
class OutcomeCardLoading extends StatefulWidget {
  const OutcomeCardLoading({super.key, required this.outcome});

  final RunOutcome outcome;

  @override
  State<OutcomeCardLoading> createState() => _OutcomeCardLoadingState();
}

class _OutcomeCardLoadingState extends State<OutcomeCardLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OutcomeTierPalette.of(widget.outcome);
    return OutcomeCardShell(
      palette: palette,
      builder: (context, k) {
        return Padding(
          padding: EdgeInsets.fromLTRB(22 * k, 26 * k, 22 * k, 22 * k),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final elapsedMs =
                            (_controller.lastElapsedDuration ?? Duration.zero).inMilliseconds;
                        final pulse = _triangleWave((elapsedMs % 1000) / 1000);
                        return Transform.scale(
                          scale: 1 + 0.18 * pulse,
                          child: Opacity(opacity: 1 - 0.3 * pulse, child: child),
                        );
                      },
                      child: Text(
                        '💓',
                        style: TextStyle(fontSize: 44 * k, height: 1),
                      ),
                    ),
                    SizedBox(height: 18 * k),
                    Text(
                      'Loading your life card…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 19 * k,
                        fontWeight: FontWeight.w700,
                        color: palette.baseText,
                      ),
                    ),
                    SizedBox(height: 18 * k),
                    _DotsRow(controller: _controller, color: palette.loaderDotColor, k: k),
                    SizedBox(height: 18 * k),
                    SizedBox(
                      width: 180 * k,
                      child: Text(
                        "Every run ends its own way. Let's see which one you got…",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12 * k,
                          fontWeight: FontWeight.w600,
                          color: palette.baseText.withValues(alpha: palette.loaderSublineOpacity),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Wordmark only, pinned at the bottom — no tagline, no store
              // badges during loading (design v1 §7.1).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: OutcomeWordmark(color: palette.baseText, accent: palette.wordmarkAccent, k: k),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Three dots, each translating Y 0 -> -6dp and opacity 0.4 -> 1 over a 0.9s
/// ease-in-out cycle, staggered 0/.15/.3s apart (design v1 §7.2) — all three
/// driven by the SAME shared [controller] (via its elapsed wall time), never
/// three independent `AnimationController`s.
class _DotsRow extends StatelessWidget {
  const _DotsRow({required this.controller, required this.color, required this.k});

  final AnimationController controller;
  final Color color;
  final double k;

  static const _periodMs = 900;
  static const _offsetsMs = [0, 150, 300];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) SizedBox(width: 6 * k),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final elapsedMs = (controller.lastElapsedDuration ?? Duration.zero).inMilliseconds;
              final phase = ((elapsedMs + _offsetsMs[i]) % _periodMs) / _periodMs;
              final eased = _triangleWave(phase);
              return Transform.translate(
                offset: Offset(0, -6 * k * eased),
                child: Opacity(opacity: 0.4 + 0.6 * eased, child: child),
              );
            },
            child: Container(
              width: 9 * k,
              height: 9 * k,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ],
    );
  }
}
