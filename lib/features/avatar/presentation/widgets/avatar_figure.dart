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
/// `AnimationController` — nothing here needs an explicit `dispose()`, and
/// the animation only ever runs while this widget is actually built/mounted.
class AvatarFigure extends StatelessWidget {
  const AvatarFigure({
    super.key,
    required this.spec,
    required this.fillPercent,
    this.shouldAnimate = true,
  });

  final AvatarSpec spec;

  /// 0-100. Clamped defensively; callers (`HomeAvatarCard`/`AvatarTile`)
  /// already only ever pass in-range values.
  final int fillPercent;

  /// Whether the bottom-up fill height should animate towards [fillPercent]
  /// via the implicit `TweenAnimationBuilder`, or snap straight to it with no
  /// interpolation. Home threads its own `RouteAware` visibility signal in
  /// here (see `_HomeScreenState`): the tween must not run while Home sits
  /// mounted-but-offscreen (behind Play/Outcome), since it would silently
  /// finish before the player ever sees it, replacing the intended animated
  /// fill change with a snap once Home becomes visible again.
  final bool shouldAnimate;

  @override
  Widget build(BuildContext context) {
    final target = fillPercent.clamp(0, 100);
    if (!shouldAnimate) {
      return CustomPaint(
        size: const Size(_kUnitWidth, _kUnitHeight),
        painter: _AvatarFigurePainter(
          spec: spec,
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
            spec: spec,
            fillHeightPercent: value,
            fillColorPercent: target,
          ),
        );
      },
    );
  }
}

class _AvatarFigurePainter extends CustomPainter {
  _AvatarFigurePainter({
    required this.spec,
    required this.fillHeightPercent,
    required this.fillColorPercent,
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
    final vesselHeight = _baseY - _shoulderY;
    final effectiveFillHeightPercent = fillHeightPercent < _kMinVisibleFillPercent
        ? _kMinVisibleFillPercent
        : fillHeightPercent;
    final fillTop = _baseY - vesselHeight * (effectiveFillHeightPercent / 100);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTRB(0, fillTop, _kUnitWidth, _baseY + 1),
      Paint()..color = avatarFillColorForPercent(fillColorPercent),
    );
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
        oldDelegate.fillColorPercent != fillColorPercent;
  }
}
