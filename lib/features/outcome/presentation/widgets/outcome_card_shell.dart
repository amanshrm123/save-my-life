import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../play_loop/domain/run_state.dart';

/// Per-tier visual config (design v1 §1.1) — the single source of truth for
/// story-card colors, shared by the resolved card and the loader alike
/// (architecture v4 §4: "the loader is already tier-themed... uses the final
/// tier palette immediately", so there's no jarring color flip on resolve).
class OutcomeTierPalette {
  const OutcomeTierPalette({
    required this.chipLabel,
    this.cardColor,
    this.cardGradient,
    required this.baseText,
    required this.chipFill,
    required this.chipText,
    required this.nameSpan,
    required this.wordmarkAccent,
    required this.loaderDotColor,
    required this.loaderSublineOpacity,
  });

  final String chipLabel;

  /// Solid fill — null for Eternal, which uses [cardGradient] instead
  /// (mutually exclusive with a solid color on the same `BoxDecoration`).
  final Color? cardColor;

  /// Eternal only (design v1 §1.2) — a real `LinearGradient`, not the
  /// pre-redesign card's flat `AppColors.gold` fill.
  final Gradient? cardGradient;

  final Color baseText;
  final Color chipFill;
  final Color chipText;

  /// The colored `{name}` span inside the story text.
  final Color nameSpan;

  /// The "Alive" word in the footer wordmark — Death alone keeps the
  /// universal brand `coral` in both its (superseded) light and dark
  /// treatments; Survived/Eternal each retheme it to their own accent
  /// (design v1 §1.1's "Death is the default outcome" note — preserve this
  /// asymmetry, don't unify it).
  final Color wordmarkAccent;

  final Color loaderDotColor;

  /// Two genuinely different values across tiers (design v1 §1.4/§5): 0.55
  /// on Death's dark card, 0.6 on Survived/Eternal's light cards. Don't
  /// collapse to one shared constant.
  final double loaderSublineOpacity;

  static const death = OutcomeTierPalette(
    chipLabel: '💀 You died',
    cardColor: AppColors.ink,
    baseText: AppColors.paper,
    chipFill: AppColors.deathChipFillOnDark,
    chipText: AppColors.deathChipTextOnDark,
    nameSpan: AppColors.deathChipTextOnDark,
    wordmarkAccent: AppColors.coral,
    loaderDotColor: AppColors.coral,
    loaderSublineOpacity: 0.55,
  );

  static const survived = OutcomeTierPalette(
    chipLabel: '🆘 Survived',
    cardColor: AppColors.surviveCardBg,
    baseText: AppColors.surviveInk,
    chipFill: AppColors.surviveChipBg,
    chipText: AppColors.greenDark,
    nameSpan: AppColors.surviveNameSpan,
    wordmarkAccent: AppColors.greenDark,
    loaderDotColor: AppColors.greenDark,
    loaderSublineOpacity: 0.6,
  );

  static const eternal = OutcomeTierPalette(
    chipLabel: '✨ Eternal · Top 0.3%',
    cardGradient: LinearGradient(
      begin: Alignment(-0.3, -1),
      end: Alignment(0.3, 1),
      colors: [AppColors.eternalGradientStart, AppColors.eternalGradientEnd],
    ),
    baseText: AppColors.eternalInk,
    chipFill: AppColors.eternalInk,
    chipText: AppColors.gold,
    nameSpan: AppColors.eternalNameSpan,
    wordmarkAccent: AppColors.eternalBrandAccent,
    loaderDotColor: AppColors.eternalInk,
    loaderSublineOpacity: 0.6,
  );

  static OutcomeTierPalette of(RunOutcome outcome) {
    switch (outcome) {
      case RunOutcome.death:
        return death;
      case RunOutcome.survived:
        return survived;
      case RunOutcome.eternal:
        return eternal;
    }
  }
}

/// Shared 3:4 silhouette used by both `OutcomeCard` (resolved) and
/// `OutcomeCardLoading` (architecture v4 §7) — `AspectRatio(3/4)` (design
/// v1 Revision 5 — supersedes Revision 4's 6:7, which superseded Revision
/// 3's 4:5, which superseded Revision 2's 3:4, itself superseding the
/// original 9:16 shape), 26dp radius, NO border, and a soft blurred drop
/// shadow.
///
/// Revision 5's trigger: Revision 4 fixed the real root-cause bug that had
/// made every prior ratio a no-op in production (`AspectRatio` sat inside a
/// tight-constrained `Expanded`, so it never bound its own height — see
/// `outcome_card_screen.dart`'s `Center` wrapper) — once that was genuinely
/// fixed, 6:7 read as *too* short for a 3-4 line story on-device. Re-run of
/// the same fit-check methodology (fixed overhead ≈192dp at k=1: 48dp
/// padding + ≈32dp top row + 12dp lead-in gap + ≈100dp `CardFooter`):
/// 3:4 gives a 250×333.33dp box, leaving ≈141.33dp for headline+story+floor
/// rule — comfortably fits a 1-line headline + 4-line story (≈132.64dp)
/// with no `FittedBox` shrink, and only engages a barely-perceptible shrink
/// (~87%) on the genuine double-worst-case (2-line headline + 4-line
/// story, ≈162.88dp) rather than the every-4-line-story shrink 6:7 forced.
///
/// This is the one deliberate exception to this app's house "sticker"
/// pattern (2-3dp ink border + hard, zero-blur offset shadow) — scoped
/// ONLY to this card shell, never the Share/Again buttons or toast
/// around it (design v1 §2.1). The card's whole purpose culminates in a
/// rasterized export shared outside the app, where a soft, naturalistic
/// shadow reads as "a floating card" against an arbitrary external
/// background — unlike every other in-app component, which is styled
/// specifically to read against this app's own flat `bg`.
///
/// Every internal dimension passed to [builder] should be scaled by the
/// [k] factor it receives (design v1 §2.2): `k = actualWidth /
/// referenceWidth`, where `referenceWidth` (250dp) is the mockup's own
/// reference card width — this guarantees the exported share image is a
/// faithful, proportioned rendition of the mockup regardless of the source
/// device's screen size.
class OutcomeCardShell extends StatelessWidget {
  const OutcomeCardShell({
    super.key,
    required this.palette,
    required this.builder,
  });

  final OutcomeTierPalette palette;
  final Widget Function(BuildContext context, double k) builder;

  static const double referenceWidth = 250;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final k = constraints.maxWidth / referenceWidth;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.cardGradient == null ? palette.cardColor : null,
              gradient: palette.cardGradient,
              borderRadius: BorderRadius.circular(26 * k),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.20),
                  offset: Offset(0, 16 * k),
                  blurRadius: 36 * k,
                ),
              ],
            ),
            // This card is a fixed-composition export asset: every dimension
            // already scales by [k] to fit its own 3:4 box, but `Text`
            // still applies the device's system font-scaling on top of
            // that unless told not to. At k=1 the store badges alone need
            // ~176 of the 206dp available width — an Android "Larger text"
            // setting (scaler ~1.3) would push layout past the edge, and
            // since this gets rasterized via `RepaintBoundary` into a
            // shared PNG, any resulting overflow/clipping ships to whoever
            // the card is shared with. Pinning `TextScaler.noScaling` here
            // is a deliberate, scoped choice for this one export contract —
            // not a general accessibility regression — since nothing about
            // this card's fixed 3:4 layout can accommodate arbitrary
            // user text-scaling without breaking that contract.
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: builder(context, k),
            ),
          );
        },
      ),
    );
  }
}
