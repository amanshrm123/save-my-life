import 'package:flutter/material.dart' show Color;

import '../../../core/theme/app_theme.dart';
import '../../play_loop/domain/run_state.dart';

/// The tier-colored gradient a shared card's sticker sits over (architecture
/// v5 §3): the outcome card PNG is passed as the *sticker* layer
/// (`interactive_asset_uri`/`foreground_media`), never the background asset,
/// so every target still needs a `top_background_color`/
/// `bottom_background_color` pair for the letterbox fill behind it.
///
/// Reuses the existing tier tokens verbatim (`AppColors.red`/`.green`/
/// `.gold`, paired with `AppColors.ink`) — no new hex values, per
/// architecture §3.
class ShareGradient {
  const ShareGradient({required this.top, required this.bottom});

  final Color top;
  final Color bottom;
}

ShareGradient shareGradientFor(RunOutcome outcome) {
  switch (outcome) {
    case RunOutcome.death:
      return const ShareGradient(top: AppColors.red, bottom: AppColors.ink);
    case RunOutcome.survived:
      return const ShareGradient(top: AppColors.green, bottom: AppColors.ink);
    case RunOutcome.eternal:
      return const ShareGradient(top: AppColors.gold, bottom: AppColors.ink);
  }
}

/// `#RRGGBB` hex string for the native side's `top_background_color`/
/// `bottom_background_color` string extras — alpha is dropped since these
/// are opaque background fills, and all app palette colors here are already
/// fully opaque.
String shareColorHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
