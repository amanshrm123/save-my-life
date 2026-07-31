import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/theme/app_theme.dart';
import 'package:timing_tap/features/avatar/domain/avatar_fill_band.dart';

void main() {
  group('avatarFillColorForPercent', () {
    // Rebased by architecture v6 §7.1 (>=60/>=20 -> >=40/>=20) so `green`
    // stays reachable once the Play Loop's life economy becomes
    // attrition-only (reachable in-run values: 50/40/30/20/10/0). Note this
    // moves 45 from the old coral band into the new green band — it is NOT
    // still a 3-distinct-band demonstration under the new thresholds, only
    // 4 still lands in the danger band.
    test('the original mockup sample (100) and 4 both land as specced; 45 '
        'now lands in green under the rebased threshold', () {
      expect(avatarFillColorForPercent(100), AppColors.green);
      expect(avatarFillColorForPercent(45), AppColors.green);
      expect(avatarFillColorForPercent(4), AppColors.redDark);
    });

    test('>= 40 is green', () {
      expect(avatarFillColorForPercent(40), AppColors.green);
      expect(avatarFillColorForPercent(41), AppColors.green);
      expect(avatarFillColorForPercent(100), AppColors.green);
    });

    test('20-39 is coral', () {
      expect(avatarFillColorForPercent(20), AppColors.coral);
      expect(avatarFillColorForPercent(39), AppColors.coral);
    });

    test('< 20 is the shared danger token, redDark (never red)', () {
      expect(avatarFillColorForPercent(19), AppColors.redDark);
      expect(avatarFillColorForPercent(0), AppColors.redDark);
      expect(avatarFillColorForPercent(19), isNot(AppColors.red));
    });

    test('boundary values are inclusive on their band\'s lower edge', () {
      expect(avatarFillColorForPercent(39), AppColors.coral);
      expect(avatarFillColorForPercent(40), AppColors.green);
      expect(avatarFillColorForPercent(19), AppColors.redDark);
      expect(avatarFillColorForPercent(20), AppColors.coral);
    });

    // Canary from the Play Loop's reachable in-run life values (architecture
    // v6 §4.5): 50, 40, 30, 20, 10, 0.
    test('the reachable in-run life values land as v6 §7.1 intends', () {
      expect(avatarFillColorForPercent(50), AppColors.green);
      expect(avatarFillColorForPercent(40), AppColors.green);
      expect(avatarFillColorForPercent(30), AppColors.coral);
      expect(avatarFillColorForPercent(20), AppColors.coral);
      expect(avatarFillColorForPercent(10), AppColors.redDark);
      expect(avatarFillColorForPercent(0), AppColors.redDark);
    });
  });
}
