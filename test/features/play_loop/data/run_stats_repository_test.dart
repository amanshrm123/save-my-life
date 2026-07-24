import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/play_loop/data/run_stats_repository.dart';

/// Architecture v2 §6 (founder-resolved, revised): Run/Deaths are genuine
/// cross-session lifetime totals persisted via `shared_preferences`, not
/// session-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

      await repo.recordRunCompleted(wasDeath: false);

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 1, reason: 'survived/eternal must not bump deaths');
    });

    test('a death outcome increments both totalRunsPlayed and totalDeaths', () async {
      final service = await buildService({kKeyTotalRunsPlayed: 3, kKeyTotalDeaths: 1});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(wasDeath: true);

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 2);
    });

    test('writes survive a fresh repository instance over the same prefs '
        '(durability, simulating a relaunch)', () async {
      final service = await buildService({});
      await RunStatsRepository(service).recordRunCompleted(wasDeath: true);

      final reloaded = RunStatsRepository(service);
      expect(reloaded.totalRunsPlayed, 1);
      expect(reloaded.totalDeaths, 1);
    });

    test('repeated completions accumulate correctly across many runs', () async {
      final service = await buildService({});
      final repo = RunStatsRepository(service);

      await repo.recordRunCompleted(wasDeath: true); // 1 played, 1 death
      await repo.recordRunCompleted(wasDeath: false); // 2 played, 1 death
      await repo.recordRunCompleted(wasDeath: false); // 3 played, 1 death
      await repo.recordRunCompleted(wasDeath: true); // 4 played, 2 deaths

      expect(repo.totalRunsPlayed, 4);
      expect(repo.totalDeaths, 2);
    });
  });
}
