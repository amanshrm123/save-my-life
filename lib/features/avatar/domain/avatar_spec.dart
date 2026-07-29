import 'package:flutter/painting.dart' show Color;

/// The two avatar genders (design `home-avatars-v1.md` §4) — `id` math is
/// `gender.index * 6 + variant`, so [male] must stay index 0 / [female]
/// index 1.
enum AvatarGender { male, female }

/// The 12 distinct hair silhouettes the `AvatarFigure` painter knows how to
/// draw (design `home-avatars-v1.md` §3.1/§4) — one enum shared by both
/// genders, since the painter's `switch` only cares about the shape, not who
/// wears it.
enum AvatarHair {
  sweptBack,
  sidePart,
  spiky,
  curlyRound,
  wavySide,
  buzzcut,
  longFlowingSplit,
  bobWithPart,
  curlyWithBow,
  pigtails,
  longStraightCenter,
  shortBobCurlUnder,
}

/// One catalog entry (design `home-avatars-v1.md` §4): a fixed combination
/// of gender, hair shape, and the three content colors the `AvatarFigure`
/// painter fills in with. Catalog content only — not a theme token, and not
/// user-mutable (the player picks *among* these 12, never edits one).
class AvatarSpec {
  const AvatarSpec({
    required this.id,
    required this.gender,
    required this.variant,
    required this.hair,
    required this.skin,
    required this.hairColor,
    required this.shirt,
  });

  /// `gender.index * 6 + variant` — male ids 0-5, female ids 6-11 (§4.1).
  final int id;
  final AvatarGender gender;

  /// 0-5 within [gender]; also the palette index into the skin/hair-color
  /// tables and that gender's own shirt-color table (§4.1).
  final int variant;

  final AvatarHair hair;
  final Color skin;
  final Color hairColor;
  final Color shirt;
}
