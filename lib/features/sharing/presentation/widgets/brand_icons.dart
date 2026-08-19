import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/share_target.dart';

/// Brand glyphs for the 3 share tiles (design share-target-sheet-v1 §1/§11
/// checklist item 6, architecture §12 play-store-specialist flag 5).
///
/// The SVGs under `assets/brand/` are sourced verbatim from Simple Icons
/// (github.com/simple-icons/simple-icons, MIT-licensed markup,
/// `develop/icons/{instagram,facebook,whatsapp}.svg`) — a pixel-accurate
/// reproduction of each brand's current public glyph, the same source
/// thousands of production apps use for exactly this "share to X" button
/// case. This is NOT the same thing as Meta's/WhatsApp's own officially
/// *licensed* asset from their Brand Resource Center: obtaining those
/// requires logging into a Meta/WhatsApp-linked account and accepting their
/// brand usage terms on the app's behalf, which is a business decision for
/// whoever owns that account, not something to do unattended here. If/when
/// the official assets are obtained, swap the files under `assets/brand/`
/// for the licensed ones — this widget's structure (a colored backing shape
/// plus an `SvgPicture.asset` on top) doesn't need to change.
///
/// Rendered via `flutter_svg`, not hand-parsed `Path` data — zero
/// `Image`/`ImageCache` entries in the app's own sense (these are vector,
/// not raster, assets), consistent with this app's RAM-resident design.
///
/// Each brand's Simple Icons glyph has a genuinely different native shape,
/// verified by rendering the raw SVGs standalone (macOS Quick Look, a
/// renderer independent of both this app's `flutter_svg` and an earlier
/// abandoned `path_drawing` attempt) rather than assumed: Facebook's path
/// already IS a solid disc with a white "f" cut into it via the path's own
/// winding, so a single tinted `SvgPicture` reproduces the real two-tone
/// mark directly. Instagram's and WhatsApp's paths are pure line-art (an
/// outline camera glyph / an outline phone-in-bubble glyph, each with no
/// fill of their own) — confirmed intentional, not a rendering bug — so
/// both get an explicit colored backing shape drawn behind them here,
/// matching each brand's real app-icon silhouette (Instagram: rounded
/// square; WhatsApp: circle, same as Facebook's).
Widget brandGlyphFor(ShareTarget target, {double size = 40}) {
  switch (target) {
    case ShareTarget.instagramStory:
      return _InstagramGlyph(size: size);
    case ShareTarget.whatsappStatus:
      return _WhatsAppGlyph(size: size);
    case ShareTarget.facebookStory:
      return _FacebookGlyph(size: size);
  }
}

/// WhatsApp's current brand green.
const Color _whatsAppGreen = Color(0xFF25D366);

/// Facebook's current brand blue (Meta's 2021 refresh, `#0866FF` — updated
/// from the older `#1877F2`).
const Color _facebookBlue = Color(0xFF0866FF);

/// Facebook's Simple Icons path already encodes its own "solid disc with a
/// white glyph cutout" shape via the path's own winding — a single tinted
/// `SvgPicture` reproduces the real two-tone mark directly, no separate
/// background layer needed.
class _FacebookGlyph extends StatelessWidget {
  const _FacebookGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/facebook.svg',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(_facebookBlue, BlendMode.srcIn),
    );
  }
}

/// WhatsApp's Simple Icons glyph is pure line-art (an outline phone-in-a-
/// speech-bubble, no fill of its own — confirmed against a standalone
/// render, not a rendering bug), unlike Facebook's self-contained path
/// above — so it needs an explicit solid-green circular backing (matching
/// the real WhatsApp app icon's circular shape) with the glyph tinted
/// white on top, the same two-layer treatment [_InstagramGlyph] below uses.
class _WhatsAppGlyph extends StatelessWidget {
  const _WhatsAppGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: _whatsAppGreen, shape: BoxShape.circle),
      padding: EdgeInsets.all(size * 0.16),
      child: SvgPicture.asset(
        'assets/brand/whatsapp.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}

/// Instagram's real gradient (matches Meta's own published Instagram icon
/// gradient family) with the accurate Simple Icons glyph on top — a
/// square-ring outline + camera-lens ring + flash dot, all line-art with no
/// fill of its own (same reasoning as [_WhatsAppGlyph] above) — tinted
/// white. A flat single color can't represent a gradient, so this
/// background is drawn explicitly rather than baked into the SVG.
class _InstagramGlyph extends StatelessWidget {
  const _InstagramGlyph({required this.size});

  final double size;

  static const List<Color> _gradientColors = [
    Color(0xFFFEDA75),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: SvgPicture.asset(
        'assets/brand/instagram.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}
