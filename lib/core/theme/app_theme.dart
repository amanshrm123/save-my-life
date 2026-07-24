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
  static const Color gold = Color(0xFFFFC23C);
  static const Color goldDark = Color(0xFFE5A516);

  /// Helper row / char counter / disabled-secondary text.
  static const Color mute = Color(0xFF7B8A86);

  /// Tagline / description paragraph under every headline. Distinct from
  /// [mute] despite both being cool grays — do not collapse them.
  static const Color bodyMute = Color(0xFF4A5F5A);

  /// Inactive page-dot fill. Distinct from [mute] and [bodyMute].
  static const Color dotInactive = Color(0xFFA7C4B8);

  static const Color blue = Color(0xFF4A9FD8);
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
