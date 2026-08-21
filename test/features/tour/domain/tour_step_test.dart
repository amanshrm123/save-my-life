import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/tour/domain/tour_step.dart';

/// `kHomeTourSteps` (onboarding-tour v1 §1): the tour's copy is final and
/// hardcoded here — this just pins the exact contract the rest of the tour
/// (`CoachMarkCard`/`TourOverlay`) reads it through.
void main() {
  test(
    'has exactly 4 steps, in the dashboard\'s top-to-bottom reading order',
    () {
      expect(kHomeTourSteps, hasLength(4));
      expect(kHomeTourSteps[0].headline, 'Keep your streak');
      expect(kHomeTourSteps[1].headline, 'Your record');
      expect(kHomeTourSteps[2].headline, 'This is you');
      expect(kHomeTourSteps[3].headline, 'Everything else');
    },
  );

  test('only the gear (step 4) is a circular cutout', () {
    expect(kHomeTourSteps.map((s) => s.isCircularCutout), [
      false,
      false,
      false,
      true,
    ]);
  });

  test('REGRESSION (code-reviewer finding on this pass): no step re-explains '
      'the core game mechanics teach_card.dart already covers -- tapping the '
      'number, gaining/losing life, or how a run ends -- rather than checking '
      'against strings the copy would never plausibly contain either way', () {
    // Real phrases lifted from onboarding_screen.dart's actual TeachCard
    // copy ('Tap on the number' / 'A target time appears. Tap the instant
    // it hits.', 'Mind your life' / 'Nail it, gain life. Miss, lose it.
    // Hit 0% and you\'re gone.', 'Three ways it ends' / 'Die, survive a
    // last save, or go Eternal.') -- not stray individual words, since
    // the tour's own copy can legitimately reuse a word incidentally
    // (step 2's body names the "Eternal" stat tile, which is fine; it
    // doesn't explain what going Eternal means).
    const forbiddenPhrases = [
      'target time',
      'tap the instant',
      'gain life',
      'hit 0%',
      'last save',
      'three ways',
    ];
    for (final step in kHomeTourSteps) {
      final body = step.body.toLowerCase();
      for (final phrase in forbiddenPhrases) {
        expect(
          body,
          isNot(contains(phrase)),
          reason: '"${step.headline}" duplicates onboarding copy: "$phrase"',
        );
      }
    }
  });
}
