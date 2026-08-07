import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/avatar_fill_band.dart';
import '../../domain/avatar_spec.dart';

/// Canonical reference box (design `home-avatars-v1.md` §3.1) — the
/// painter's logical coordinate space; `_AvatarFigurePainter` scales this up
/// to whatever actual `Size` it's given.
const double _kUnitWidth = 84;
const double _kUnitHeight = 104;

/// The procedural avatar figure (design `home-avatars-v1.md` §3): a plain
/// `CustomPainter` — zero image assets, zero `flutter_svg`, zero
/// `ImageCache` entries. Doubles as a life-meter: [fillPercent] drives the
/// body vessel's bottom-up fill color/height.
///
/// The fill animates via an implicit `TweenAnimationBuilder` (matching
/// `LifeBar`'s `AnimatedContainer` convention) rather than a manually-owned
/// `AnimationController` when [continuousWave] is `false` — nothing in that
/// path needs an explicit `dispose()`, and the animation only ever runs
/// while this widget is actually built/mounted. This is Home's/the avatar
/// picker's path (default) and is byte-for-byte unchanged from before this
/// widget grew a `continuousWave` mode.
///
/// When [continuousWave] is `true` (juice spec effect 1, Play-screen
/// `LifeAvatar` only), this widget instead owns two `AnimationController`s:
/// one always-`repeat()`-ing controller driving an organic "sloshing
/// liquid" wave phase on the fill's top edge, and one short-lived easing
/// controller that restarts whenever [fillPercent] changes, both to drive
/// the actual bottom-up fill height AND to signal "a fill change is in
/// flight" so the wave can briefly grow choppier. The fill COLOR is still
/// driven purely by the existing instant `avatarFillColorForPercent` — no
/// color-tween machinery is added here (out of scope for this pass, see
/// this feature's implementation notes).
class AvatarFigure extends StatefulWidget {
  const AvatarFigure({
    super.key,
    required this.spec,
    required this.fillPercent,
    this.shouldAnimate = true,
    this.continuousWave = false,
  });

  final AvatarSpec spec;

  /// 0-100. Clamped defensively; callers (`HomeAvatarCard`/`AvatarTile`)
  /// already only ever pass in-range values.
  final int fillPercent;

  /// Whether the bottom-up fill height should animate towards [fillPercent]
  /// (via the implicit `TweenAnimationBuilder` when [continuousWave] is
  /// `false`, or via the owned fill-easing `AnimationController` when it's
  /// `true`), or snap straight to it with no interpolation. Home threads its
  /// own `RouteAware` visibility signal in here (see `_HomeScreenState`): the
  /// tween must not run while Home sits mounted-but-offscreen (behind
  /// Play/Outcome), since it would silently finish before the player ever
  /// sees it, replacing the intended animated fill change with a snap once
  /// Home becomes visible again.
  final bool shouldAnimate;

  /// Juice spec effect 1: continuous "sloshing liquid" wave on the fill's
  /// top edge, plus a boosted wave amplitude while a fill change is in
  /// flight. Only the Play-screen `LifeAvatar` passes `true` — every other
  /// call site (Home avatar card, avatar picker tiles) keeps the default
  /// `false`, rendering exactly as before (flat fill top, no continuous
  /// ticking).
  final bool continuousWave;

  @override
  State<AvatarFigure> createState() => _AvatarFigureState();
}

class _AvatarFigureState extends State<AvatarFigure>
    with TickerProviderStateMixin {
  /// One full wave cycle (2π rad) every ~1.16s — derived from the approved
  /// mockup's per-frame phase increment (≈0.09 rad per 1/60s frame ≈ 5.4
  /// rad/s), converted into a controller-duration/`repeat()` setup instead
  /// of a hand-rolled per-frame increment so the rate stays frame-rate
  /// independent.
  static const Duration _kWaveCycleDuration = Duration(milliseconds: 1164);

  /// How long the fill-height easing controller takes to settle on a new
  /// [AvatarFigure.fillPercent] target, in the `continuousWave` path.
  static const Duration _kFillEaseDuration = Duration(milliseconds: 350);

  /// Base wave amplitude (logical px at the `_kUnitWidth`/104 painter
  /// scale) while no fill change is in flight.
  static const double _kBaseWaveAmplitude = 2.5;

  /// Extra amplitude added on top of [_kBaseWaveAmplitude] while the fill
  /// controller `isAnimating` (i.e. a life-change "slosh" is in flight).
  static const double _kBoostWaveAmplitude = 3.0;

  AnimationController? _waveController;
  AnimationController? _fillController;

  /// The fill-easing controller's current begin/end targets (0-100), reset
  /// on every real [AvatarFigure.fillPercent] change so the easing always
  /// starts from wherever the fill visually is right now, not from 0.
  double _fillBegin = 0;
  double _fillEnd = 0;

  @override
  void initState() {
    super.initState();
    _fillEnd = widget.fillPercent.clamp(0, 100).toDouble();
    _fillBegin = widget.continuousWave ? 0 : _fillEnd;
    if (widget.continuousWave) {
      _waveController = AnimationController(
        vsync: this,
        duration: _kWaveCycleDuration,
      );
      final fillController = AnimationController(
        vsync: this,
        duration: _kFillEaseDuration,
      );
      _fillController = fillController;
      if (widget.shouldAnimate) {
        fillController.forward(from: 0);
      } else {
        fillController.value = 1;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final waveController = _waveController;
    if (waveController == null) return;
    // Reduce Motion: the wave is passive/decorative, so it simply doesn't
    // run at all (amplitude is separately forced to 0 in `build`, covering
    // both "never started" and "was running, motion just got disabled").
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (waveController.isAnimating) waveController.stop();
    } else {
      if (!waveController.isAnimating) waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AvatarFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.continuousWave) return;
    if (widget.fillPercent == oldWidget.fillPercent) return;
    // Defensive (code-review #7): `_fillController` is always non-null here
    // in practice — every `continuousWave: true` call site keeps it `true`
    // for the widget's whole lifetime, so it's created once in `initState`
    // and never torn down before this — but guard rather than force-unwrap,
    // in case that invariant ever changes.
    final fillController = _fillController;
    if (fillController == null) return;
    _fillBegin = _currentFillValue();
    _fillEnd = widget.fillPercent.clamp(0, 100).toDouble();
    if (widget.shouldAnimate) {
      fillController.forward(from: 0);
    } else {
      fillController.value = 1;
    }
  }

  /// The fill-easing controller's current interpolated 0-100 value — used
  /// as the new tween's `begin` whenever [AvatarFigure.fillPercent] changes
  /// again mid-animation, so the "slosh" restarts from wherever the fill
  /// visually is right now rather than jumping.
  double _currentFillValue() {
    final controller = _fillController;
    if (controller == null) return _fillEnd;
    final eased = Curves.easeOut.transform(controller.value);
    return _fillBegin + (_fillEnd - _fillBegin) * eased;
  }

  @override
  void dispose() {
    _waveController?.dispose();
    _fillController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.fillPercent.clamp(0, 100);

    if (!widget.continuousWave) {
      if (!widget.shouldAnimate) {
        return CustomPaint(
          size: const Size(_kUnitWidth, _kUnitHeight),
          painter: _AvatarFigurePainter(
            spec: widget.spec,
            fillHeightPercent: target.toDouble(),
            fillColorPercent: target,
          ),
        );
      }
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: target.toDouble()),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return CustomPaint(
            size: const Size(_kUnitWidth, _kUnitHeight),
            painter: _AvatarFigurePainter(
              spec: widget.spec,
              fillHeightPercent: value,
              fillColorPercent: target,
            ),
          );
        },
      );
    }

    // Defensive (code-review #7): both controllers are always non-null here
    // in practice (see `didUpdateWidget`'s matching comment) — captured
    // into locals once, with a flat-fallback if that invariant ever broke,
    // rather than force-unwrapping the fields repeatedly below.
    final waveController = _waveController;
    final fillController = _fillController;
    if (waveController == null || fillController == null) {
      return CustomPaint(
        size: const Size(_kUnitWidth, _kUnitHeight),
        painter: _AvatarFigurePainter(
          spec: widget.spec,
          fillHeightPercent: target.toDouble(),
          fillColorPercent: target,
        ),
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: Listenable.merge([waveController, fillController]),
      builder: (context, child) {
        final fillValue = _currentFillValue();
        final amplitude = reduceMotion
            ? 0.0
            : _kBaseWaveAmplitude +
                  (fillController.isAnimating ? _kBoostWaveAmplitude : 0.0);
        final wavePhase = reduceMotion ? 0.0 : waveController.value * 2 * pi;
        return CustomPaint(
          size: const Size(_kUnitWidth, _kUnitHeight),
          painter: _AvatarFigurePainter(
            spec: widget.spec,
            fillHeightPercent: fillValue,
            fillColorPercent: target,
            continuousWave: true,
            wavePhase: wavePhase,
            waveAmplitude: amplitude,
          ),
        );
      },
    );
  }
}

/// Pure "sample the wavy fill top edge at one x, then clamp into the
/// vessel's own vertical bounds" calculation (juice spec effect 1,
/// code-review fix HIGH #1), extracted out of `_AvatarFigurePainter`'s
/// private `_wavyFillPath` so this file's single most safety-critical bit of
/// math — the fill silhouette must never fully disappear (near-death) or gap
/// at the top (near-full), regardless of wave amplitude/phase — is
/// unit-testable directly, without needing a full widget test. `shoulderY`/
/// `baseY`/`unitWidth` are passed in rather than hardcoded so this stays a
/// pure function of its inputs; production code always calls it with
/// `_AvatarFigurePainter`'s own `_shoulderY`/`_baseY`/`_kUnitWidth`.
@visibleForTesting
double avatarWaveYClamped({
  required double fillTop,
  required double waveAmplitude,
  required double wavePhase,
  required double x,
  required double unitWidth,
  required double shoulderY,
  required double baseY,
}) {
  final xOffset = (x / unitWidth) * 2 * pi;
  final wave =
      waveAmplitude * sin(wavePhase + xOffset) +
      (waveAmplitude * _AvatarFigurePainter._kSecondaryWaveAmplitudeRatio) *
          sin(
            wavePhase * _AvatarFigurePainter._kSecondaryWaveFrequencyRatio +
                xOffset * _AvatarFigurePainter._kSecondaryWaveSpatialRatio,
          );
  final y = fillTop + wave;
  return y.clamp(shoulderY, baseY);
}

class _AvatarFigurePainter extends CustomPainter {
  _AvatarFigurePainter({
    required this.spec,
    required this.fillHeightPercent,
    required this.fillColorPercent,
    this.continuousWave = false,
    this.wavePhase = 0,
    this.waveAmplitude = 0,
  });

  final AvatarSpec spec;

  /// The (possibly still-animating) 0-100 value driving the fill rect's
  /// height only.
  final double fillHeightPercent;

  /// The widget's final, non-animating target 0-100 value — the fill COLOR
  /// is always derived from this, never from [fillHeightPercent], so the
  /// color never sweeps through the low/mid bands while the height tween is
  /// still in flight (see `avatarFillColorForPercent`).
  final int fillColorPercent;

  /// Juice spec effect 1 (Play-screen `LifeAvatar` only): when `true`, the
  /// fill's top edge is a wavy `Path` (see [_paintBodyWavy]) instead of the
  /// flat `Rect` every other caller still gets via [_paintBody] — keeping
  /// that method byte-for-byte unchanged so Home/the avatar picker never
  /// regress.
  final bool continuousWave;

  /// Current wave phase, in radians. Only meaningful when [continuousWave]
  /// is `true`.
  final double wavePhase;

  /// Current wave amplitude, in logical px at the `_kUnitWidth` painter
  /// scale (0 under Reduce Motion — see `_AvatarFigureState.build`). Only
  /// meaningful when [continuousWave] is `true`.
  final double waveAmplitude;

  static const double _shoulderY = 60;
  static const double _baseY = 100;
  static const double _shoulderLeftX = 28;
  static const double _shoulderRightX = 56;
  static const double _baseLeftX = 22;
  static const double _baseRightX = 62;
  static const double _topCornerR = 8;
  static const double _bottomCornerR = 10;
  static const Offset _headCenter = Offset(42, 40);
  static const double _headRadius = 16;
  static const double _strokeWidth = 2.5;
  static const double _detailStrokeWidth = 1.5;

  /// Minimum rendered fill height, in the same 0-100 units as
  /// [fillHeightPercent] — a visual floor only, so a critical/near-death
  /// life% still shows a legible colored sliver instead of reading as an
  /// empty/white body.
  static const double _kMinVisibleFillPercent = 6;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kUnitWidth, size.height / _kUnitHeight);

    _paintBody(canvas);
    _paintNeck(canvas);
    _paintShirtCollar(canvas);
    _paintHead(canvas);
    _paintEyes(canvas);
    _paintMouth(canvas);
    _paintHair(canvas);

    canvas.restore();
  }

  Path _bodyPath() {
    return Path()
      ..moveTo(_shoulderLeftX, _shoulderY + _topCornerR)
      ..quadraticBezierTo(_shoulderLeftX, _shoulderY, _shoulderLeftX + _topCornerR, _shoulderY)
      ..lineTo(_shoulderRightX - _topCornerR, _shoulderY)
      ..quadraticBezierTo(_shoulderRightX, _shoulderY, _shoulderRightX, _shoulderY + _topCornerR)
      ..lineTo(_baseRightX, _baseY - _bottomCornerR)
      ..quadraticBezierTo(_baseRightX, _baseY, _baseRightX - _bottomCornerR, _baseY)
      ..lineTo(_baseLeftX + _bottomCornerR, _baseY)
      ..quadraticBezierTo(_baseLeftX, _baseY, _baseLeftX, _baseY - _bottomCornerR)
      ..lineTo(_shoulderLeftX, _shoulderY + _topCornerR)
      ..close();
  }

  void _paintBody(Canvas canvas) {
    final path = _bodyPath();

    // Base fill (the "empty" portion of the vessel), per §3.3.
    canvas.drawPath(path, Paint()..color = AppColors.paper);

    // Bottom-up life-meter fill, clipped to the vessel's own silhouette.
    // Floored at `_kMinVisibleFillPercent` so the critical/final-band case
    // (life near 0%) always shows a clearly visible colored sliver instead
    // of reading as empty/white — flagged independently by both the visual
    // sign-off pass and the player-reviewer gut-check on the Play Loop
    // avatar-life-meter revision. Geometry-only floor, does not touch the
    // color rule (still driven purely by `fillColorPercent`'s real value).
    final fillTop = _fillTop();
    canvas.save();
    canvas.clipPath(path);
    if (continuousWave) {
      canvas.drawPath(
        _wavyFillPath(fillTop),
        Paint()..color = avatarFillColorForPercent(fillColorPercent),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(0, fillTop, _kUnitWidth, _baseY + 1),
        Paint()..color = avatarFillColorForPercent(fillColorPercent),
      );
    }
    canvas.restore();

    // Outer silhouette stroke — same 2.5px weight as the head (§3.1 rule).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = AppColors.ink,
    );
  }

  double _fillTop() {
    final vesselHeight = _baseY - _shoulderY;
    final effectiveFillHeightPercent = fillHeightPercent < _kMinVisibleFillPercent
        ? _kMinVisibleFillPercent
        : fillHeightPercent;
    return _baseY - vesselHeight * (effectiveFillHeightPercent / 100);
  }

  /// Juice spec effect 1: the fill's top edge as an organic, non-repeating-
  /// looking wavy `Path` (two summed sines) rather than a flat line — built
  /// across the fill rect's width via `quadraticBezierTo` segments, then
  /// closed down to the vessel's base. Clipped to the same body silhouette
  /// as [_paintBody]'s flat-rect case, so only the geometry differs.
  static const int _kWaveSegments = 10;

  /// Secondary sine's amplitude, as a fraction of [waveAmplitude] — the
  /// smaller "ripple" summed on top of the primary wave for an organic,
  /// non-repeating-looking surface (code-review fix: named, not inline).
  static const double _kSecondaryWaveAmplitudeRatio = 0.4;

  /// Secondary sine's phase-speed multiplier relative to [wavePhase].
  static const double _kSecondaryWaveFrequencyRatio = 1.7;

  /// Secondary sine's spatial-frequency multiplier relative to the primary
  /// sine's per-x phase offset.
  static const double _kSecondaryWaveSpatialRatio = 1.3;

  Path _wavyFillPath(double fillTop) {
    double waveY(double x) => avatarWaveYClamped(
      fillTop: fillTop,
      waveAmplitude: waveAmplitude,
      wavePhase: wavePhase,
      x: x,
      unitWidth: _kUnitWidth,
      shoulderY: _shoulderY,
      baseY: _baseY,
    );

    final path = Path()..moveTo(0, waveY(0));
    for (var i = 1; i <= _kWaveSegments; i++) {
      final x = _kUnitWidth * i / _kWaveSegments;
      final prevX = _kUnitWidth * (i - 1) / _kWaveSegments;
      final midX = (prevX + x) / 2;
      path.quadraticBezierTo(midX, waveY(midX), x, waveY(x));
    }
    path
      ..lineTo(_kUnitWidth, _baseY + 1)
      ..lineTo(0, _baseY + 1)
      ..close();
    return path;
  }

  void _paintNeck(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(37, 52, 10, 8),
      Paint()..color = spec.skin,
    );
  }

  void _paintShirtCollar(Canvas canvas) {
    final path = Path()
      ..moveTo(_shoulderLeftX + 4, _shoulderY + 2)
      ..quadraticBezierTo(42, _shoulderY + 6, _shoulderRightX - 4, _shoulderY + 2);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _detailStrokeWidth
        ..color = spec.shirt,
    );
  }

  void _paintHead(Canvas canvas) {
    canvas.drawCircle(_headCenter, _headRadius, Paint()..color = spec.skin);
    canvas.drawCircle(
      _headCenter,
      _headRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = AppColors.ink,
    );
  }

  void _paintEyes(Canvas canvas) {
    final paint = Paint()..color = AppColors.ink;
    canvas.drawCircle(const Offset(36, 38), 2, paint);
    canvas.drawCircle(const Offset(48, 38), 2, paint);
  }

  void _paintMouth(Canvas canvas) {
    final path = Path()
      ..moveTo(36, 45)
      ..quadraticBezierTo(42, 49, 48, 45);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _detailStrokeWidth
        ..color = AppColors.ink,
    );
  }

  void _paintHair(Canvas canvas) {
    canvas.drawPath(_hairPath(spec.hair), Paint()..color = spec.hairColor);
    if (spec.hair == AvatarHair.curlyWithBow) {
      _paintBow(canvas);
    }
  }

  /// The `curlyWithBow` hairstyle's distinguishing bow. Drawn as its own
  /// small ribbon shape (two wings + a center knot) well clear of the curl
  /// union — the last curl is centered `(54, 23)` radius `8`, so every point
  /// of this bow (centered `(66, 14)`, wings extending ±5) is >8 units away,
  /// guaranteeing no overlap. Filled `paper`/stroked `ink` (not `hairColor`)
  /// so it always reads as a distinct shape regardless of which hair color
  /// it's paired with, rather than an indistinguishable same-color blob —
  /// this is what actually differentiates this style from `curlyRound`.
  void _paintBow(Canvas canvas) {
    const Offset center = Offset(66, 14);
    const double wingHalfWidth = 5;
    const double wingHalfHeight = 2.5;
    const double knotRadius = 2;

    final path = Path()
      // Left wing.
      ..moveTo(center.dx - wingHalfWidth, center.dy - wingHalfHeight)
      ..lineTo(center.dx - 0.5, center.dy)
      ..lineTo(center.dx - wingHalfWidth, center.dy + wingHalfHeight)
      ..close()
      // Right wing.
      ..moveTo(center.dx + wingHalfWidth, center.dy - wingHalfHeight)
      ..lineTo(center.dx + 0.5, center.dy)
      ..lineTo(center.dx + wingHalfWidth, center.dy + wingHalfHeight)
      ..close()
      ..addOval(Rect.fromCircle(center: center, radius: knotRadius));

    canvas.drawPath(path, Paint()..color = AppColors.paper);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _detailStrokeWidth
        ..color = AppColors.ink,
    );
  }

  static Path _hairPath(AvatarHair hair) {
    switch (hair) {
      case AvatarHair.sweptBack:
        return Path()
          ..moveTo(26, 34)
          ..quadraticBezierTo(28, 18, 48, 18)
          ..quadraticBezierTo(60, 19, 58, 32)
          ..quadraticBezierTo(48, 22, 34, 27)
          ..quadraticBezierTo(28, 29, 26, 34)
          ..close();

      case AvatarHair.sidePart:
        return Path()
          ..moveTo(25, 36)
          ..quadraticBezierTo(26, 19, 41, 18)
          ..lineTo(45, 20)
          ..quadraticBezierTo(52, 19, 59, 34)
          ..quadraticBezierTo(50, 25, 40, 25)
          ..quadraticBezierTo(30, 25, 25, 36)
          ..close();

      case AvatarHair.spiky:
        {
          final path = Path()..moveTo(24, 33);
          const tipXs = [28.0, 34.0, 40.0, 46.0, 52.0, 58.0];
          var up = true;
          for (final x in tipXs) {
            path.lineTo(x, up ? 14 : 26);
            up = !up;
          }
          path
            ..lineTo(60, 33)
            ..quadraticBezierTo(42, 40, 24, 33)
            ..close();
          return path;
        }

      case AvatarHair.curlyRound:
        {
          final path = Path();
          for (final cx in [30.0, 38.0, 46.0, 54.0]) {
            path.addOval(Rect.fromCircle(center: Offset(cx, 24), radius: 8));
          }
          return path;
        }

      case AvatarHair.wavySide:
        return Path()
          ..moveTo(26, 30)
          ..quadraticBezierTo(24, 19, 40, 18)
          ..quadraticBezierTo(56, 19, 58, 32)
          ..quadraticBezierTo(60, 42, 55, 50)
          ..quadraticBezierTo(58, 40, 50, 34)
          ..quadraticBezierTo(40, 40, 30, 34)
          ..quadraticBezierTo(24, 34, 26, 30)
          ..close();

      case AvatarHair.buzzcut:
        return Path()
          ..moveTo(28, 30)
          ..quadraticBezierTo(30, 19, 42, 19)
          ..quadraticBezierTo(54, 19, 56, 30)
          ..quadraticBezierTo(42, 23, 28, 30)
          ..close();

      case AvatarHair.longFlowingSplit:
        return Path()
          ..moveTo(22, 32)
          ..quadraticBezierTo(24, 18, 40, 17)
          ..lineTo(40, 21)
          ..quadraticBezierTo(30, 23, 26, 34)
          ..quadraticBezierTo(21, 46, 24, 58)
          ..quadraticBezierTo(18, 46, 22, 32)
          ..close()
          ..moveTo(62, 32)
          ..quadraticBezierTo(60, 18, 44, 17)
          ..lineTo(44, 21)
          ..quadraticBezierTo(54, 23, 58, 34)
          ..quadraticBezierTo(63, 46, 60, 58)
          ..quadraticBezierTo(66, 46, 62, 32)
          ..close();

      case AvatarHair.bobWithPart:
        return Path()
          ..moveTo(24, 34)
          ..quadraticBezierTo(24, 18, 42, 17)
          ..quadraticBezierTo(60, 18, 60, 34)
          ..quadraticBezierTo(60, 46, 56, 52)
          ..quadraticBezierTo(58, 42, 54, 34)
          ..quadraticBezierTo(48, 25, 42, 25)
          ..quadraticBezierTo(36, 25, 30, 34)
          ..quadraticBezierTo(26, 42, 28, 52)
          ..quadraticBezierTo(24, 46, 24, 34)
          ..close();

      case AvatarHair.curlyWithBow:
        {
          // The bow itself is painted separately by `_paintBow` (in a
          // contrasting `paper`/`ink` treatment, not `hairColor`) — see the
          // call site in `_paintHair` below. Kept as its own case (rather
          // than falling through to `curlyRound`) so the two remain
          // independently editable even though the curl silhouette is
          // currently identical.
          final path = Path();
          for (final cx in [30.0, 38.0, 46.0, 54.0]) {
            path.addOval(Rect.fromCircle(center: Offset(cx, 23), radius: 8));
          }
          return path;
        }

      case AvatarHair.pigtails:
        {
          final path = Path()
            ..moveTo(27, 32)
            ..quadraticBezierTo(28, 19, 42, 18)
            ..quadraticBezierTo(56, 19, 57, 32)
            ..quadraticBezierTo(42, 25, 27, 32)
            ..close();
          path.addOval(Rect.fromCircle(center: const Offset(21, 38), radius: 6));
          path.addOval(Rect.fromCircle(center: const Offset(63, 38), radius: 6));
          return path;
        }

      case AvatarHair.longStraightCenter:
        return Path()
          ..moveTo(25, 30)
          ..quadraticBezierTo(26, 18, 42, 17)
          ..quadraticBezierTo(58, 18, 59, 30)
          ..lineTo(59, 58)
          ..lineTo(54, 58)
          ..lineTo(54, 34)
          ..quadraticBezierTo(48, 25, 42, 25)
          ..quadraticBezierTo(36, 25, 30, 34)
          ..lineTo(30, 58)
          ..lineTo(25, 58)
          ..close();

      case AvatarHair.shortBobCurlUnder:
        return Path()
          ..moveTo(25, 32)
          ..quadraticBezierTo(26, 18, 42, 17)
          ..quadraticBezierTo(58, 18, 59, 32)
          ..quadraticBezierTo(59, 42, 52, 46)
          ..quadraticBezierTo(58, 44, 56, 36)
          ..quadraticBezierTo(48, 26, 42, 26)
          ..quadraticBezierTo(36, 26, 28, 36)
          ..quadraticBezierTo(26, 44, 32, 46)
          ..quadraticBezierTo(25, 42, 25, 32)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarFigurePainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.fillHeightPercent != fillHeightPercent ||
        oldDelegate.fillColorPercent != fillColorPercent ||
        oldDelegate.continuousWave != continuousWave ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.waveAmplitude != waveAmplitude;
  }
}
