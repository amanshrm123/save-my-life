import 'package:flutter/material.dart';

/// Flat color token reference for the onboarding flow, distilled from
/// `screen-library-v3.html`'s `:root` CSS
/// (docs/design/onboarding-flow-v1.md §2.1). Deliberately a plain `const`
/// class, not a design-tokens package or `ThemeExtension` — this repo's
/// flat-module discipline (architecture v2 §2/§4) doesn't need more than
/// that for a handful of named colors.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFC8ECD9);
  static const Color ink = Color(0xFF1F2A2E);
  static const Color paper = Color(0xFFFFFDF7);
  static const Color paper2 = Color(0xFFF2EFE6);
  static const Color coral = Color(0xFFFF7A59);
  static const Color coralDark = Color(0xFFE5613F);
  static const Color green = Color(0xFF2FBF71);
  static const Color greenDark = Color(0xFF1F9C58);
  static const Color red = Color(0xFFF0483E);
  static const Color mute = Color(0xFF7B8A86);

  /// Splash tagline color (§2.4) — a slightly darker mute than [mute],
  /// matching the mockup's `.d` context on the mint background.
  static const Color splashTagline = Color(0xFF3F5651);

  /// Teaching-card body text color (§2.4).
  static const Color teachBody = Color(0xFF4A5F5A);

  /// 8.1 name-rejected note banner background (§5.6).
  static const Color noteBg = Color(0xFFFDE3E3);
}

/// App-wide theme. `fontFamily: 'Fredoka'` is set once, globally, here —
/// individual `TextStyle`s only need `fontWeight: FontWeight.w400/500/600/
/// 700` (docs/design/onboarding-flow-v1.md §1); Flutter/Skia resolves the
/// matching bundled weight automatically, no per-widget `fontFamily`
/// overrides needed anywhere in onboarding.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Fredoka',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.coral),
  );
}
