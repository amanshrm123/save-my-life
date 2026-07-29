import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/theme/app_theme.dart';
import 'package:timing_tap/features/avatar/domain/avatar_fill_band.dart';

void main() {
  group('avatarFillColorForPercent', () {
    test('the mockup\'s three-sample demonstration (100/45/4) lands as specced', () {
      expect(avatarFillColorForPercent(100), AppColors.green);
      expect(avatarFillColorForPercent(45), AppColors.coral);
      expect(avatarFillColorForPercent(4), AppColors.redDark);
    });

    test('>= 60 is green', () {
      expect(avatarFillColorForPercent(60), AppColors.green);
      expect(avatarFillColorForPercent(61), AppColors.green);
      expect(avatarFillColorForPercent(100), AppColors.green);
    });

    test('20-59 is coral', () {
      expect(avatarFillColorForPercent(20), AppColors.coral);
      expect(avatarFillColorForPercent(59), AppColors.coral);
    });

    test('< 20 is the shared danger token, redDark (never red)', () {
      expect(avatarFillColorForPercent(19), AppColors.redDark);
      expect(avatarFillColorForPercent(0), AppColors.redDark);
      expect(avatarFillColorForPercent(19), isNot(AppColors.red));
    });

    test('boundary values are inclusive on their band\'s lower edge', () {
      expect(avatarFillColorForPercent(59), AppColors.coral);
      expect(avatarFillColorForPercent(60), AppColors.green);
      expect(avatarFillColorForPercent(19), AppColors.redDark);
      expect(avatarFillColorForPercent(20), AppColors.coral);
    });
  });
}
