import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/play_loop/data/run_stats_repository.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// Architecture v2 §6 (founder-resolved, revised); extended by architecture
/// v3 §2: Run/Deaths/Survives/Eternal/best-life are genuine cross-session
/// lifetime totals persisted via `shared_preferences`, not session-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Minimal `RunSummary` for these totals-only tests — only `outcome`
  /// matters here (the other fields don't affect `recordRunCompleted`'s
  /// runs-played/deaths bookkeeping under test).
  RunSummary summary({required bool wasDeath, int peakLifePercent = 0}) {
    return RunSummary(
      outcome: wasDeath ? RunOutcome.death : RunOutcome.survived,
      runNumber: 0,
      lifetimeDeaths: 0,
      peakLifePercent: peakLifePercent,
      minLifePercent: 0,
      perfectCount: 0,
      playerName: '',
    );
  }

  RunSummary summaryWithOutcome(RunOutcome outcome, {int peakLifePercent = 0}) {
    return RunSummary(
      outcome: outcome,
      runNumber: 0,
      lifetimeDeaths: 0,
      peakLifePercent: peakLifePercent,
      minLifePercent: 0,
      perfectCount: 0,
      playerName: '',
    );
  }

  Future<PreferencesService> buildService(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    return PreferencesService.create();
  }

  group('RunStatsRepository — reads', () {
    test('defaults to 0/0 when no keys are present (first launch)', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      expect(repo.totalRunsPlayed, 0);
      expect(repo.totalDeaths, 0);
    });

    test('reflects previously-persisted values', () async {
      final service = await buildService({
        kKeyTotalRunsPlayed: 12,
        kKeyTotalDeaths: 4,
      });
      final repo = RunStatsRepository(service);

      expect(repo.totalRunsPlayed, 12);
      expect(repo.totalDeaths, 4);
    });
  });

  group('RunStatsRepository.recordRunCompleted', () {
    test('a non-death outcome increments totalRunsPlayed but NOT totalDeaths', () async {
      final service = await buildService({kKeyTotalRunsPlayed: 3, kKeyTotalDeaths: 1});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: false));

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 1, reason: 'survived/eternal must not bump deaths');
    });

    test('a death outcome increments both totalRunsPlayed and totalDeaths', () async {
      final service = await buildService({kKeyTotalRunsPlayed: 3, kKeyTotalDeaths: 1});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: true));

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 2);
    });

    test('writes survive a fresh repository instance over the same prefs '
        '(durability, simulating a relaunch)', () async {
      final service = await buildService({});
      await RunStatsRepository(service).recordRunCompleted(summary(wasDeath: true));

      final reloaded = RunStatsRepository(service);
      expect(reloaded.totalRunsPlayed, 1);
      expect(reloaded.totalDeaths, 1);
    });

    test('repeated completions accumulate correctly across many runs', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: true)); // 1 played, 1 death
      await repo.recordRunCompleted(summary(wasDeath: false)); // 2 played, 1 death
      await repo.recordRunCompleted(summary(wasDeath: false)); // 3 played, 1 death
      await repo.recordRunCompleted(summary(wasDeath: true)); // 4 played, 2 deaths

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 2);
    });
  });

  group('RunStatsRepository.recordRunCompleted — outcome routing (architecture v3 §2)', () {
    test('a survived outcome increments totalSurvives but neither totalDeaths nor totalEternal', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.survived));

      expect(repo.totalRunsPlayed, 1);
      expect(repo.totalSurvives, 1);
      expect(repo.totalDeaths, 0);
      expect(repo.totalEternal, 0);
    });

    test('an eternal outcome increments totalEternal but neither totalDeaths nor totalSurvives', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.eternal));

      expect(repo.totalRunsPlayed, 1);
      expect(repo.totalEternal, 1);
      expect(repo.totalDeaths, 0);
      expect(repo.totalSurvives, 0);
    });

    test('a death outcome increments totalDeaths but neither totalSurvives nor totalEternal', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.death));

      expect(repo.totalDeaths, 1);
      expect(repo.totalSurvives, 0);
      expect(repo.totalEternal, 0);
    });

    test('a mixed sequence of outcomes routes each to exactly its own counter', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.death));
      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.survived));
      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.survived));
      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.eternal));

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 1);
      expect(repo.totalSurvives, 2);
      expect(repo.totalEternal, 1);
    });
  });

  group('RunStatsRepository.recordRunCompleted — bestLifePercent (architecture v3 §2)', () {
    test('the first completed run\'s peak becomes bestLifePercent from a 0 default', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: true, peakLifePercent: 40));

      expect(repo.bestLifePercent, 40);
    });

    test('a strictly higher peak on a later run replaces bestLifePercent', () async {
      final service = await buildService({kKeyBestLifePercent: 40});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: true, peakLifePercent: 61));

      expect(repo.bestLifePercent, 61);
    });

    test('a lower-or-equal peak on a later run does NOT update bestLifePercent '
        '(only a genuine new peak updates it)', () async {
      final service = await buildService({kKeyBestLifePercent: 61});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summary(wasDeath: true, peakLifePercent: 40));
      expect(repo.bestLifePercent, 61, reason: 'a lower peak must not overwrite the existing best');

      await repo.recordRunCompleted(summary(wasDeath: false, peakLifePercent: 61));
      expect(repo.bestLifePercent, 61, reason: 'an equal peak is not a NEW peak, so it must not "update" (no-op is fine either way, but it must not regress)');
    });

    test('bestLifePercent updates regardless of outcome (death/survived/eternal '
        'all carry a peakLifePercent worth comparing)', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(summaryWithOutcome(RunOutcome.eternal, peakLifePercent: 100));

      expect(repo.bestLifePercent, 100);
    });
  });

  group('RunStatsRepository.registerPlayDay (architecture v3 §2/§11 risk 5)', () {
    test('the first-ever play registers a streak of 1 and persists it', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      final result = await repo.registerPlayDay(100);

      expect(result.streak.count, 1);
      expect(repo.streak.count, 1);
      expect(repo.streak.lastPlayDay, 100);
    });

    test('calling registerPlayDay twice for the SAME day is idempotent — the '
        'streak count does not double-increment', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.registerPlayDay(100);
      final second = await repo.registerPlayDay(100);

      expect(second.streak.count, 1);
      expect(repo.streak.count, 1);
    });

    test('a play on the next calendar day advances the persisted streak', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.registerPlayDay(100);
      final result = await repo.registerPlayDay(101);

      expect(result.streak.count, 2);
      expect(repo.streak.count, 2);
      expect(repo.streak.lastPlayDay, 101);
    });

    test('a fresh RunStatsRepository instance over the same prefs reflects '
        'the persisted streak (durability, simulating a relaunch)', () async {
      final service = await buildService({});
      await RunStatsRepository(service).registerPlayDay(100);

      final reloaded = RunStatsRepository(service);
      expect(reloaded.streak.count, 1);
      expect(reloaded.streak.lastPlayDay, 100);
    });
  });
}
