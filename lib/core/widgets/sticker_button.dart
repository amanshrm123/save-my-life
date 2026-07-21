import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared "sticker" chrome — border + flat, zero-blur drop-shadow + fill —
/// backing the mockup's `.cta`/`.ghostbtn`/`.row` classes
/// (docs/design/onboarding-flow-v1.md §2.3/§4). Reused well beyond
/// onboarding (outcome cards, settings rows, pause modal), which is why it
/// lives in `core/widgets/` rather than a feature folder.
///
/// Deliberately **not** `Material`/`ElevatedButton` — Material's
/// `elevation`/`PhysicalModel` shadow always blurs and simulates ambient +
/// direct light, which does not match the mockup's hard `box-shadow: 0 Npx
/// 0 var(--ink)`. The shadow is authored directly on a `BoxDecoration`
/// instead (§2.3).
class StickerButton extends StatelessWidget {
  const StickerButton({
    super.key,
    required this.label,
    required this.fillColor,
    required this.onPressed,
    this.shadowDepth = 5,
    this.borderColor = AppColors.ink,
    this.textShadowColor,
  });

  final String label;
  final Color fillColor;
  final VoidCallback? onPressed;

  /// CSS shadow depth in px — 5 for primary CTAs, 4 for ghost-style
  /// buttons (§2.2).
  final double shadowDepth;

  /// Border color — ink by default, red for 8.1's rejected-state reuse if
  /// a caller opts into that instead of a fresh style (§2.2/§4).
  final Color borderColor;

  /// The `-Dark` variant of [fillColor] used for the button label's flat
  /// text-shadow (§2.4). Defaults to [AppColors.coralDark] when [fillColor]
  /// is coral-ish and [AppColors.greenDark] otherwise-ish is too clever to
  /// guess reliably, so callers should pass this explicitly; it falls back
  /// to [AppColors.ink] with no visible offset risk if omitted.
  final Color? textShadowColor;

  @override
  Widget build(BuildContext context) {
    // Hit target includes the shadow strip (§2.3) — the entire Container
    // (fill rect + its shadow strip beneath it) is wrapped in the tap
    // handler, not just the top fill rectangle.
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(0, shadowDepth),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: Colors.white,
            shadows: [
              Shadow(
                color: textShadowColor ?? AppColors.ink,
                offset: const Offset(0, 1.5),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
