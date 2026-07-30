import 'package:flutter/painting.dart' show Color;

import 'avatar_spec.dart';

// --- Catalog content colors (design `home-avatars-v1.md` §4) — deliberately
// NOT added to `AppColors`: these are avatar-catalog *content*, not app theme
// tokens, and are only ever referenced from this file.

// Skin tones, cycled by variant index (0-5).
const Color _skinPorcelain = Color(0xFFFFE0C4);
const Color _skinFair = Color(0xFFF5C99B);
const Color _skinTan = Color(0xFFD9A066);
const Color _skinDeepTan = Color(0xFFB87A45);
const Color _skinBrown = Color(0xFF8B5A2B);
const Color _skinDeepBrown = Color(0xFF5C3A1E);

// Hair colors, cycled by variant index (0-5).
const Color _hairJetBlack = Color(0xFF2B2420);
const Color _hairChestnut = Color(0xFF5A3825);
const Color _hairAuburn = Color(0xFF8B4A2B);
const Color _hairHoneyBlonde = Color(0xFFD9A94F);
const Color _hairPlatinum = Color(0xFFE8DCC8);
const Color _hairSlateGray = Color(0xFF8A8F94);

// Shirt colors — male palette, by variant index (0-5).
const Color _shirtMaleBlue = Color(0xFF4A9FD8);
const Color _shirtMaleLeafGreen = Color(0xFF5FA867);
const Color _shirtMaleRust = Color(0xFFC97B4A);
const Color _shirtMaleIndigo = Color(0xFF7B6FC9);
const Color _shirtMaleDeepTeal = Color(0xFF3F5651);
const Color _shirtMaleBrick = Color(0xFFB84A5C);

// Shirt colors — female palette, by variant index (0-5).
const Color _shirtFemaleRose = Color(0xFFE58BA0);
const Color _shirtFemaleAqua = Color(0xFF8AC9C4);
const Color _shirtFemaleOrchid = Color(0xFFD9A5D0);
const Color _shirtFemaleMustard = Color(0xFFE5B95C);
const Color _shirtFemaleSage = Color(0xFF6FA88A);
const Color _shirtFemaleMauve = Color(0xFFC97BA0);

// --- The 12 canonical specs (design `home-avatars-v1.md` §4.1). Each is a
// standalone top-level `const` (not built by indexing into the palette lists
// above) so `kAvatars` stays a genuinely compile-time-canonicalized const
// list — no runtime allocation, no JSON/asset loading.

const AvatarSpec _maleSweptBack = AvatarSpec(
  id: 0,
  gender: AvatarGender.male,
  variant: 0,
  hair: AvatarHair.sweptBack,
  skin: _skinPorcelain,
  hairColor: _hairJetBlack,
  shirt: _shirtMaleBlue,
);

const AvatarSpec _maleSidePart = AvatarSpec(
  id: 1,
  gender: AvatarGender.male,
  variant: 1,
  hair: AvatarHair.sidePart,
  skin: _skinFair,
  hairColor: _hairChestnut,
  shirt: _shirtMaleLeafGreen,
);

const AvatarSpec _maleSpiky = AvatarSpec(
  id: 2,
  gender: AvatarGender.male,
  variant: 2,
  hair: AvatarHair.spiky,
  skin: _skinTan,
  hairColor: _hairAuburn,
  shirt: _shirtMaleRust,
);

const AvatarSpec _maleCurlyRound = AvatarSpec(
  id: 3,
  gender: AvatarGender.male,
  variant: 3,
  hair: AvatarHair.curlyRound,
  skin: _skinDeepTan,
  hairColor: _hairHoneyBlonde,
  shirt: _shirtMaleIndigo,
);

const AvatarSpec _maleWavySide = AvatarSpec(
  id: 4,
  gender: AvatarGender.male,
  variant: 4,
  hair: AvatarHair.wavySide,
  skin: _skinBrown,
  hairColor: _hairPlatinum,
  shirt: _shirtMaleDeepTeal,
);

const AvatarSpec _maleBuzzcut = AvatarSpec(
  id: 5,
  gender: AvatarGender.male,
  variant: 5,
  hair: AvatarHair.buzzcut,
  skin: _skinDeepBrown,
  hairColor: _hairSlateGray,
  shirt: _shirtMaleBrick,
);

const AvatarSpec _femaleLongFlowingSplit = AvatarSpec(
  id: 6,
  gender: AvatarGender.female,
  variant: 0,
  hair: AvatarHair.longFlowingSplit,
  skin: _skinPorcelain,
  hairColor: _hairJetBlack,
  shirt: _shirtFemaleRose,
);

const AvatarSpec _femaleBobWithPart = AvatarSpec(
  id: 7,
  gender: AvatarGender.female,
  variant: 1,
  hair: AvatarHair.bobWithPart,
  skin: _skinFair,
  hairColor: _hairChestnut,
  shirt: _shirtFemaleAqua,
);

const AvatarSpec _femaleCurlyWithBow = AvatarSpec(
  id: 8,
  gender: AvatarGender.female,
  variant: 2,
  hair: AvatarHair.curlyWithBow,
  skin: _skinTan,
  hairColor: _hairAuburn,
  shirt: _shirtFemaleOrchid,
);

const AvatarSpec _femalePigtails = AvatarSpec(
  id: 9,
  gender: AvatarGender.female,
  variant: 3,
  hair: AvatarHair.pigtails,
  skin: _skinDeepTan,
  hairColor: _hairHoneyBlonde,
  shirt: _shirtFemaleMustard,
);

const AvatarSpec _femaleLongStraightCenter = AvatarSpec(
  id: 10,
  gender: AvatarGender.female,
  variant: 4,
  hair: AvatarHair.longStraightCenter,
  skin: _skinBrown,
  hairColor: _hairPlatinum,
  shirt: _shirtFemaleSage,
);

const AvatarSpec _femaleShortBobCurlUnder = AvatarSpec(
  id: 11,
  gender: AvatarGender.female,
  variant: 5,
  hair: AvatarHair.shortBobCurlUnder,
  skin: _skinDeepBrown,
  hairColor: _hairSlateGray,
  shirt: _shirtFemaleMauve,
);

/// All 12 catalog entries, id-ascending (`kAvatars[i].id == i` by
/// construction) — a plain compile-time `const List`, never built/loaded at
/// runtime.
const List<AvatarSpec> kAvatars = [
  _maleSweptBack,
  _maleSidePart,
  _maleSpiky,
  _maleCurlyRound,
  _maleWavySide,
  _maleBuzzcut,
  _femaleLongFlowingSplit,
  _femaleBobWithPart,
  _femaleCurlyWithBow,
  _femalePigtails,
  _femaleLongStraightCenter,
  _femaleShortBobCurlUnder,
];

/// Pure lookup helpers over [kAvatars] — no state, no I/O.
class AvatarCatalog {
  const AvatarCatalog._();

  /// The documented fallback (design §4.1): id 0, `sweptBack`/Porcelain/
  /// Jet-black/blue-shirt male. Used for a never-picked player (`avatar_id
  /// == -1`) and as the picker's own pre-selection default.
  static const AvatarSpec fallback = _maleSweptBack;

  /// Looks up a catalog entry by id, falling back to [fallback] for any id
  /// outside the valid `0-11` range (including the never-picked sentinel,
  /// `-1`) rather than throwing.
  static AvatarSpec byId(int id) {
    if (id < 0 || id >= kAvatars.length) return fallback;
    return kAvatars[id];
  }

  /// The 6 entries for [gender], in variant order (0-5) — used to populate
  /// the picker's grid for whichever gender tab is active.
  static List<AvatarSpec> forGender(AvatarGender gender) {
    return kAvatars.where((spec) => spec.gender == gender).toList(growable: false);
  }
}
