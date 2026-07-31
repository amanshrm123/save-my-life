import 'package:flutter/material.dart';

/// Color palette lifted verbatim from the mockup's `:root` custom properties
/// (design spec v1 §0/§1.1). Keep the three cool grays distinct — they are
/// easy to typo-merge but serve different roles.
class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFFC8ECD9);
  static const Color ink = Color(0xFF1F2A2E);
  static const Color paper = Color(0xFFFFFDF7);
  static const Color paper2 = Color(0xFFF2EFE6);

  static const Color coral = Color(0xFFFF7A59);
  static const Color coralDark = Color(0xFFE5613F);

  static const Color green = Color(0xFF2FBF71);
  static const Color greenDark = Color(0xFF1F9C58);

  static const Color red = Color(0xFFF0483E);

  /// "Red-dark" companion to [red] — the final-band STOP button's label
  /// text-shadow (`0 1.5px 0 #b8362e`). Not present in the mockup's `:root`
  /// unlike its siblings (`coralDark`/`greenDark`/`goldDark`); promoted to a
  /// real token here per design spec v1 §1.2 rather than left as a magic hex.
  static const Color redDark = Color(0xFFB8362E);

  static const Color gold = Color(0xFFFFC23C);
  static const Color goldDark = Color(0xFFE5A516);

  /// Helper row / char counter / disabled-secondary text.
  static const Color mute = Color(0xFF7B8A86);

  /// Tagline / description paragraph under every headline. Distinct from
  /// [mute] despite both being cool grays — do not collapse them.
  static const Color bodyMute = Color(0xFF4A5F5A);

  /// Inactive page-dot fill. Distinct from [mute] and [bodyMute].
  static const Color dotInactive = Color(0xFFA7C4B8);

  /// The 4th gray (Play Loop design spec v1 §1.1) — the life-bar meta
  /// caption ("Life 47%") baseline color. Distinct from [mute] (used for
  /// the "Target" reminder) and [bodyMute] (countdown/pause body copy) —
  /// don't collapse into either.
  static const Color hudMute = Color(0xFF3F5651);

  static const Color blue = Color(0xFF4A9FD8);

  /// Positive/neutral "note" chip text color (design v3 §1.1/§1.3) — the
  /// streak-broken hint (6.3). A genuine 5th gray, distinct from [mute]/
  /// [bodyMute]/[dotInactive]/[hudMute].
  static const Color noteText = Color(0xFF5C6F6A);

  /// Positive/neutral note-chip background (design v3 §1.3).
  static const Color noteBg = Color(0xFFDBEEE4);

  /// Error note-chip background — pinned exactly by design v3 §1.3 (reused
  /// as-is from onboarding's inline name-rejection treatment).
  static const Color errorNoteBg = Color(0xFFFDE3E3);

  /// Eternal outcome-cardbox's catalog-line + `stayalive.app` mark color
  /// (design v3 §1.2) — overrides the default tier color on the solid-gold
  /// fill (dark/low-saturation, matching the ARM plate's contrast rule).
  ///
  /// Retired from the story-card's name-span role by design v1 Revision 2
  /// §R2.4: post-0.85-alpha-blend contrast for that role measured only
  /// ~3.5:1 (below AA), which [eternalNameSpan] fixes. Left defined and
  /// unused here, not deleted, per this file's "don't repurpose/collapse a
  /// named token" convention — it may still gain a future non-name-span use.
  static const Color eternalNo = Color(0xFF8A5A00);

  /// Ad-chrome palette (design v3 §1.4) — deliberately off-palette, used
  /// only by the two full ad screens (5.1/5.3) so they read as "someone
  /// else's UI," never reused elsewhere in the app.
  static const Color adBg = Color(0xFF2A3540);
  static const Color adSubtext = Color(0xFFAEB9C4);
  static const Color adInstallFill = Color(0xFF4AD991);
  static const Color adInstallText = Color(0xFF0C2A1C);
  static const Color adFootText = Color(0xFF7C8894);
  static const Color adChipBg = Color(0x29FFFFFF); // rgba(255,255,255,0.16)

  // --- Outcome story cards (design v1 §1.1) — the v4 redesign's new tokens.

  /// Death's inverted-only chip fill: red @ 20% opacity painted over the
  /// `ink` card background (design v1 §4.1) — a genuinely semi-transparent
  /// color, not a pre-blended opaque one, so it stays correct if the
  /// underlying card fill ever changes.
  static const Color deathChipFillOnDark = Color(0x33F0483E);

  /// Death's inverted chip text — also reused for the inverted card's
  /// name-span (design v1 §4.1's contrast fix: plain `red` on near-black
  /// `ink` measures ~3.5:1, legible but weak; this lighter red is the value
  /// the mockup itself already defines for the chip, reused for the name).
  static const Color deathChipTextOnDark = Color(0xFFFF8A82);

  /// Survived card background (design v1 §1.1) — a genuine distinct light
  /// surface from [paper]/[bg]/[paper2], its own exact mockup hex.
  static const Color surviveCardBg = Color(0xFFEAFAF1);

  /// Survived card's base ink/text color (design v1 §1.1).
  static const Color surviveInk = Color(0xFF0C3B28);

  /// Survived card's chip fill (design v1 §1.1/§4.2).
  static const Color surviveChipBg = Color(0xFFD3F2E1);

  /// Survived story-card's name-span color (design v1 Revision 2 §R2.4) — a
  /// deep, fully-saturated pine/emerald, dedicated to this one role. Replaces
  /// the previously-reused [greenDark] there: post-0.85-alpha-blend against
  /// [surviveCardBg], `greenDark` only measured ~2.7:1 (below even AA-large's
  /// 3:1); this token measures ~5.3:1. `greenDark` keeps its existing
  /// chip-text/wordmark-accent roles unchanged.
  static const Color surviveNameSpan = Color(0xFF065C31);

  /// Eternal card's base ink/text color AND chip fill (design v1 §1.1/§4.3 —
  /// the chip is intentionally the same dark-brown as the base ink, an
  /// inversion so the chip "pops dark" against the light gradient). Also
  /// doubles as the Eternal loader's dot color (design v1 §1.4).
  static const Color eternalInk = Color(0xFF5A3D00);

  /// A distinct dark-amber — the Eternal wordmark's "Alive" accent only
  /// (design v1 §1.1). Do NOT collapse with [eternalNo]/[eternalInk]: the
  /// three Eternal browns still in play are subtly different and each has
  /// exactly one role across the app.
  static const Color eternalBrandAccent = Color(0xFFA8720C);

  /// Eternal card background gradient stops (design v1 §1.2) — the current
  /// shipped card's flat [gold] fill becomes a real two-stop `LinearGradient`
  /// for the story-card redesign, a genuine `BoxDecoration.gradient` (not
  /// `.color`) code-shape change.
  static const Color eternalGradientStart = Color(0xFFFFF2D4);
  static const Color eternalGradientEnd = Color(0xFFFFE0A8);

  /// Eternal story-card's name-span color (design v1 Revision 2 §R2.4) — a
  /// deep ruby/garnet, dedicated to this one role. Replaces the previously
  /// reused [eternalNo] there: post-0.85-alpha-blend against the gradient's
  /// darker stop ([eternalGradientEnd]), `eternalNo` only measured ~3.5:1
  /// (below AA); this token measures ~5.2:1 against the darker stop and
  /// ~5.8:1 against the lighter stop ([eternalGradientStart]). `eternalInk`/
  /// `eternalBrandAccent`/chip fill are all unaffected.
  static const Color eternalNameSpan = Color(0xFF8B1E3F);
}

/// Fredoka text styles used across screens 1.1-1.5 (design spec v1 §1.2).
/// Bundled as a local asset font (architecture v1 §7) — never `google_fonts`.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Fredoka';

  /// Wordmark ("Stay" / "Alive!") — 1.1 only.
  static const TextStyle wordmark = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 0.9,
    color: AppColors.ink,
  );

  /// Screen headline (`h3.t`) — 1.2-1.5.
  static const TextStyle headline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.ink,
  );

  /// Body / tagline / description (`.d`) — all 5 screens.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.bodyMute,
  );

  /// Sticker button label (`.cta`) — white on green/coral fill.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1,
    color: Colors.white,
  );

  /// "Skip for now" ghost text link — 1.5 only.
  static const TextStyle ghostLink = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1,
    color: AppColors.mute,
    decoration: TextDecoration.underline,
  );

  /// Name input text — 1.5.
  static const TextStyle inputText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1,
    color: AppColors.ink,
  );

  /// Helper row / char counter — 1.5.
  static const TextStyle helper = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w600,
    height: 1,
    color: AppColors.mute,
  );
}

/// App-wide theme: palette + Fredoka font centralised in one place
/// (architecture v1 §7).
class AppTheme {
  const AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        surface: AppColors.bg,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: AppTypography.fontFamily),
    );
  }
}
