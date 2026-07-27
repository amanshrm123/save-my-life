import 'package:flutter/material.dart';

/// Decorative, non-tappable "available on" badges (design v1 §6, architecture
/// v4 §6.2) — genuinely rendered on-screen on the resolved card, and inside
/// the shared `RepaintBoundary` so they're also baked into the exported
/// share image ("every share is an install ad"). Plain bordered containers,
/// no `GestureDetector`, no `url_launcher`, no new dependency.
///
/// Founder-resolved (post-compliance-review, this session): the mockup's
/// literal copy ("Download on / App Store", "Get it on / Google Play")
/// reproduces Apple's and Google's trademarked badge phrasing/lockups
/// without using their official badge artwork — both an app-store and a
/// play-store compliance pass flagged this as a real brand-guideline risk
/// the moment a card is shared publicly (not just at store-submission
/// time). Reworded to generic, non-trademarked platform names ("iOS" /
/// "Android") instead of store-brand names ("App Store" / "Google Play"),
/// keeping the two-badge "available on" visual convention the design
/// intends without reproducing anyone's trademarked lockup. Revisit with
/// official badge assets once real store listings exist.
class StoreBadges extends StatelessWidget {
  const StoreBadges({super.key, required this.color, required this.k});

  final Color color;
  final double k;

  @override
  Widget build(BuildContext context) {
    // Same near-zero-headroom problem as `OutcomeWordmark` (design v1 §2.2's
    // 206dp content width at k=1): the two badges' real Fredoka-rendered
    // width runs wider than the ~176dp the design doc estimated, overflowing
    // `RenderFlex` on exactly the same class of bug as the wordmark row —
    // wrapped in the same `FittedBox` fix so it scales itself down to fit
    // rather than overflowing into the shared PNG.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StoreBadge(icon: '', line1: 'Available on', line2: 'iOS', color: color, k: k),
          SizedBox(width: 6 * k),
          _StoreBadge(icon: '', line1: 'Available on', line2: 'Android', color: color, k: k),
        ],
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({
    required this.icon,
    required this.line1,
    required this.line2,
    required this.color,
    required this.k,
  });

  final String icon;
  final String line1;
  final String line2;
  final Color color;
  final double k;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * k, vertical: 5 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 * k),
        border: Border.all(color: color, width: 1.5 * k),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: 12 * k, color: color, height: 1)),
          SizedBox(width: 5 * k),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                line1,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 8 * k,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: color,
                ),
              ),
              Text(
                line2,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 10 * k,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
