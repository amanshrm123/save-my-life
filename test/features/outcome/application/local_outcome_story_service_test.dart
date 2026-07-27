import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/application/local_outcome_story_service.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// Coverage for `LocalOutcomeStoryService` (architecture v4 §2/§3/§8 risk 7)
/// — the service that now owns both content selection AND the six
/// last-shown-index ints (beat + icon, per tier), plus the `forceFailure`
/// toggle. Replaces the deleted `outcome_providers_test.dart`'s coverage of
/// the old session-scoped `_LastFlavorIndices` holder, since that bookkeeping
/// moved here per architecture v4 §3.
void main() {
  RunSummary summaryFor(RunOutcome outcome) {
    return RunSummary(
      outcome: outcome,
      runNumber: 1,
      lifetimeDeaths: 1,
      peakLifePercent: 77,
      minLifePercent: 3,
      perfectCount: 3,
      playerName: 'Aman',
    );
  }

  group('repeat-avoidance — never the same beat or icon twice in a row, '
      'per tier, independently', () {
    for (final outcome in RunOutcome.values) {
      test('$outcome: across many consecutive fetches, neither the '
          'headline nor the icon repeats back-to-back', () async {
        final service = LocalOutcomeStoryService(random: Random(1));
        final summary = summaryFor(outcome);

        String? prevHeadline;
        String? prevIcon;
        for (var i = 0; i < 200; i++) {
          final content = await service.fetchStory(summary);
          if (prevHeadline != null) {
            expect(
              content.headline,
              isNot(prevHeadline),
              reason: '$outcome: fetch #$i repeated the immediately-previous headline',
            );
          }
          if (prevIcon != null) {
            expect(
              content.icon,
              isNot(prevIcon),
              reason: '$outcome: fetch #$i repeated the immediately-previous icon',
            );
          }
          prevHeadline = content.headline;
          prevIcon = content.icon;
        }
      });
    }
  });

  group('per-tier tracking is independent — one tier\'s history never '
      'affects another\'s avoid-index', () {
    test('interleaving fetches for a different tier does not disturb a '
        'given tier\'s own immediate-repeat avoidance', () async {
      final service = LocalOutcomeStoryService(random: Random(2));
      final death = summaryFor(RunOutcome.death);
      final survived = summaryFor(RunOutcome.survived);

      String? prevDeathHeadline;
      String? prevDeathIcon;
      for (var i = 0; i < 60; i++) {
        // Interleave an unrelated tier's fetch in between every death fetch.
        await service.fetchStory(survived);

        final content = await service.fetchStory(death);
        if (prevDeathHeadline != null) {
          expect(content.headline, isNot(prevDeathHeadline));
        }
        if (prevDeathIcon != null) {
          expect(content.icon, isNot(prevDeathIcon));
        }
        prevDeathHeadline = content.headline;
        prevDeathIcon = content.icon;
      }
    });

    test('beat avoidance and icon avoidance track independently — a repeat '
        'in one dimension does not force a repeat (or an unnecessary skip) '
        'in the other', () async {
      // With real (non-degenerate) pool sizes, run enough trials that if
      // beat-index and icon-index were accidentally coupled to the same
      // avoid-int, we would see systematically-impossible pairings. This is
      // a smoke test that both dimensions vary independently across trials.
      final service = LocalOutcomeStoryService(random: Random(3));
      final summary = summaryFor(RunOutcome.death);

      final headlines = <String>{};
      final icons = <String>{};
      for (var i = 0; i < 100; i++) {
        final content = await service.fetchStory(summary);
        headlines.add(content.headline);
        icons.add(content.icon);
      }
      // Over 100 trials, both dimensions should show real variety — not
      // collapsed onto a single repeated value by a shared/aliased index.
      expect(headlines.length, greaterThan(5));
      expect(icons.length, greaterThan(1));
    });
  });

  group('forceFailure', () {
    test('returns OutcomeStoryContent.naFor exactly, for every tier', () async {
      for (final outcome in RunOutcome.values) {
        final service = LocalOutcomeStoryService(random: Random(4))..forceFailure = true;
        final content = await service.fetchStory(summaryFor(outcome));
        expect(content, OutcomeStoryContent.naFor);
        expect(content.isFallback, isTrue);
      }
    });

    test('does NOT mutate any of the 6 last-shown indices, nor consume any '
        'Random draws — verified behaviorally by comparing an '
        'identically-seeded service that never calls forceFailure against '
        'one that has several forced-failure calls spliced in between real '
        'fetches; both must produce byte-identical subsequent picks', () async {
      final summary = summaryFor(RunOutcome.death);

      final baseline = LocalOutcomeStoryService(random: Random(123));
      final first = await baseline.fetchStory(summary);
      final second = await baseline.fetchStory(summary);
      final third = await baseline.fetchStory(summary);

      final withForcedFailures = LocalOutcomeStoryService(random: Random(123));
      final firstB = await withForcedFailures.fetchStory(summary);
      withForcedFailures.forceFailure = true;
      // Several forced failures in a row — must be fully inert.
      for (var i = 0; i < 5; i++) {
        final naResult = await withForcedFailures.fetchStory(summary);
        expect(naResult, OutcomeStoryContent.naFor);
      }
      withForcedFailures.forceFailure = false;
      final secondB = await withForcedFailures.fetchStory(summary);
      final thirdB = await withForcedFailures.fetchStory(summary);

      expect(firstB.headline, first.headline);
      expect(firstB.icon, first.icon);
      expect(
        secondB.headline,
        second.headline,
        reason: 'a forced failure must not have consumed a Random draw or '
            'updated the avoid-index — the next real fetch must pick '
            'exactly what it would have picked with no forced failures in '
            'between',
      );
      expect(secondB.icon, second.icon);
      expect(thirdB.headline, third.headline);
      expect(thirdB.icon, third.icon);
    });

    test('a forced failure between two real fetches for the SAME tier does '
        'not corrupt the next real fetch\'s immediate-repeat avoidance — the '
        'next real pick still correctly avoids the last REAL pick, not some '
        'stale/uninitialized index', () async {
      final service = LocalOutcomeStoryService(random: Random(9));
      final summary = summaryFor(RunOutcome.survived);

      final before = await service.fetchStory(summary);
      service.forceFailure = true;
      await service.fetchStory(summary);
      await service.fetchStory(summary);
      service.forceFailure = false;
      final after = await service.fetchStory(summary);

      expect(after.headline, isNot(before.headline));
      expect(after.icon, isNot(before.icon));
    });
  });
}
