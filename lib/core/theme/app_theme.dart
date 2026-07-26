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

  /// Survived outcome-cardbox background (design v3 §1.2) — a genuine 4th
  /// light surface color, distinct from [paper]/[bg]/[paper2].
  static const Color cardSurviveBg = Color(0xFFE3F7EE);

  /// Eternal outcome-cardbox's catalog-line + `stayalive.app` mark color
  /// (design v3 §1.2) — overrides the default tier color on the solid-gold
  /// fill (dark/low-saturation, matching the ARM plate's contrast rule).
  static const Color eternalNo = Color(0xFF8A5A00);

  /// Eternal outcome-cardbox's flavor-line body text color (design v3 §1.2).
  static const Color eternalWay = Color(0xFF6B4600);

  /// Eternal outcome-cardbox's colored-name-span color (design v3 §1.2) —
  /// the gold-bg analog of [coral] used on paper/mint cards.
  static const Color eternalName = Color(0xFFB5500E);

  /// Ad-chrome palette (design v3 §1.4) — deliberately off-palette, used
  /// only by the two full ad screens (5.1/5.3) so they read as "someone
  /// else's UI," never reused elsewhere in the app.
  static const Color adBg = Color(0xFF2A3540);
  static const Color adSubtext = Color(0xFFAEB9C4);
  static const Color adInstallFill = Color(0xFF4AD991);
  static const Color adInstallText = Color(0xFF0C2A1C);
  static const Color adFootText = Color(0xFF7C8894);
  static const Color adChipBg = Color(0x29FFFFFF); // rgba(255,255,255,0.16)
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
