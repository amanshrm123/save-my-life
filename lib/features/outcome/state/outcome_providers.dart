import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play_loop/domain/run_summary.dart';
import '../application/local_outcome_story_service.dart';
import '../application/outcome_story_service.dart';
import '../domain/outcome_story_content.dart';

/// Minimum branded-loader duration (architecture v4 §2/§4, design v1 §7) —
/// enforced here via `Future.wait`, matching `SplashScreen`'s existing
/// min-duration idiom (`Future.wait([realWork, Future.delayed(minDuration)])`
/// in the screen/provider layer, never inside the data source itself).
const Duration kMinStoryLoadDuration = Duration(seconds: 2);

/// Session-scoped, deliberately NOT `autoDispose` (architecture v4 §3): the
/// service instance — and its per-tier last-shown-index memory for both the
/// beat and icon pools — needs to live for the whole app session, the same
/// lifetime `outcomeRandomProvider`/`flavorSelectorProvider` had pre-redesign.
final Provider<OutcomeStoryService> outcomeStoryServiceProvider =
    Provider<OutcomeStoryService>((ref) => LocalOutcomeStoryService());

/// Resolves this run's fully-formed card content exactly once per
/// `RunSummary` instance (family-cached by object identity — the screen
/// holds the one `RunSummary` for its whole life, so rebuilds like the
/// share-toast appearing/disappearing never re-fetch or re-roll).
///
/// `autoDispose`'d: the screen watches continuously for its entire
/// lifetime, so no `ref.keepAlive()` is needed (architecture §3) — the
/// family entry is freed when the screen goes away (replaced by "Again" or
/// popped via "Home").
final outcomeStoryProvider =
    FutureProvider.autoDispose.family<OutcomeStoryContent, RunSummary>((ref, summary) async {
      // `content` is assigned from the real fetch's own typed `Future`, so
      // there's no untyped `List<Object?>` result to cast back out of —
      // `Future.wait` still runs both futures concurrently (the fetch and
      // the minimum-duration delay), it just no longer needs a shared
      // heterogeneous result list to do it.
      late final OutcomeStoryContent content;
      await Future.wait<void>([
        ref.watch(outcomeStoryServiceProvider).fetchStory(summary).then((c) => content = c),
        Future<void>.delayed(kMinStoryLoadDuration),
      ]);
      return content;
    });
