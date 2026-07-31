import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timing_tap/core/persistence/preferences_keys.dart';
import 'package:timing_tap/core/persistence/preferences_service.dart';
import 'package:timing_tap/features/outcome/application/story_pool_repository.dart';
import 'package:timing_tap/features/outcome/domain/story_pool_codec.dart';

/// Coverage for `StoryPoolRepository` (remote-story-config-implementation-
/// spec §2.4 / §9.4) — the fetch/cache/fallback chain. Uses `MockClient`
/// (`package:http/testing.dart`) and a real `PreferencesService` backed by
/// `SharedPreferences.setMockInitialValues` (this codebase's existing test
/// convention). No real network, no real disk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final endpoint = Uri.parse('https://example.test/stories.json');

  Future<PreferencesService> buildPrefs(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    return PreferencesService.create();
  }

  String payload({int contentVersion = 1, String idPrefix = 'death'}) {
    return jsonEncode({
      'schemaVersion': kStorySchemaVersion,
      'contentVersion': contentVersion,
      'updatedAt': '2026-07-31T00:00:00Z',
      'tiers': {
        'death': {
          'beats': [
            {
              'id': '${idPrefix}_001',
              'headline': 'H',
              'named': '{name} n',
              'anonymous': 'a',
            },
          ],
          // Deliberately ASCII, not real emoji: `http.Response`'s default
          // (non-UTF-8) `Encoding` can't roundtrip multi-byte characters,
          // and these tests aren't exercising icon *content* (that's
          // `story_pool_codec_test.dart`'s job) — only the repository's
          // fetch/cache/fallback plumbing.
          'icons': ['icon-death'],
        },
        'survived': {
          'beats': [
            {
              'id': 'survived_001',
              'headline': 'H',
              'named': '{name} n',
              'anonymous': 'a',
            },
          ],
          'icons': ['icon-survived'],
        },
        'eternal': {
          'beats': [
            {
              'id': 'eternal_001',
              'headline': 'H',
              'named': '{name} n',
              'anonymous': 'a',
            },
          ],
          'icons': ['icon-eternal'],
        },
      },
    });
  }

  StoryPoolRepository buildRepo({
    required PreferencesService prefs,
    required http.Client client,
    _FakeAssetBundle? bundle,
    DateTime Function()? now,
  }) {
    return StoryPoolRepository(
      client: client,
      prefs: prefs,
      endpoint: endpoint,
      bundle: bundle ?? _FakeAssetBundle(content: payload(idPrefix: 'bundled')),
      now: now,
    );
  }

  group('load() — offline first launch', () {
    test('empty cache + a throwing client -> returns the bundled pool, '
        'currentSource == bundled, never throws', () async {
      final prefs = await buildPrefs({});
      final throwingClient = MockClient(
        (_) async => throw const SocketException('no network'),
      );
      final bundle = _FakeAssetBundle(content: payload(idPrefix: 'bundled'));
      final repo = buildRepo(
        prefs: prefs,
        client: throwingClient,
        bundle: bundle,
      );

      final pool = await repo.load();

      expect(pool.death.beats.single.id, 'bundled_001');
      expect(repo.currentSource, StoryPoolSource.bundled);
      expect(bundle.evictCallCount, 1);
    });
  });

  group('load() — offline after cache', () {
    test('a valid cached payload + a throwing client -> returns the CACHED '
        'pool (not bundled), currentSource == cache', () async {
      final prefs = await buildPrefs({
        kKeyStoryPoolCache: payload(idPrefix: 'cached'),
      });
      final throwingClient = MockClient(
        (_) async => throw const SocketException('no network'),
      );
      final repo = buildRepo(prefs: prefs, client: throwingClient);

      final pool = await repo.load();

      expect(pool.death.beats.single.id, 'cached_001');
      expect(repo.currentSource, StoryPoolSource.cache);
    });
  });

  group('load() — corrupt cached payload', () {
    test('falls back to bundled AND clears all three cache keys', () async {
      final prefs = await buildPrefs({
        kKeyStoryPoolCache: 'not json',
        kKeyStoryPoolEtag: 'W/"stale"',
        kKeyStoryPoolFetchedAt: 12345,
      });
      final client = MockClient((_) async => http.Response('', 500));
      final repo = buildRepo(prefs: prefs, client: client);

      final pool = await repo.load();

      expect(pool.death.beats.single.id, 'bundled_001');
      expect(repo.currentSource, StoryPoolSource.bundled);
      expect(prefs.storyPoolCache, '');
      expect(prefs.storyPoolEtag, '');
      expect(prefs.storyPoolFetchedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('load() — bundled asset missing/corrupt', () {
    test(
      'installs StoryPool.empty, currentSource == none, never throws',
      () async {
        final prefs = await buildPrefs({});
        final client = MockClient((_) async => http.Response('', 500));
        final bundle = _FakeAssetBundle(shouldThrow: true);
        final repo = buildRepo(prefs: prefs, client: client, bundle: bundle);

        final pool = await repo.load();

        expect(pool.death.beats, isEmpty);
        expect(repo.currentSource, StoryPoolSource.none);
      },
    );
  });

  group('load() — single-flight', () {
    test(
      'two concurrent calls -> one asset read, identical returned instance',
      () async {
        final prefs = await buildPrefs({});
        final client = MockClient((_) async => http.Response('', 500));
        final bundle = _FakeAssetBundle(content: payload(idPrefix: 'bundled'));
        final repo = buildRepo(prefs: prefs, client: client, bundle: bundle);

        final future1 = repo.load();
        final future2 = repo.load();
        final pool1 = await future1;
        final pool2 = await future2;

        expect(identical(pool1, pool2), isTrue);
        expect(bundle.loadStringCallCount, 1);
      },
    );

    test('a call after success returns the same instance without re-reading '
        'the asset', () async {
      final prefs = await buildPrefs({});
      final client = MockClient((_) async => http.Response('', 500));
      final bundle = _FakeAssetBundle(content: payload(idPrefix: 'bundled'));
      final repo = buildRepo(prefs: prefs, client: client, bundle: bundle);

      final first = await repo.load();
      final second = await repo.load();

      expect(identical(first, second), isTrue);
      expect(bundle.loadStringCallCount, 1);
    });
  });

  group('refreshIfStale() — corrupt remote payload', () {
    test(
      'malformed JSON -> false, current unchanged, cache untouched',
      () async {
        final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
        final client = MockClient((_) async => http.Response('{', 200));
        final repo = buildRepo(prefs: prefs, client: client);
        await repo.load();

        final refreshed = await repo.refreshIfStale();

        expect(refreshed, isFalse);
        expect(prefs.storyPoolCache, '');
        expect(repo.currentSource, StoryPoolSource.bundled);
      },
    );
  });

  group('refreshIfStale() — schema mismatch', () {
    test(
      'schemaVersion: 2 -> false, cache untouched, current retained',
      () async {
        final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
        final mismatched = jsonEncode({
          'schemaVersion': 2,
          'contentVersion': 1,
          'tiers': <String, dynamic>{},
        });
        final client = MockClient((_) async => http.Response(mismatched, 200));
        final repo = buildRepo(prefs: prefs, client: client);
        final beforePool = await repo.load();

        final refreshed = await repo.refreshIfStale();

        expect(refreshed, isFalse);
        expect(prefs.storyPoolCache, '');
        expect(identical(repo.current, beforePool), isTrue);
      },
    );
  });

  group('refreshIfStale() — oversized payload', () {
    test('600 KB body -> rejected, current unchanged, nothing persisted; '
        'assert on byte length, not char count', () async {
      final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
      final hugeBody = 'a' * (600 * 1024);
      final client = MockClient((_) async => http.Response(hugeBody, 200));
      final repo = buildRepo(prefs: prefs, client: client);
      final beforePool = await repo.load();

      final refreshed = await repo.refreshIfStale();

      expect(refreshed, isFalse);
      expect(prefs.storyPoolCache, '');
      expect(prefs.storyPoolFetchedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(identical(repo.current, beforePool), isTrue);
    });
  });

  group('refreshIfStale() — 304 handling', () {
    test('a cached payload + ETag sends If-None-Match; a 304 leaves current '
        'IDENTICAL, updates fetchedAt only', () async {
      final prefs = await buildPrefs({
        kKeyStoryPoolCache: payload(idPrefix: 'cached'),
        kKeyStoryPoolEtag: 'W/"abc"',
        kKeyStoryPoolFetchedAt: 0,
      });
      http.Request? capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 304);
      });
      final repo = buildRepo(prefs: prefs, client: client);
      final beforePool = await repo.load();

      final refreshed = await repo.refreshIfStale();

      expect(capturedRequest!.headers['If-None-Match'], 'W/"abc"');
      expect(refreshed, isFalse);
      expect(identical(repo.current, beforePool), isTrue);
      expect(prefs.storyPoolFetchedAt.millisecondsSinceEpoch, greaterThan(0));
    });
  });

  group('refreshIfStale() — ETag capture', () {
    test(
      'a 200 with an ETag header persists it; the next call sends it',
      () async {
        final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
        final requests = <http.Request>[];
        var call = 0;
        final client = MockClient((request) async {
          requests.add(request);
          call++;
          if (call == 1) {
            // contentVersion 2, distinct from the fake bundle's default (1),
            // so this exercises ETag capture rather than tripping the
            // content-version short-circuit (covered by its own group below).
            return http.Response(
              payload(contentVersion: 2, idPrefix: 'remote'),
              200,
              headers: {'etag': 'W/"first"'},
            );
          }
          return http.Response('', 304);
        });
        // Starts already past the TTL (fetchedAt defaults to epoch 0) so the
        // first `refreshIfStale` actually reaches the network.
        final now = _MutableClock(
          DateTime.fromMillisecondsSinceEpoch(0).add(const Duration(hours: 7)),
        );
        final repo = buildRepo(
          prefs: prefs,
          client: client,
          now: () => now.value,
        );
        await repo.load();

        final firstRefresh = await repo.refreshIfStale();
        expect(firstRefresh, isTrue);
        expect(prefs.storyPoolEtag, 'W/"first"');

        now.value = now.value.add(const Duration(hours: 7));
        await repo.refreshIfStale();

        expect(requests[1].headers['If-None-Match'], 'W/"first"');
      },
    );
  });

  group('refreshIfStale() — TTL', () {
    test('within kStoryPoolTtl -> no HTTP call at all; past it -> exactly '
        'one', () async {
      var callCount = 0;
      final client = MockClient((_) async {
        callCount++;
        return http.Response('', 500);
      });
      final now = _MutableClock(DateTime.fromMillisecondsSinceEpoch(0));
      final prefs = await buildPrefs({
        kKeyStoryPoolFetchedAt: now.value.millisecondsSinceEpoch,
      });
      final repo = buildRepo(
        prefs: prefs,
        client: client,
        now: () => now.value,
      );

      // Still within the TTL.
      now.value = now.value.add(const Duration(hours: 1));
      await repo.refreshIfStale();
      expect(callCount, 0);

      // Past the TTL.
      now.value = now.value.add(const Duration(hours: 6));
      await repo.refreshIfStale();
      expect(callCount, 1);
    });
  });

  group('refreshIfStale() — non-200', () {
    test('404 -> false, fetchedAt NOT written', () async {
      final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
      final client = MockClient((_) async => http.Response('not found', 404));
      final repo = buildRepo(prefs: prefs, client: client);

      final refreshed = await repo.refreshIfStale();

      expect(refreshed, isFalse);
      expect(prefs.storyPoolFetchedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('500 -> false, fetchedAt NOT written', () async {
      final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
      final client = MockClient((_) async => http.Response('boom', 500));
      final repo = buildRepo(prefs: prefs, client: client);

      final refreshed = await repo.refreshIfStale();

      expect(refreshed, isFalse);
      expect(prefs.storyPoolFetchedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('refreshIfStale() — timeout', () {
    test('a client that never completes -> .timeout fires at 4s, false, '
        'no throw', () async {
      final prefs = await buildPrefs({kKeyStoryPoolFetchedAt: 0});
      final neverCompletes = Completer<http.Response>();
      final client = MockClient((_) => neverCompletes.future);
      final repo = buildRepo(prefs: prefs, client: client);

      fakeAsync((async) {
        bool? result;
        Object? error;
        repo.refreshIfStale().then((r) => result = r).catchError((e) {
          error = e;
          return false;
        });

        async.elapse(const Duration(seconds: 5));

        expect(result, isFalse);
        expect(error, isNull);
      });
    });
  });

  group('refreshIfStale() — content-version short-circuit', () {
    test('a 200 with the same contentVersion as current -> false, current '
        'identity unchanged', () async {
      final prefs = await buildPrefs({
        kKeyStoryPoolCache: payload(contentVersion: 5, idPrefix: 'cached'),
        kKeyStoryPoolFetchedAt: 0,
      });
      final client = MockClient(
        (_) async =>
            http.Response(payload(contentVersion: 5, idPrefix: 'remote'), 200),
      );
      final repo = buildRepo(prefs: prefs, client: client);
      final beforePool = await repo.load();

      final refreshed = await repo.refreshIfStale();

      expect(refreshed, isFalse);
      expect(identical(repo.current, beforePool), isTrue);
    });

    test(
      'a 200 with a DIFFERENT contentVersion installs the new pool',
      () async {
        final prefs = await buildPrefs({
          kKeyStoryPoolCache: payload(contentVersion: 5, idPrefix: 'cached'),
          kKeyStoryPoolFetchedAt: 0,
        });
        final client = MockClient(
          (_) async => http.Response(
            payload(contentVersion: 6, idPrefix: 'remote'),
            200,
          ),
        );
        final repo = buildRepo(prefs: prefs, client: client);
        final beforePool = await repo.load();

        final refreshed = await repo.refreshIfStale();

        expect(refreshed, isTrue);
        expect(identical(repo.current, beforePool), isFalse);
        expect(repo.current!.death.beats.single.id, 'remote_001');
        expect(repo.currentSource, StoryPoolSource.remote);
      },
    );
  });
}

/// Minimal `AssetBundle` fake — only `loadString`/`evict` are exercised by
/// `StoryPoolRepository`.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle({this.content, this.shouldThrow = false});

  final String? content;
  final bool shouldThrow;
  int loadStringCallCount = 0;
  int evictCallCount = 0;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError('StoryPoolRepository only calls loadString/evict');
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadStringCallCount++;
    if (shouldThrow) {
      throw Exception('asset not found: $key');
    }
    return content!;
  }

  @override
  void evict(String key) {
    evictCallCount++;
  }
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
}
