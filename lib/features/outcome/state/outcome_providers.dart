import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../onboarding/state/onboarding_providers.dart'
    show preferencesServiceProvider;
import '../../play_loop/domain/run_summary.dart';
import '../application/outcome_story_service.dart';
import '../application/remote_outcome_story_service.dart';
import '../application/story_config_endpoint.dart';
import '../application/story_cycle_store.dart';
import '../application/story_pool_repository.dart';
import '../domain/outcome_story_content.dart';
import '../domain/story_pool.dart';

/// Loading floor. 2s -> 1000ms — the fetch is no longer on the card's
/// critical path (remote-story-config-implementation-spec §5.1), so this is
/// purely a dramatic-pause design lever. game-ux-designer reviewed the
/// options-doc's proposed 1200ms against `OutcomeCardLoading`'s own
/// heartbeat pulse (an exact 1-second `AnimationController` cycle) and
/// found 1200ms cut the pulse off 20% into a second beat — 1000ms lets it
/// complete exactly one full cycle before the card resolves.
const Duration kMinStoryLoadDuration = Duration(milliseconds: 1000);

/// NOTE — constant-location resolution (implementation spec §5.1 vs. §1.2):
/// the spec originally placed `kStoryFetchTimeout` and `kStoryPoolTtl` in
/// this file. They instead live in `story_pool_repository.dart`, because
/// `StoryPoolRepository`/`RemoteOutcomeStoryService` need them at compile
/// time and this file is downstream of both. There is deliberately no
/// re-declaration here (that would create a duplicate/shadowing conflict) —
/// import them from `story_pool_repository.dart` if a future provider in
/// this file ever needs them directly.

/// The app's first-ever networking object (memory-safety M10): created once
/// per session and closed on dispose so a leaked client never holds an open
/// connection pool.
final Provider<http.Client> httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Session-scoped singleton owning the fetch/cache/fallback chain (spec
/// §2.4). Not `autoDispose`: both `storyPoolProvider`'s warm-up and every
/// `RemoteOutcomeStoryService.fetchStory` call share this one instance's
/// memoized `current`/`load()`.
final Provider<StoryPoolRepository> storyPoolRepositoryProvider =
    Provider<StoryPoolRepository>(
      (ref) => StoryPoolRepository(
        client: ref.watch(httpClientProvider),
        prefs: ref.watch(preferencesServiceProvider),
        endpoint: Uri.parse(kStoryConfigUrl),
      ),
    );

/// Session-scoped singleton owning the ID-keyed dedup-cycle state (spec
/// §2.5). Hydrates synchronously from prefs in its constructor.
final Provider<StoryCycleStore> storyCycleStoreProvider =
    Provider<StoryCycleStore>(
      (ref) => StoryCycleStore(ref.watch(preferencesServiceProvider)),
    );

/// App-lifetime pool warm-up + background refresh (options §9.1). Resolves
/// from cache/asset (fast, no network), THEN kicks off the network refresh
/// fire-and-forget so this Future is never gated on connectivity. Not
/// `autoDispose`: the pool must survive across screens or it would be
/// re-parsed on every navigation.
final FutureProvider<StoryPool> storyPoolProvider = FutureProvider<StoryPool>((
  ref,
) async {
  final repo = ref.watch(storyPoolRepositoryProvider);
  final pool = await repo.load();
  unawaited(
    repo.refreshIfStale(),
  ); // never awaited; swaps repo.current in place
  return pool;
});

/// Session-scoped, deliberately NOT `autoDispose` (architecture v4 §3): the
/// service instance — and its per-tier last-shown-index memory for the icon
/// pools — needs to live for the whole app session, the same lifetime
/// `outcomeRandomProvider`/`flavorSelectorProvider` had pre-redesign.
///
/// ONE-LINE SWAP (remote-story-config-implementation-spec §5.2): everything
/// downstream is untouched.
final Provider<OutcomeStoryService> outcomeStoryServiceProvider =
    Provider<OutcomeStoryService>(
      (ref) => RemoteOutcomeStoryService(
        repository: ref.watch(storyPoolRepositoryProvider),
        cycleStore: ref.watch(storyCycleStoreProvider),
      ),
    );

/// Resolves this run's fully-formed card content exactly once per
/// `RunSummary` instance (family-cached by object identity — the screen
/// holds the one `RunSummary` for its whole life, so rebuilds like the
/// share-toast appearing/disappearing never re-fetch or re-roll).
///
/// Completely unchanged by the remote-story-config feature (spec §5.2's
/// explicit note) — same `Future.wait` body, same family-identity caching.
/// It deliberately does NOT `ref.watch` `storyPoolProvider`: doing so would
/// rebuild every outcome card on a background refresh mid-session, which
/// options §9.1 explicitly forbids. Both this provider and `storyPoolProvider`
/// instead go through the shared `StoryPoolRepository` singleton (spec §5.3).
///
/// `autoDispose`'d: the screen watches continuously for its entire
/// lifetime, so no `ref.keepAlive()` is needed (architecture §3) — the
/// family entry is freed when the screen goes away (replaced by "Again" or
/// popped via "Home").
final outcomeStoryProvider = FutureProvider.autoDispose
    .family<OutcomeStoryContent, RunSummary>((ref, summary) async {
      // `content` is assigned from the real fetch's own typed `Future`, so
      // there's no untyped `List<Object?>` result to cast back out of —
      // `Future.wait` still runs both futures concurrently (the fetch and
      // the minimum-duration delay), it just no longer needs a shared
      // heterogeneous result list to do it.
      late final OutcomeStoryContent content;
      await Future.wait<void>([
        ref
            .watch(outcomeStoryServiceProvider)
            .fetchStory(summary)
            .then((c) => content = c),
        Future<void>.delayed(kMinStoryLoadDuration),
      ]);
      return content;
    });
