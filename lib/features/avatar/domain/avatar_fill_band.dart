import 'package:flutter/painting.dart' show Color;

import '../../../core/theme/app_theme.dart';

/// Fill-color band for the `AvatarFigure`'s life-meter fill (design
/// `home-avatars-v1.md` §3.2/§3.5, architect-confirmed thresholds):
/// `>=60` -> [AppColors.green], `>=20` -> [AppColors.coral], else the shared
/// danger token [AppColors.redDark] (not [AppColors.red] — §3.5's resolved
/// "one shared danger red" call).
///
/// Pure function — no widget/BuildContext dependency, so it's directly
/// unit-testable and reusable by both the Home card and (indirectly, via the
/// figure) the picker's preview tiles.
Color avatarFillColorForPercent(int fillPercent) {
  if (fillPercent >= 60) return AppColors.green;
  if (fillPercent >= 20) return AppColors.coral;
  return AppColors.redDark;
}
