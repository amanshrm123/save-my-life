import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/outcome/application/remote_outcome_story_service.dart';
import 'package:timing_tap/features/outcome/application/story_cycle_store.dart';
import 'package:timing_tap/features/outcome/application/story_pool_repository.dart';
import 'package:timing_tap/features/outcome/domain/outcome_story_content.dart';
import 'package:timing_tap/features/outcome/domain/story_beat.dart';
import 'package:timing_tap/features/outcome/domain/story_pool.dart';
import 'package:timing_tap/features/outcome/domain/story_pool_codec.dart';
import 'package:timing_tap/features/play_loop/domain/run_state.dart';
import 'package:timing_tap/features/play_loop/domain/run_summary.dart';

/// Coverage for `RemoteOutcomeStoryService` (remote-story-config-
/// implementation-spec §2.6 / §9.5) — renamed + extended from
/// `local_outcome_story_service_test.dart`. All four existing groups from
/// that file port over against a stub `StoryPoolRepository` returning a
/// fixture pool (rather than the deleted compile-time beat/icon pools),
/// since that behaviour survives verbatim: per-tier independence,
/// `forceFailure` inertness, icon/beat independence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  StoryBeat beat(String id) => StoryBeat(
    id: id,
    headline: 'Headline $id',
    named: '{name} $id',
    anonymous: 'Anon $id',
  );

  StoryTierPool tierOf(
    int beatCount,
    int iconCount, {
    String prefix = 'death',
  }) {
    return StoryTierPool(
      beats: List.generate(
        beatCount,
        (i) => beat('${prefix}_${i.toString().padLeft(3, '0')}'),
      ),
      icons: List.generate(iconCount, (i) => '$prefix-icon-$i'),
    );
  }

  StoryPool fixturePool({
    int contentVersion = 1,
    int deathBeats = 60,
    int survivedBeats = 60,
    int eternalBeats = 60,
    int deathIcons = 6,
    int survivedIcons = 5,
    int eternalIcons = 4,
  }) {
    return StoryPool(
      contentVersion: contentVersion,
      death: tierOf(deathBeats, deathIcons, prefix: 'death'),
      survived: tierOf(survivedBeats, survivedIcons, prefix: 'survived'),
      eternal: tierOf(eternalBeats, eternalIcons, prefix: 'eternal'),
    );
  }

  /// Builds a `StoryPoolRepository` whose `current`/`load` resolve to
  /// [pool] without touching real network or disk — the "stub
  /// `StoryPoolRepository`" the spec's R2 rationale describes.
  Future<StoryPoolRepository> stubRepository(
    StoryPool pool, {
    http.Client? client,
    DateTime Function()? now,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    final bundle = _FixtureAssetBundle(pool);
    final repo = StoryPoolRepository(
      client: client ?? MockClient((_) async => http.Response('', 404)),
      prefs: prefs,
      endpoint: Uri.parse('https://example.test/stories.json'),
      bundle: bundle,
      now: now,
    );
    await repo.load();
    return repo;
  }

  Future<_CountingStoryCycleStore> counterStore() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    return _CountingStoryCycleStore(prefs);
  }

  group('repeat-avoidance — icon never repeats back-to-back, per tier, '
      'independently (options §8.5, unchanged)', () {
    for (final outcome in RunOutcome.values) {
      test('$outcome: across many consecutive fetches, the icon never '
          'repeats back-to-back', () async {
        final repo = await stubRepository(fixturePool());
        final service = RemoteOutcomeStoryService(
          repository: repo,
          cycleStore: await counterStore(),
          random: Random(1),
        );
        final summary = summaryFor(outcome);

        String? prevIcon;
        for (var i = 0; i < 200; i++) {
          final content = await service.fetchStory(summary);
          if (prevIcon != null) {
            expect(
              content.icon,
              isNot(prevIcon),
              reason:
                  '$outcome: fetch #$i repeated the immediately-previous icon',
            );
          }
          prevIcon = content.icon;
        }
      });
    }
  });

  group('beat repeat-avoidance is now the cycle guarantee', () {
    test(
      'over pool.length consecutive death fetches, all beats are distinct',
      () async {
        final pool = fixturePool(deathBeats: 40);
        final repo = await stubRepository(pool);
        final service = RemoteOutcomeStoryService(
          repository: repo,
          cycleStore: await counterStore(),
          random: Random(2),
        );
        final summary = summaryFor(RunOutcome.death);

        final headlines = <String>{};
        for (var i = 0; i < 40; i++) {
          final content = await service.fetchStory(summary);
          headlines.add(content.headline);
        }
        expect(
          headlines.length,
          40,
          reason: 'all 40 beats must have been shown exactly once',
        );
      },
    );
  });

  group('per-tier tracking is independent — one tier\'s history never '
      'affects another\'s state', () {
    test('interleaving fetches for a different tier does not disturb a '
        'given tier\'s own icon avoidance', () async {
      final repo = await stubRepository(fixturePool());
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(2),
      );
      final death = summaryFor(RunOutcome.death);
      final survived = summaryFor(RunOutcome.survived);

      String? prevDeathIcon;
      for (var i = 0; i < 60; i++) {
        // Interleave an unrelated tier's fetch in between every death fetch.
        await service.fetchStory(survived);

        final content = await service.fetchStory(death);
        if (prevDeathIcon != null) {
          expect(content.icon, isNot(prevDeathIcon));
        }
        prevDeathIcon = content.icon;
      }
    });

    test('beat selection and icon selection vary independently across '
        'trials', () async {
      final repo = await stubRepository(fixturePool());
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(3),
      );
      final summary = summaryFor(RunOutcome.death);

      final headlines = <String>{};
      final icons = <String>{};
      for (var i = 0; i < 100; i++) {
        final content = await service.fetchStory(summary);
        headlines.add(content.headline);
        icons.add(content.icon);
      }
      expect(headlines.length, greaterThan(5));
      expect(icons.length, greaterThan(1));
    });
  });

  group('forceFailure', () {
    test('returns OutcomeStoryContent.naFor exactly, for every tier', () async {
      for (final outcome in RunOutcome.values) {
        final repo = await stubRepository(fixturePool());
        final service = RemoteOutcomeStoryService(
          repository: repo,
          cycleStore: await counterStore(),
          random: Random(4),
        )..forceFailure = true;
        final content = await service.fetchStory(summaryFor(outcome));
        expect(content, OutcomeStoryContent.naFor);
        expect(content.isFallback, isTrue);
      }
    });

    test('does NOT mutate any cycle-store state, nor consume any Random '
        'draws — verified behaviorally by comparing an identically-seeded '
        'service that never calls forceFailure against one that has '
        'several forced-failure calls spliced in between real fetches; '
        'both must produce byte-identical subsequent picks', () async {
      final summary = summaryFor(RunOutcome.death);
      final pool = fixturePool();

      final baselineRepo = await stubRepository(pool);
      final baseline = RemoteOutcomeStoryService(
        repository: baselineRepo,
        cycleStore: await counterStore(),
        random: Random(123),
      );
      final first = await baseline.fetchStory(summary);
      final second = await baseline.fetchStory(summary);
      final third = await baseline.fetchStory(summary);

      final withForcedFailuresRepo = await stubRepository(pool);
      final withForcedFailures = RemoteOutcomeStoryService(
        repository: withForcedFailuresRepo,
        cycleStore: await counterStore(),
        random: Random(123),
      );
      final firstB = await withForcedFailures.fetchStory(summary);
      withForcedFailures.forceFailure = true;
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
        reason:
            'a forced failure must not have consumed a Random draw or '
            'updated cycle state — the next real fetch must pick exactly '
            'what it would have picked with no forced failures in between',
      );
      expect(secondB.icon, second.icon);
      expect(thirdB.headline, third.headline);
      expect(thirdB.icon, third.icon);
    });

    test('a forced failure between two real fetches for the SAME tier does '
        'not corrupt the next real fetch\'s icon avoidance', () async {
      final repo = await stubRepository(fixturePool());
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(9),
      );
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

  group('pruneAgainst is called exactly once per installed pool', () {
    test('once across 20 fetches against a stable pool, and once more '
        'after the repository hot-swaps to a new pool instance', () async {
      final poolA = fixturePool(contentVersion: 1);
      final poolB = fixturePool(contentVersion: 2);

      // A mutable clock + client so `refreshIfStale` can be driven directly
      // (real fetch/cache/swap mechanics), simulating a background refresh
      // landing mid-session — `RemoteOutcomeStoryService` never talks to
      // the network itself, only ever reads `repository.current`.
      var serveNewPool = false;
      final client = MockClient((_) async {
        if (!serveNewPool) return http.Response('', 404);
        return http.Response(StoryPoolCodec.encode(poolB), 200);
      });
      // Starts already past the TTL so the first `refreshIfStale` call
      // actually reaches the network instead of no-op'ing.
      final clock = _MutableClock(
        DateTime.fromMillisecondsSinceEpoch(0).add(const Duration(hours: 7)),
      );

      final repo = await stubRepository(
        poolA,
        client: client,
        now: () => clock.value,
      );
      final store = await counterStore();
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: store,
        random: Random(5),
      );
      final summary = summaryFor(RunOutcome.death);

      for (var i = 0; i < 20; i++) {
        await service.fetchStory(summary);
      }
      expect(store.pruneCallCount, 1);

      // Hot-swap: flip the mock server to serve a genuinely different pool
      // and advance the clock past the TTL again, then trigger the swap.
      serveNewPool = true;
      clock.value = clock.value.add(const Duration(hours: 7));
      final swapped = await repo.refreshIfStale();
      expect(swapped, isTrue);

      await service.fetchStory(summary);
      expect(store.pruneCallCount, 2);

      // Further fetches against the swapped-in pool must not re-trigger
      // pruning again.
      for (var i = 0; i < 5; i++) {
        await service.fetchStory(summary);
      }
      expect(store.pruneCallCount, 2);
    });
  });

  group('an empty tier yields naFor for that tier only', () {
    test('the other two tiers still resolve normally', () async {
      final pool = StoryPool(
        contentVersion: 1,
        death: tierOf(10, 6, prefix: 'death'),
        survived: const StoryTierPool(beats: [], icons: ['icon']),
        eternal: tierOf(6, 4, prefix: 'eternal'),
      );
      final repo = await stubRepository(pool);
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(6),
      );

      final survivedContent = await service.fetchStory(
        summaryFor(RunOutcome.survived),
      );
      expect(survivedContent, OutcomeStoryContent.naFor);

      final deathContent = await service.fetchStory(
        summaryFor(RunOutcome.death),
      );
      expect(deathContent.isFallback, isFalse);
      expect(deathContent.headline, isNot('N/A'));

      final eternalContent = await service.fetchStory(
        summaryFor(RunOutcome.eternal),
      );
      expect(eternalContent.isFallback, isFalse);
      expect(eternalContent.headline, isNot('N/A'));
    });

    // NEW: the test above only calls the empty tier ONCE, which can't rule
    // out a one-shot fluke (e.g. a bug that only degrades correctly on the
    // very first `fetchStory` call, or an off-by-one that would surface on
    // a second call against the same, already-pruned pool instance). This
    // repeats the empty tier many times, interleaved with real fetches
    // against the other two tiers, all against the SAME service/repository
    // instance, and asserts every single empty-tier call -- not just the
    // first -- degrades to naFor while the other two keep working.
    test('the empty tier keeps yielding naFor on every call, not just the '
        'first, while the other two tiers keep working normally across '
        'many interleaved calls on the SAME service instance', () async {
      final pool = StoryPool(
        contentVersion: 1,
        death: tierOf(10, 6, prefix: 'death'),
        survived: const StoryTierPool(beats: [], icons: ['icon']),
        eternal: tierOf(6, 4, prefix: 'eternal'),
      );
      final repo = await stubRepository(pool);
      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(7),
      );

      for (var i = 0; i < 15; i++) {
        final survivedContent = await service.fetchStory(
          summaryFor(RunOutcome.survived),
        );
        expect(
          survivedContent,
          OutcomeStoryContent.naFor,
          reason:
              'survived call #$i must degrade to naFor, not just the '
              'first call',
        );

        final deathContent = await service.fetchStory(
          summaryFor(RunOutcome.death),
        );
        expect(deathContent.isFallback, isFalse);
        expect(deathContent.headline, isNot('N/A'));

        final eternalContent = await service.fetchStory(
          summaryFor(RunOutcome.eternal),
        );
        expect(eternalContent.isFallback, isFalse);
        expect(eternalContent.headline, isNot('N/A'));
      }
    });
  });

  group('remote fetch success path renders real content end-to-end', () {
    // Neither this file's `stubRepository` helper nor
    // `story_pool_repository_test.dart`'s 200-response cases ever push a
    // genuine 200 payload all the way through to a rendered
    // `OutcomeStoryContent` -- `stubRepository` seeds `current` only via the
    // bundled-asset path (client defaults to a 404 `MockClient`), and the
    // repository tests stop at asserting on `repo.current`/`currentSource`,
    // never on `RemoteOutcomeStoryService`'s output. Every integration test
    // in `test/integration/` also overrides `httpClientProvider` with a
    // 404-only `MockClient` (see `support/app_harness.dart`), so the
    // successful-fetch path is otherwise completely unexercised end-to-end.
    // This proves it: a `MockClient` 200 response with real JSON installs via
    // `refreshIfStale`, and `RemoteOutcomeStoryService.fetchStory` renders
    // that pool's actual content (not naFor, not the bundled pool's content).
    test('a MockClient 200 response with real JSON is installed via '
        'refreshIfStale and rendered correctly by fetchStory', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();
      final bundledPool = fixturePool(contentVersion: 1);
      final remotePool = StoryPool(
        contentVersion: 2,
        death: const StoryTierPool(
          beats: [
            StoryBeat(
              id: 'death_remote_001',
              headline: 'Remote headline, peak {peak}',
              named: '{name} lived the remote story',
              anonymous: 'Anon lived the remote story',
            ),
          ],
          icons: ['R'],
        ),
        survived: tierOf(5, 3, prefix: 'survived'),
        eternal: tierOf(5, 3, prefix: 'eternal'),
      );

      final clock = _MutableClock(
        DateTime.fromMillisecondsSinceEpoch(0).add(const Duration(hours: 7)),
      );
      final client = MockClient(
        (_) async => http.Response(StoryPoolCodec.encode(remotePool), 200),
      );
      final repo = StoryPoolRepository(
        client: client,
        prefs: prefs,
        endpoint: Uri.parse('https://example.test/stories.json'),
        bundle: _FixtureAssetBundle(bundledPool),
        now: () => clock.value,
      );

      // Cold start: resolves from the bundled asset, no network involved.
      await repo.load();
      expect(repo.currentSource, StoryPoolSource.bundled);

      // Background refresh: a genuine 200 with real JSON swaps it in.
      final swapped = await repo.refreshIfStale();
      expect(swapped, isTrue);
      expect(repo.currentSource, StoryPoolSource.remote);

      final service = RemoteOutcomeStoryService(
        repository: repo,
        cycleStore: await counterStore(),
        random: Random(42),
      );
      final content = await service.fetchStory(summaryFor(RunOutcome.death));

      expect(content, isNot(OutcomeStoryContent.naFor));
      expect(content.isFallback, isFalse);
      expect(content.headline, contains('Remote headline'));
      // `{peak}` substituted by `StoryRenderer` from `RunSummary.peakLifePercent`
      // (77 in `summaryFor`).
      expect(content.headline, contains('77'));
      expect(content.storyNamed, contains('remote story'));
      expect(content.storyAnonymous, contains('remote story'));
      expect(content.icon, 'R');
    });
  });
}

/// Minimal `AssetBundle` fake that serves one fixture `StoryPool`, encoded
/// through the real `StoryPoolCodec` — so `StoryPoolRepository.load()`
/// installs it exactly as it would install a real bundled asset.
class _FixtureAssetBundle extends AssetBundle {
  _FixtureAssetBundle(this.pool);

  final StoryPool pool;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return StoryPoolCodec.encode(pool);
  }
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
}

class _CountingStoryCycleStore extends StoryCycleStore {
  _CountingStoryCycleStore(super.prefs);

  int pruneCallCount = 0;

  @override
  void pruneAgainst(StoryPool pool) {
    pruneCallCount++;
    super.pruneAgainst(pool);
  }
}
