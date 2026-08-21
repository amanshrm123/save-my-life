import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/tour_step.dart';
import 'coach_mark_card.dart';

/// The Home dashboard's spotlight overlay (design v1 §3/§4): a full-screen,
/// input-absorbing scrim with a single animated cutout over the current
/// step's target, plus its floating coach mark. A plain `Positioned.fill`
/// child of Home's own `Stack` — never an `OverlayEntry`, never a pushed
/// route (design v1 §9.1/§9.2). Unmounting this widget (Home setting its
/// `_tourStep` back to null) tears down the painter, card and every implicit
/// animation ticker through the normal framework path — there is nothing
/// here to remember to clean up in a `dispose()`.
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.targetRect,
    required this.closing,
    required this.onAdvance,
    required this.onSkip,
    required this.onDismissed,
  });

  final TourStep step;
  final int stepIndex;
  final int stepCount;

  /// The current step's target rect, already converted to this overlay's
  /// own local coordinate space by `_HomeScreenState` (design v1 §5.1) —
  /// `null` for the one transient frame between the tour starting/advancing
  /// and the post-frame remeasure resolving it. The painter only ever
  /// receives this plain `Rect`, never the `GlobalKey`/`RenderObject` behind
  /// it (design v1 §9.4).
  final Rect? targetRect;

  /// True once a dismiss has been requested — drives the 150ms fade-out;
  /// [onDismissed] fires once that finishes (design v1 §3.3).
  final bool closing;

  final VoidCallback onAdvance;
  final VoidCallback onSkip;
  final VoidCallback onDismissed;

  static const double _cutoutInflate = 8;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  /// False for exactly the first built frame, so the initial `AnimatedOpacity`
  /// change from 0 -> 1 is a real, observed transition (180ms fade-in) rather
  /// than an already-settled value (design v1 §3.3). No ticker of its own —
  /// just a plain post-frame callback, the same idiom `ReminderOptInScreen`
  /// already uses for its "mark shown" write.
  bool _appeared = false;

  /// A snapshot of `opacity` (see [build]) from the LAST completed build —
  /// deliberately not re-derived live from [_appeared] when checked in
  /// [didUpdateWidget] (see that method's doc comment for why the two
  /// differ in exactly the race this guards against).
  double? _lastOpacity;

  /// Guards [_notifyDismissedOnce] so a genuine `AnimatedOpacity.onEnd`
  /// firing around the same time as the [didUpdateWidget] fallback below
  /// can never call [TourOverlay.onDismissed] twice.
  bool _dismissNotified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _appeared = true);
    });
  }

  @override
  void didUpdateWidget(covariant TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Code-reviewer finding #1 on this pass: `_requestEndTour` (Home) and
    // this widget's own `initState` post-frame callback (above) can both be
    // pending in the SAME frame's post-frame-callback batch (Home's
    // `_scheduleTourRemeasure` registers its callback before `TourOverlay`
    // is even built, so it runs first) -- e.g. when the very first target
    // measurement fails and immediately requests a dismiss. By the time
    // THIS widget rebuilds with `closing: true`, `_appeared` may already
    // have flipped `true` from that same earlier batch, so checking
    // `!_appeared` here live is unreliable -- it can read `true` even
    // though the opacity actually rendered last frame was 0 for a DIFFERENT
    // reason (not yet appeared) than the one forcing it now (closing).
    // `_lastOpacity` sidesteps that: it's what [build] actually computed
    // and rendered last time, snapshotted before any of this frame's field
    // mutations. If that was already 0.0, `AnimatedOpacity`'s target value
    // won't change across this update (0.0 -> 0.0) and it will never start
    // an animation, so its `onEnd` -- the only other path to
    // [TourOverlay.onDismissed] -- never fires. Left unhandled, Home is
    // stuck forever with `_tourStep` non-null: the overlay's opaque
    // `GestureDetector` keeps absorbing every tap (with `onTap` now null),
    // and `PopScope(canPop: false)` is still active, so back does nothing
    // either -- a permanent soft-lock. Finish immediately instead of
    // waiting for a fade transition that was never going to be visible
    // anyway.
    if (widget.closing && !oldWidget.closing && _lastOpacity == 0.0) {
      _notifyDismissedOnce();
    }
  }

  void _notifyDismissedOnce() {
    if (_dismissNotified) return;
    _dismissNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.targetRect;
    final opacity = (widget.closing || !_appeared) ? 0.0 : 1.0;
    _lastOpacity = opacity;
    final duration = Duration(milliseconds: widget.closing ? 150 : 180);

    return Positioned.fill(
      child: Semantics(
        label: '${widget.step.headline}. ${widget.step.body}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.closing ? null : widget.onAdvance,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: duration,
            onEnd: () {
              if (widget.closing) _notifyDismissedOnce();
            },
            child: rect == null
                ? const _BlankScrim()
                : _SpotlitContent(
                    step: widget.step,
                    stepIndex: widget.stepIndex,
                    stepCount: widget.stepCount,
                    targetRect: rect,
                    onAdvance: widget.onAdvance,
                    onSkip: widget.onSkip,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The plain full scrim shown for the single transient frame before the
/// first rect measurement resolves — no cutout, no ring, no card yet
/// (design v1 §5.1).
class _BlankScrim extends StatelessWidget {
  const _BlankScrim();

  @override
  Widget build(BuildContext context) {
    // No `Positioned.fill` here -- this sits directly under `AnimatedOpacity`
    // (a `FadeTransition`), not a `Stack`; it already receives the tight,
    // full-screen constraints the outer `Positioned.fill` established.
    return const CustomPaint(
      painter: _ScrimPainter(cutout: null, cutoutRadius: 0),
    );
  }
}

/// The real spotlight: cutout + ring (animated between steps via
/// `TweenAnimationBuilder<Rect?>`, design v1 §3.3) plus the placed coach
/// mark.
class _SpotlitContent extends StatelessWidget {
  const _SpotlitContent({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.targetRect,
    required this.onAdvance,
    required this.onSkip,
  });

  final TourStep step;
  final int stepIndex;
  final int stepCount;
  final Rect targetRect;
  final VoidCallback onAdvance;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final cutout = targetRect.inflate(TourOverlay._cutoutInflate);
    final screenSize = MediaQuery.sizeOf(context);
    final showSkip = stepIndex < stepCount - 1;

    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: cutout),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedCutout, child) {
        final resolvedCutout = animatedCutout ?? cutout;
        final radius = step.isCircularCutout
            ? resolvedCutout.height / 2
            : step.cornerRadius;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScrimPainter(
                  cutout: resolvedCutout,
                  cutoutRadius: radius,
                ),
              ),
            ),
            _CoachMarkPlacement(
              cutout: resolvedCutout,
              screenSize: screenSize,
              child: CoachMarkCard(
                step: step,
                stepIndex: stepIndex,
                stepCount: stepCount,
                onAdvance: onAdvance,
                onSkip: showSkip ? onSkip : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Design v1 §3.2: below the cutout when its bottom edge sits in the top
/// 55% of the screen, otherwise above it, with a 12dp gap. Horizontally
/// clamped to the screen's 16dp gutters. No arrow/tail in v1.
class _CoachMarkPlacement extends StatelessWidget {
  const _CoachMarkPlacement({
    required this.cutout,
    required this.screenSize,
    required this.child,
  });

  final Rect cutout;
  final Size screenSize;
  final Widget child;

  static const double _gap = 12;
  static const double _gutter = 16;
  static const double _placeBelowThreshold = 0.55;

  @override
  Widget build(BuildContext context) {
    final placeBelow =
        cutout.bottom <= screenSize.height * _placeBelowThreshold;
    return Positioned(
      left: _gutter,
      right: _gutter,
      top: placeBelow ? cutout.bottom + _gap : null,
      bottom: placeBelow ? null : screenSize.height - cutout.top + _gap,
      child: Center(child: child),
    );
  }
}

/// Design v1 §3.1 — the single load-bearing painting decision: one
/// `Path.combine(PathOperation.difference, ...)` plus one `drawPath` for the
/// scrim, and one `drawRRect` for the ring. Deliberately **not**
/// `saveLayer` + `BlendMode.clear`, which would allocate a full-screen
/// offscreen buffer every frame the tour is visible — exactly the wrong
/// trade for this app's RAM-resident design (design v1 §9.5). Holds only a
/// `Rect?` and a `double`, never a `GlobalKey`/`BuildContext`/`RenderObject`
/// (design v1 §9.4), so `shouldRepaint` is a plain value comparison.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.cutout, required this.cutoutRadius});

  final Rect? cutout;
  final double cutoutRadius;

  static const double _scrimOpacity = 0.72;
  static const double _ringWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()
      ..color = AppColors.ink.withValues(alpha: _scrimOpacity);
    final screenRect = Offset.zero & size;

    final cutout = this.cutout;
    if (cutout == null) {
      canvas.drawRect(screenRect, scrimPaint);
      return;
    }

    final cutoutRRect = RRect.fromRectAndRadius(
      cutout,
      Radius.circular(cutoutRadius),
    );
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(screenRect),
      Path()..addRRect(cutoutRRect),
    );
    canvas.drawPath(scrimPath, scrimPaint);

    final ringPaint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringWidth;
    canvas.drawRRect(cutoutRRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter oldDelegate) {
    return oldDelegate.cutout != cutout ||
        oldDelegate.cutoutRadius != cutoutRadius;
  }
}
