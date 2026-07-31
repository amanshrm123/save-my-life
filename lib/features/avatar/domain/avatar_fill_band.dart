import 'package:flutter/painting.dart' show Color;

import '../../../core/theme/app_theme.dart';

/// Fill-color band for the `AvatarFigure`'s life-meter fill (design
/// `home-avatars-v1.md` §3.2/§3.5, rebased by architecture v6 §7.1/design
/// v3 §7): `>=40` -> [AppColors.green], `>=20` -> [AppColors.coral], else
/// the shared danger token [AppColors.redDark] (not [AppColors.red] —
/// §3.5's resolved "one shared danger red" call).
///
/// Rebased from the old `>=60/>=20` thresholds because the reachable in-run
/// life values are now only 50, 40, 30, 20, 10, 0 (architecture v6 §4):
/// left at `>=60`, `green` would become unreachable app-wide (in-run and on
/// the Home avatar card, both of which share this function).
///
/// Pure function — no widget/BuildContext dependency, so it's directly
/// unit-testable and reusable by both the Home card and (indirectly, via the
/// figure) the picker's preview tiles.
Color avatarFillColorForPercent(int fillPercent) {
  if (fillPercent >= 40) return AppColors.green;
  if (fillPercent >= 20) return AppColors.coral;
  return AppColors.redDark;
}
