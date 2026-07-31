import 'package:flutter/material.dart';

import '../../domain/share_target.dart';

/// PLACEHOLDER brand glyphs — pending replacement (design
/// share-target-sheet-v1 §1/§11 checklist item 6, architecture §12
/// play-store-specialist flag 5).
///
/// These are NOT Instagram/WhatsApp/Facebook's official brand assets. Real
/// official brand assets require manually downloading each platform's own
/// licensed vector from its brand resource center (Meta Brand Resource
/// Center for Instagram/Facebook, WhatsApp Brand Center) under that
/// platform's usage terms — not something to fetch/scrape automatically.
/// Built instead as simple, recognizable, brand-colored `CustomPainter`
/// glyphs, the same hand-built-painter approach this codebase already uses
/// for `AvatarFigure` (zero image assets, zero `ImageCache` entries) rather
/// than a generic Material-icon substitute (rejected by the design doc —
/// wrong/absent brand color, inconsistent stroke style, reads as an
/// unfinished "cheap knockoff" picker).
///
/// MUST be swapped for each platform's real official brand asset (correct
/// color, minimum clear-space, no implied endorsement) before store
/// submission — flagged explicitly for app-store-specialist/
/// play-store-specialist sign-off, not something this pass silently ships
/// as final art.
CustomPainter brandGlyphPainterFor(ShareTarget target) {
  switch (target) {
    case ShareTarget.instagramStory:
      return const InstagramGlyphPainter();
    case ShareTarget.whatsappStatus:
      return const WhatsAppGlyphPainter();
    case ShareTarget.facebookStory:
      return const FacebookGlyphPainter();
  }
}

/// Simplified gradient-camera silhouette placeholder — Instagram's real mark
/// is a specific licensed vector; this approximates its rounded-square +
/// lens-ring + flash-dot shape and gradient family only.
class InstagramGlyphPainter extends CustomPainter {
  const InstagramGlyphPainter();

  static const List<Color> _gradientColors = [
    Color(0xFFFEDA75),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.3));
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _gradientColors,
      ).createShader(rect);
    canvas.drawRRect(rrect, gradientPaint);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width * 0.24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.74, size.height * 0.26),
      size.width * 0.045,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant InstagramGlyphPainter oldDelegate) => false;
}

/// Simplified green speech-bubble/handset placeholder — WhatsApp's real mark
/// is a specific licensed vector; this approximates only its brand green
/// circular fill plus a white receiver-shaped glyph.
class WhatsAppGlyphPainter extends CustomPainter {
  const WhatsAppGlyphPainter();

  static const Color _whatsAppGreen = Color(0xFF25D366);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, Paint()..color = _whatsAppGreen);

    final glyphRadius = size.width * 0.16;
    final topLeft = Offset(size.width * 0.34, size.height * 0.36);
    final bottomRight = Offset(size.width * 0.66, size.height * 0.64);
    final path = Path()
      ..addOval(Rect.fromCircle(center: topLeft, radius: glyphRadius))
      ..addOval(Rect.fromCircle(center: bottomRight, radius: glyphRadius))
      ..addRect(Rect.fromPoints(topLeft, bottomRight));
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant WhatsAppGlyphPainter oldDelegate) => false;
}

/// Simplified blue rounded-square + white "f" placeholder — Facebook's real
/// mark is a specific licensed vector; this approximates only its brand
/// blue and the "f" silhouette.
class FacebookGlyphPainter extends CustomPainter {
  const FacebookGlyphPainter();

  static const Color _facebookBlue = Color(0xFF1877F2);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.22));
    canvas.drawRRect(rrect, Paint()..color = _facebookBlue);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'f',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.72,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 - size.height * 0.03,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant FacebookGlyphPainter oldDelegate) => false;
}
