import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timing_tap/features/outcome/domain/death_lines.dart';
import 'package:timing_tap/features/outcome/state/outcome_providers.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// Regression coverage for the death-card sub-line copy fix
/// (`outcome_providers.dart`): `priorDeaths = lifetimeDeaths - 1`, not
/// `lifetimeDeaths` itself, and correct singular/plural wording — pins the
/// exact bug found and fixed this session so it can never silently regress.
void main() {
  RunSummary deathSummary({required int lifetimeDeaths, int peak = 42}) {
    return RunSummary(
      outcome: RunOutcome.death,
      runNumber: 1,
      lifetimeDeaths: lifetimeDeaths,
      peakLifePercent: peak,
      minLifePercent: 0,
      perfectCount: 0,
      playerName: '',
    );
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('death card sub-line — priorDeaths off-by-one regression', () {
    test('a player\'s very first-ever death (lifetimeDeaths == 1) omits the '
        '"Survived N deaths first" clause entirely (priorDeaths == 0)', () {
      final container = buildContainer();
      final summary = deathSummary(lifetimeDeaths: 1, peak: 61);

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.subLine, 'Peaked at 61%.');
      expect(content.subLine, isNot(contains('Survived')));
    });

    test('lifetimeDeaths == 2 -> exactly 1 prior death -> singular "1 death"', () {
      final container = buildContainer();
      final summary = deathSummary(lifetimeDeaths: 2, peak: 55);

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.subLine, 'Survived 1 death first. Peaked at 55%.');
      expect(content.subLine, isNot(contains('1 deaths')));
    });

    test('lifetimeDeaths == 3 -> exactly 2 prior deaths -> plural "2 deaths", '
        'NOT the raw lifetimeDeaths value (the off-by-one this test pins)', () {
      final container = buildContainer();
      final summary = deathSummary(lifetimeDeaths: 3, peak: 40);

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.subLine, 'Survived 2 deaths first. Peaked at 40%.');
      expect(
        content.subLine,
        isNot(contains('Survived 3')),
        reason: 'a reverted off-by-one would read lifetimeDeaths directly, not lifetimeDeaths - 1',
      );
    });

    test('a large lifetimeDeaths (118) still reports exactly one fewer, '
        'pluralized', () {
      final container = buildContainer();
      final summary = deathSummary(lifetimeDeaths: 118, peak: 30);

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.subLine, 'Survived 117 deaths first. Peaked at 30%.');
    });

    test('catalogLine always reads "Death #N of 1000" regardless of the '
        'priorDeaths math (sanity: the two are independent)', () {
      final container = buildContainer();
      final summary = deathSummary(lifetimeDeaths: 10);

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.catalogLine, startsWith('Death #'));
      expect(content.catalogLine, endsWith(' of 1000'));
    });
  });

  group('survived/eternal sub-lines (sanity, not the regression under test)', () {
    test('survived sub-line reports minLifePercent via the fixed template', () {
      final container = buildContainer();
      const summary = RunSummary(
        outcome: RunOutcome.survived,
        runNumber: 1,
        lifetimeDeaths: 0,
        peakLifePercent: 20,
        minLifePercent: 3,
        perfectCount: 0,
        playerName: '',
      );

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.catalogLine, 'Last-second save');
      expect(content.subLine, contains('Down to 3%'));
    });

    test('eternal catalog line reports perfectCount/eternalPerfectCount and '
        'the sub-line is the pooled qualitative flex text (not RunSummary-derived)', () {
      final container = buildContainer();
      const summary = RunSummary(
        outcome: RunOutcome.eternal,
        runNumber: 1,
        lifetimeDeaths: 0,
        peakLifePercent: 100,
        minLifePercent: 50,
        perfectCount: 3,
        playerName: '',
      );

      final content = container.read(outcomeCardContentProvider(summary));

      expect(content.catalogLine, 'Perfect start · 3/3');
      expect(content.subLine, isNotEmpty);
      expect(content.subLine, isNot(contains('%')));
    });
  });

  group('immediate-repeat avoidance across consecutive deaths in one session '
      '(player-reviewer finding, fixed this session)', () {
    test('two back-to-back deaths in the same container never show the same '
        'flavor line twice in a row, across many repeated trials', () {
      // Run this many times since it's probabilistic without the fix (1/50
      // chance of a coincidental repeat) but deterministic with it (0/50).
      for (var trial = 0; trial < 30; trial++) {
        final container = buildContainer();
        final first = container.read(
          outcomeCardContentProvider(deathSummary(lifetimeDeaths: 1)),
        );
        final second = container.read(
          outcomeCardContentProvider(deathSummary(lifetimeDeaths: 2)),
        );

        expect(
          second.flavorEntryAnonymous,
          isNot(first.flavorEntryAnonymous),
          reason: 'trial $trial: the second death repeated the first '
              'death\'s exact flavor line in the same session',
        );
      }
    });

    test('a third death in the same session is still just excluded from '
        'repeating the immediately-previous pick, not the one before that '
        '(this is immediate-repeat avoidance, not full history dedupe)', () {
      final container = buildContainer();
      final first = container.read(
        outcomeCardContentProvider(deathSummary(lifetimeDeaths: 1)),
      );
      final second = container.read(
        outcomeCardContentProvider(deathSummary(lifetimeDeaths: 2)),
      );
      expect(second.flavorEntryAnonymous, isNot(first.flavorEntryAnonymous));

      // A third pick is only guaranteed to differ from the *second*, not
      // necessarily from the first (deliberately lightweight — see
      // FlavorSelector's doc comment). We can't assert it always differs
      // from `first` since with only 50 entries wrapping back to the first
      // one two picks later is legitimate, expected behavior.
      final third = container.read(
        outcomeCardContentProvider(deathSummary(lifetimeDeaths: 3)),
      );
      expect(third.flavorEntryAnonymous, isNot(second.flavorEntryAnonymous));
    });

    test('death pool has enough entries that immediate-repeat avoidance is '
        'meaningful (guards against a future content-pool shrink making this '
        'moot)', () {
      expect(deathLines.length, greaterThan(1));
    });
  });
}
