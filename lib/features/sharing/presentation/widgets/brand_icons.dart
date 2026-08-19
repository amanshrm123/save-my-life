import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/share_target.dart';

/// Brand glyphs for the 3 share tiles (design share-target-sheet-v1 §1/§11
/// checklist item 6, architecture §12 play-store-specialist flag 5).
///
/// Facebook and WhatsApp now use the real, officially-licensed assets
/// (`assets/brand/facebook.png`, `assets/brand/whatsapp.svg`), downloaded
/// directly from Meta's own Brand Resource Center
/// (meta.com/brand/resources/facebook/logo,
/// meta.com/brand/resources/whatsapp/whatsapp-brand) after accepting their
/// brand usage terms — that login/acceptance step is a business decision
/// for whoever owns the linked account, so it isn't something done
/// unattended here; the files themselves were handed over afterward.
/// Facebook's pack only shipped `.ai`/`.png` (no `.svg`), hence it's the
/// one raster asset in this otherwise-vector set — at 2084×2084 it's far
/// larger than this tile ever renders at, so there's no visible quality
/// cost. Instagram's `assets/brand/instagram.svg` is still the interim
/// Simple Icons (github.com/simple-icons/simple-icons, MIT-licensed)
/// reproduction pending the same treatment — swap that file in once
/// obtained, no code change needed here.
///
/// Rendered via `flutter_svg`/`Image.asset`, not hand-parsed `Path` data —
/// still zero `ImageCache` churn in the app's own dynamic-content sense
/// (these are 3 fixed, tiny, static assets, not the many-variant procedural
/// content this app's RAM-resident design principle is actually about).
///
/// Each brand's glyph has a genuinely different native shape, verified by
/// rendering standalone (macOS Quick Look, independent of both
/// `flutter_svg` and an earlier abandoned `path_drawing` attempt) rather
/// than assumed: Facebook's asset already IS a solid disc with a white "f"
/// baked in, self-contained, no tinting needed. WhatsApp's official glyph
/// is pure line-art (an outline phone-in-a-speech-bubble, no fill/
/// background of its own — this is Meta's actual intended presentation for
/// this asset, not a rendering bug), so it gets an explicit solid-green
/// circular backing drawn behind it here, tinted white on top, matching the
/// real WhatsApp app icon's look. Instagram's Simple Icons glyph is the
/// same kind of line-art, hence the same treatment with a gradient backing
/// instead (Instagram's real icon has no single flat brand color).
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

/// Meta's official Facebook logo asset (`Logo/Primary Logo` from the
/// downloaded Brand Asset Pack) is already the complete "solid blue disc,
/// white f" mark, baked into the PNG itself with a transparent surround —
/// rendered as-is, no tinting/backing shape needed.
class _FacebookGlyph extends StatelessWidget {
  const _FacebookGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/facebook.png',
      width: size,
      height: size,
    );
  }
}

/// WhatsApp's official glyph (Meta Brand Resource Center's "Digital Glyph,
/// Green, RGB" export) is pure line-art (an outline phone-in-a-speech-
/// bubble, no fill/background of its own — confirmed against a standalone
/// render, this is Meta's actual intended presentation for this specific
/// asset, not a rendering bug), unlike Facebook's self-contained PNG
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
