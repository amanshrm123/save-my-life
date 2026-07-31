import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/core/theme/app_theme.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/sharing/domain/share_composition.dart';

/// Pure unit coverage for the outcome -> tier-gradient mapping (architecture
/// v5 §3) and the hex-encoding helper the native `MethodChannel` call needs.
void main() {
  group('shareGradientFor', () {
    test('death -> red top / ink bottom', () {
      final gradient = shareGradientFor(RunOutcome.death);
      expect(gradient.top, AppColors.red);
      expect(gradient.bottom, AppColors.ink);
    });

    test('survived -> green top / ink bottom', () {
      final gradient = shareGradientFor(RunOutcome.survived);
      expect(gradient.top, AppColors.green);
      expect(gradient.bottom, AppColors.ink);
    });

    test('eternal -> gold top / ink bottom', () {
      final gradient = shareGradientFor(RunOutcome.eternal);
      expect(gradient.top, AppColors.gold);
      expect(gradient.bottom, AppColors.ink);
    });
  });

  group('shareColorHex', () {
    test('encodes as an opaque #RRGGBB string, alpha dropped', () {
      expect(shareColorHex(AppColors.ink), '#1f2a2e');
      expect(shareColorHex(AppColors.red), '#f0483e');
      expect(shareColorHex(AppColors.green), '#2fbf71');
      expect(shareColorHex(AppColors.gold), '#ffc23c');
    });

    test('pads a short hex value to 6 digits', () {
      expect(shareColorHex(const Color(0xFF000001)), '#000001');
    });
  });
}
