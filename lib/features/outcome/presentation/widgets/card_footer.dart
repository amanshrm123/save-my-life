import 'package:flutter/material.dart';

import 'outcome_card_shell.dart';
import 'store_badges.dart';

/// Footer stack for the resolved card (design v1 §3 anatomy): tagline ->
/// wordmark -> store badges, each separated by a 10dp gap (scaled by [k]),
/// centered. The loading state renders `OutcomeWordmark` on its own, pinned
/// at the bottom with no tagline and no store badges (design v1 §7.1).
class CardFooter extends StatelessWidget {
  const CardFooter({super.key, required this.palette, required this.k});

  final OutcomeTierPalette palette;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200 * k,
          child: Text(
            'One tap saves you — or ends you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 12 * k,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: palette.baseText.withValues(alpha: 0.75),
            ),
          ),
        ),
        SizedBox(height: 8 * k),
        OutcomeWordmark(
          color: palette.baseText,
          accent: palette.wordmarkAccent,
          k: k,
        ),
        SizedBox(height: 8 * k),
        StoreBadges(color: palette.baseText, k: k),
      ],
    );
  }
}

/// "💓 Stay Alive" — the heart glyph is deliberately SMALLER (15dp at k=1)
/// than the 19dp wordmark text beside it (design v1 §5) — a different ratio
/// than the splash screen's big hero mark; don't unify the two.
class OutcomeWordmark extends StatelessWidget {
  const OutcomeWordmark({
    super.key,
    required this.color,
    required this.accent,
    required this.k,
  });

  final Color color;
  final Color accent;
  final double k;

  @override
  Widget build(BuildContext context) {
    // Wrapped in a `FittedBox` (design v1 §5's 19dp text + 15dp glyph leave
    // almost zero horizontal headroom at k=1, where the card's available
    // content width is only 206dp) so the row scales itself down rather than
    // overflowing `RenderFlex` if the glyph+text ever measure a hair wider
    // than the card at any `k` — a fixed-composition export card can't rely
    // on wrapping, so shrink-to-fit is the correct failure mode here, not a
    // clipped/overflowing row baked into the shared PNG.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('💓', style: TextStyle(fontSize: 15 * k, height: 1)),
          SizedBox(width: 6 * k),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 19 * k,
                fontWeight: FontWeight.w700,
                height: 1,
                color: color,
              ),
              children: [
                const TextSpan(text: 'Stay '),
                TextSpan(
                  text: 'Alive',
                  style: TextStyle(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
