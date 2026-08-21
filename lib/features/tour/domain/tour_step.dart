import 'package:flutter/foundation.dart';

/// One step of the Home dashboard's first-time feature tour (design v1 §1).
/// Copy is final and single-call-site, so it lives here rather than
/// `core/copy/app_copy.dart` (whose own doc comment scopes it to strings
/// reused across more than one screen).
@immutable
class TourStep {
  const TourStep({
    required this.emoji,
    required this.headline,
    required this.body,
    this.cornerRadius = 14,
    this.isCircularCutout = false,
  });

  final String emoji;
  final String headline;
  final String body;

  /// Spotlight cutout corner radius (design v1 §3.1) — matches the target
  /// widget's own chrome. Ignored when [isCircularCutout] is true.
  final double cornerRadius;

  /// The gear (step 4) renders as a circle: half the *inflated* cutout
  /// rect's height, computed at paint time since it depends on the
  /// measured rect (design v1 §3.1) — this flag just selects that behavior
  /// instead of a fixed [cornerRadius].
  final bool isCircularCutout;
}

/// The tour's four steps, in the dashboard's own top-to-bottom reading
/// order, gear deliberately last (design v1 §1). A hardcoded `const` list —
/// v1 has exactly one tour, on Home, and this is not a reusable framework
/// (design v1 §6).
const List<TourStep> kHomeTourSteps = [
  TourStep(
    emoji: '🔥',
    headline: 'Keep your streak',
    body: 'Play once a day to hold it. Miss a day, back to zero.',
    cornerRadius: 16,
  ),
  TourStep(
    emoji: '📊',
    headline: 'Your record',
    body: 'Survived, Eternal, Deaths. Tap any tile for full stats.',
    cornerRadius: 14,
  ),
  TourStep(
    emoji: '🧍',
    headline: 'This is you',
    body: 'The fill is your best life ever. Tap to change your look.',
    cornerRadius: 14,
  ),
  TourStep(
    emoji: '⚙️',
    headline: 'Everything else',
    body: 'Sound, name and daily reminders live behind the gear.',
    isCircularCutout: true,
  ),
];
