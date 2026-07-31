import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/persistence/preferences_service.dart';
import '../domain/story_pool.dart';
import '../domain/story_pool_codec.dart';

/// The bundled fallback asset path (a real Flutter asset — see
/// `pubspec.yaml`'s `flutter: assets:` entry).
const String kBundledStoryAsset = 'assets/stories_bundled.json';

/// Caps the HTTP round trip in [StoryPoolRepository.refreshIfStale] and the
/// (disk-only, normally sub-10ms) [StoryPoolRepository.load] that
/// `fetchStory` falls back on if the card is somehow reached before the
/// pool is warm.
///
/// NOTE for the integrator wiring the provider graph: `outcome_providers.dart`
/// (spec §5.1) declares a same-named, same-valued constant for provider-layer
/// callers (e.g. `RemoteOutcomeStoryService.fetchStory`'s own `.timeout(...)`
/// on `repository.load()`). Import this one rather than redeclaring, to keep
/// a single source of truth and avoid a duplicate-declaration conflict.
const Duration kStoryFetchTimeout = Duration(seconds: 4);

/// Minimum interval between network refreshes.
///
/// Same integrator note as [kStoryFetchTimeout] applies.
const Duration kStoryPoolTtl = Duration(hours: 1);

/// Where the currently-installed [StoryPool] came from (R6). Not read by any
/// UI or provider today; exists so a future analytics hook has a clean,
/// unambiguous thing to read without overloading
/// `OutcomeStoryContent.isFallback`.
enum StoryPoolSource { remote, cache, bundled, none }

/// Owns the whole fetch/cache/fallback chain for the outcome-story content
/// pool (remote-story-config-implementation-spec §2.4). Knows nothing about
/// dedup, selection, or rendering — see `StoryCycleStore` /
/// `RemoteOutcomeStoryService` for those.
class StoryPoolRepository {
  StoryPoolRepository({
    required http.Client client,
    required PreferencesService prefs,
    required Uri endpoint,
    AssetBundle? bundle,
    DateTime Function()? now,
  }) : _client = client,
       _prefs = prefs,
       _endpoint = endpoint,
       _bundle = bundle ?? rootBundle,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final PreferencesService _prefs;
  final Uri _endpoint;
  final AssetBundle _bundle;
  final DateTime Function() _now;

  StoryPool? _current;
  StoryPoolSource _currentSource = StoryPoolSource.none;
  Future<StoryPool>? _inFlight;

  /// The installed pool, or `null` before the first [load] completes.
  StoryPool? get current => _current;

  /// Where [current] came from. `StoryPoolSource.none` before the first
  /// [load] completes.
  StoryPoolSource get currentSource => _currentSource;

  /// Cold-start resolution: cached-prefs-string -> bundled asset -> empty.
  /// Memoized and single-flight: concurrent callers share one Future, and a
  /// second call after success returns the same [StoryPool] instance.
  /// **Never throws.**
  ///
  /// Deliberately NOT `async` itself — the single-flight guard (memory-
  /// safety M11) requires `_inFlight` to be assigned before this function
  /// yields control back to the event loop even once, which a plain
  /// (non-`async`) function returning a `Future` guarantees: everything up
  /// to and including the `_inFlight = ...` assignment runs synchronously,
  /// so two back-to-back synchronous callers can never both observe
  /// `_inFlight == null`.
  ///
  /// The clear-out is done here via `.whenComplete`, registered
  /// **immediately after** `_inFlight` is assigned, rather than inside
  /// `_loadInternal` itself. That matters on the warm/cache-hit path: when
  /// the cache decodes cleanly, `_loadInternal`'s body never reaches an
  /// `await`, so Dart runs it to completion fully synchronously — if it
  /// nulled out `_inFlight` itself, that null-out would happen *before*
  /// this method's own `_inFlight = future` assignment even executes,
  /// leaving `_inFlight` pointing at a stale, already-completed `Future`
  /// for the rest of the session. Registering `.whenComplete` after the
  /// assignment guarantees the clear-out always runs strictly after it
  /// (as a microtask, even for an already-completed `Future`), on both the
  /// synchronous (warm) and asynchronous (cold) paths.
  Future<StoryPool> load() {
    if (_current != null) return Future.value(_current!);
    if (_inFlight != null) return _inFlight!;

    final future = _loadInternal();
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<StoryPool> _loadInternal() async {
    StoryPool? pool;
    StoryPoolSource source = StoryPoolSource.none;

    final cached = _prefs.storyPoolCache;
    if (cached.isNotEmpty) {
      try {
        pool = StoryPoolCodec.decode(cached);
        source = StoryPoolSource.cache;
      } catch (_) {
        // A poisoned cache (e.g. written by a since-rolled-back app version
        // under a schema this build rejects) must not be re-read every
        // launch.
        await _prefs.setStoryPoolCache('');
        await _prefs.setStoryPoolEtag('');
        await _prefs.setStoryPoolFetchedAt(
          DateTime.fromMillisecondsSinceEpoch(0),
        );
      }
    }

    if (pool == null) {
      try {
        final raw = await _bundle.loadString(kBundledStoryAsset);
        // Memory-safety M3: rootBundle is a CachingAssetBundle and would
        // otherwise hold the raw ~24 KB string alive for the process
        // lifetime for no reason. Evict immediately after a successful
        // load, regardless of whether decode below succeeds.
        _bundle.evict(kBundledStoryAsset);
        pool = StoryPoolCodec.decode(raw);
        source = StoryPoolSource.bundled;
      } catch (_) {
        pool = StoryPool.empty;
        source = StoryPoolSource.none;
      }
    }

    _current = pool;
    _currentSource = source;
    // NOTE: `_inFlight` is deliberately NOT nulled out here — see `load()`'s
    // doc comment for why that would race the caller's own assignment on
    // the fully-synchronous (warm/cache-hit) path. `load()` clears it via
    // `.whenComplete` instead.
    return pool;
  }

  /// Network refresh. No-op if within [kStoryPoolTtl] of the last
  /// successful fetch. **Never throws.** Returns `true` iff [current] was
  /// swapped.
  Future<bool> refreshIfStale() async {
    try {
      final sinceLastFetch = _now().difference(_prefs.storyPoolFetchedAt);
      // A negative duration means the device clock moved backward relative
      // to the previously-recorded `fetchedAt` (manual date change, bad NTP
      // correction). Trusting it as-is would always compare less than
      // `kStoryPoolTtl` and permanently suppress refresh until real time
      // caught back up to the skewed timestamp — treat it as stale instead.
      if (!sinceLastFetch.isNegative && sinceLastFetch < kStoryPoolTtl) {
        return false;
      }

      final etag = _prefs.storyPoolEtag;
      final response = await _client
          .get(_endpoint, headers: {if (etag.isNotEmpty) 'If-None-Match': etag})
          .timeout(kStoryFetchTimeout);

      if (response.statusCode == 304) {
        // Success path. No decode, no swap.
        await _prefs.setStoryPoolFetchedAt(_now());
        return false;
      }

      if (response.statusCode != 200) {
        // Deliberately not writing `fetchedAt` — a 5xx should be retried on
        // the next app start, not suppressed for `kStoryPoolTtl`.
        return false;
      }

      // Memory-safety M4: checked on bodyBytes.length, BEFORE any UTF-8
      // decode to String, so an oversized payload is never materialised as
      // a Dart string.
      if (response.bodyBytes.length > kStoryPoolMaxBytes) {
        return false;
      }

      // `raw` is a local; it goes out of scope after the prefs write below
      // and is never retained on any Dart object *of ours* (memory-safety
      // M2, as far as this class's own fields go). It IS, however, retained
      // for the rest of the process lifetime inside `shared_preferences`'
      // own internal cache once written below — that plugin holds every
      // key/value it has ever set in a process-lifetime Dart map. This is a
      // known, accepted consequence of choosing `shared_preferences` for
      // this cache (a deliberate choice, not revisited here); `kStoryPoolMaxBytes`
      // bounds the SIZE of that resident copy, not the fact that it's
      // resident.
      final raw = utf8.decode(response.bodyBytes);
      final StoryPool pool;
      try {
        pool = StoryPoolCodec.decode(raw);
      } on StoryPoolFormatException {
        // Decode-before-persist: a payload that failed to parse never
        // reaches the cache.
        return false;
      }

      // Only now, after a successful decode: persist. This is the
      // invariant that makes the cache read in `load()` almost always
      // succeed — the cache only ever contains a payload this exact client
      // version has already parsed successfully.
      await _prefs.setStoryPoolCache(raw);
      await _prefs.setStoryPoolEtag(response.headers['etag'] ?? '');
      await _prefs.setStoryPoolFetchedAt(_now());

      if (_current != null &&
          pool.contentVersion == _current!.contentVersion &&
          _current!.contentVersion != 0) {
        // options §8.6 "don't bother re-installing" short-circuit. Keeps
        // `_current`'s object identity stable so the prune trigger in
        // `RemoteOutcomeStoryService` doesn't refire.
        return false;
      }

      _current = pool;
      _currentSource = StoryPoolSource.remote;
      return true;
    } catch (_) {
      return false;
    }
  }
}
