import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play_loop/data/run_stats_repository.dart';
import '../../play_loop/domain/run_summary.dart';
import '../../play_loop/state/play_loop_providers.dart' show runStatsRepositoryProvider;
import '../domain/stats_snapshot.dart';
import '../domain/streak.dart';
import '../domain/streak_calculator.dart';

/// RAM cache of `RunStatsRepository`'s totals + streak (architecture v3 §6):
/// read once, then refreshed after a run completes (`registerRunCompletion`)
/// or after a reset (`ref.invalidate(statsProvider)`, architecture §11 risk
/// 4) — Home/Stats never poll the repository directly.
///
/// Deliberately **not** `.autoDispose` — a kept-alive RAM source of truth for
/// the whole app session, the same discipline as `AdGate` (architecture §5).
class StatsController extends Notifier<StatsSnapshot> {
  static const StreakCalculator _streakCalculator = StreakCalculator();

  @override
  StatsSnapshot build() => _readSnapshot();

  StatsSnapshot _readSnapshot({bool justAdvanced = false}) {
    return _snapshotFrom(ref.read(runStatsRepositoryProvider), justAdvanced: justAdvanced);
  }

  StatsSnapshot _snapshotFrom(RunStatsRepository repo, {bool justAdvanced = false}) {
    return StatsSnapshot(
      totalRunsPlayed: repo.totalRunsPlayed,
      totalDeaths: repo.totalDeaths,
      totalSurvives: repo.totalSurvives,
      totalEternal: repo.totalEternal,
      bestLifePercent: repo.bestLifePercent,
      streak: repo.streak,
      justAdvanced: justAdvanced,
    );
  }

  /// Called by `RunController` at run completion (architecture v3 §2/§6):
  /// persists the run + advances the daily streak via the single writer
  /// (`RunStatsRepository`), then refreshes this snapshot so Home/Stats
  /// reflect it immediately, with no separate poll/invalidate round-trip.
  ///
  /// The repository is captured **once**, synchronously, before the first
  /// `await` (architecture §11 risk 7) — every use of it after that point
  /// is a plain Dart object call, never a second `ref.read`. This matters
  /// because the caller (`RunController`) invokes this fire-and-forget
  /// (`unawaited`): if the whole `ProviderContainer` is torn down while this
  /// is still in flight (e.g. a screen/test disposing before the awaits
  /// settle), a second `ref.read` here would throw on the now-disposed
  /// `ref`. `ref.mounted` guards the final state write for the same reason.
  Future<void> registerRunCompletion(RunSummary summary) async {
    final repo = ref.read(runStatsRepositoryProvider);
    await repo.recordRunCompleted(summary);
    final result = await repo.registerPlayDay(_streakCalculator.today());
    if (!ref.mounted) return;
    state = _snapshotFrom(repo, justAdvanced: result.transition == StreakTransition.advanced);
  }

  /// Clears the transient "streak advanced" celebration flag once Home has
  /// shown it (architecture §6.2) — display-once semantics.
  void clearJustAdvanced() {
    if (!state.justAdvanced) return;
    state = state.copyWith(justAdvanced: false);
  }
}

final NotifierProvider<StatsController, StatsSnapshot> statsProvider =
    NotifierProvider<StatsController, StatsSnapshot>(StatsController.new);
