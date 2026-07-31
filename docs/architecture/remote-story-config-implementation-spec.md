# Remote Story Config — Implementation Spec

**Status:** Authoritative build spec. Founder has picked **Option A** (static JSON on a CDN,
plain HTTP GET) from `remote-story-config-options.md` §7 Phase 1. Nothing in the two source docs
is re-litigated here.
**Date:** 2026-07-31
**Reads as the single source of truth for:** flutter-developer (build directly from this),
tester (§8), game-ux-designer (§2.6 loading floor), compliance/store reviewers (§9).

**Source docs (both approved, both assumed read):**
- `docs/architecture/remote-story-config-options.md` — product/cost, JSON schema (§8.6), dedup
  algorithm (§8.3), prefs keys (§8.2), loading timing (§9).
- `docs/architecture/remote-story-config-technical-notes.md` — adapter sketch (§5), caching
  recommendation (§6).

Where the two docs conflict or are silent, **this doc decides**, and says so explicitly under a
`> **Resolution.**` callout. There are seven such resolutions: R1–R7.

---

## 0. Scope, at a glance

| | |
|---|---|
| **In scope** | Client-side fetch/cache/fallback of outcome-card story content; ID-keyed dedup-until-exhausted; the seed `stories.json`; the bundled fallback asset; `http` dependency; INTERNET permission. |
| **Out of scope (deferred)** | The Google Sheet + GitHub Action publish pipeline (options §5 "Phase 2" — **zero client changes when it lands**). Any analytics on `isFallback`. Any error UI, retry button, or offline banner (options §9.3 — deliberately none). Per-user/segmented content. iOS anything (standing no-Apple-ID constraint). |
| **Hosting** | **Not provisioned.** The endpoint is a single documented constant the founder points at their own host. See §3. The client build does **not** block on hosting being live — with no reachable URL the app runs entirely off the bundled asset and behaves correctly. |

---

## 1. File-by-file plan

### 1.1 New files

| Path | Kind | Purpose |
|---|---|---|
| `assets/stories_bundled.json` | **generated content (already written)** | The compiled-in fallback pool. Real Flutter asset. §4. |
| `tools/story-content/stories.json` | **generated content (already written)** | The upload artifact / canonical editable source. **Not** a Flutter asset. §3.3. |
| `tools/story-content/README.md` | doc | How to edit + upload; the emoji-safety rationale rescued from the deleted `story_icons.dart`. Content dictated in §3.4. |
| `lib/features/outcome/domain/story_pool.dart` | Dart | `StoryPool` + `StoryTierPool` immutable value objects. §2.1. |
| `lib/features/outcome/domain/story_pool_codec.dart` | Dart | `StoryPoolCodec.decode(String) -> StoryPool`, `StoryPoolFormatException`. **The one and only parse path.** §2.2. |
| `lib/features/outcome/domain/story_cycle_selector.dart` | Dart | `StoryCycleSelector` — options §8.3's algorithm, pure. §2.3. |
| `lib/features/outcome/application/story_config_endpoint.dart` | Dart | The `kStoryConfigUrl` placeholder constant, alone in its own file. §3.1. |
| `lib/features/outcome/application/story_pool_repository.dart` | Dart | Fetch/cache/fallback chain, ETag, TTL, single-flight load. §2.4. |
| `lib/features/outcome/application/story_cycle_store.dart` | Dart | In-memory seen-sets + last-shown IDs, write-through to prefs, `pruneAgainst(pool)`. §2.5. |
| `lib/features/outcome/application/remote_outcome_story_service.dart` | Dart | `RemoteOutcomeStoryService implements OutcomeStoryService`. §2.6. |

### 1.2 Modified files

| Path | Change |
|---|---|
| `lib/features/outcome/domain/story_beat.dart` | Add `final String id`; add `StoryBeat.fromJson` / `toJson`. §2.1. |
| `lib/features/outcome/domain/story_renderer.dart` | `render()` must thread `id: beat.id` through the `StoryBeat` it constructs (it currently drops every field it doesn't rewrite — with `id` required, this is a compile error until fixed; call it out so it isn't "fixed" by making `id` optional). |
| `lib/features/outcome/domain/story_selector.dart` | **No logic change**, one safety guard: return `null`-safe / assert on empty pool — see §2.3's empty-pool rule. Doc comment updated to say it now serves icons only. |
| `lib/features/outcome/state/outcome_providers.dart` | New constants, `httpClientProvider`, `storyPoolRepositoryProvider`, `storyCycleStoreProvider`, `storyPoolProvider`; one-line `outcomeStoryServiceProvider` swap; `kMinStoryLoadDuration` 2s → 1200ms. §5. |
| `lib/core/persistence/preferences_keys.dart` | Nine new keys; `kPrefsSchemaVersion` 1 → 2. §6. |
| `lib/core/persistence/preferences_service.dart` | Nine getter/setter pairs, in the file's exact existing try/catch shape. §6. |
| `lib/features/onboarding/presentation/splash_screen.dart` | One fire-and-forget line to warm `storyPoolProvider`. §5.4. |
| `pubspec.yaml` | `http: ^1.5.0` dependency; `assets/stories_bundled.json` under `flutter: assets:`. §9. |
| `android/app/src/main/AndroidManifest.xml` | Add `android.permission.INTERNET`. §9.2 — **flagged for compliance review.** |

### 1.3 Deleted files

| Path | Why |
|---|---|
| `lib/features/outcome/domain/death_beats.dart` | Content moves to `assets/stories_bundled.json`. R1 (§4). |
| `lib/features/outcome/domain/survived_beats.dart` | ditto |
| `lib/features/outcome/domain/eternal_beats.dart` | ditto |
| `lib/features/outcome/domain/story_icons.dart` | Icon pools move into the payload (options §8.5 "do ship the icon arrays in the remote payload"). Its emoji-safety doc comments are **not** lost — they move verbatim to `tools/story-content/README.md`, which is where someone about to change an emoji will actually be looking. |
| `lib/features/outcome/application/local_outcome_story_service.dart` | Fully absorbed by `RemoteOutcomeStoryService`. R2 (§2.6). |

### 1.4 Test files

| Path | Change |
|---|---|
| `test/features/outcome/application/local_outcome_story_service_test.dart` | **Renamed** → `remote_outcome_story_service_test.dart`; all four existing groups ported (they test behaviour that survives verbatim: per-tier independence, `forceFailure` inertness, icon/beat independence). |
| `test/features/outcome/domain/story_pool_codec_test.dart` | **New.** §8. |
| `test/features/outcome/domain/story_cycle_selector_test.dart` | **New.** §8. |
| `test/features/outcome/application/story_pool_repository_test.dart` | **New.** §8. |
| `test/features/outcome/application/story_cycle_store_test.dart` | **New.** §8. |
| `test/features/outcome/domain/story_selector_test.dart` | Modified: pool-count assertions (`deathBeats.length == 50` etc.) move to the codec test against the bundled asset; this file keeps only pure `StorySelector` behaviour against synthetic pools. |
| `test/features/outcome/domain/story_renderer_test.dart` | Modified: sources its `survivedBeats` fixtures from the parsed bundled asset instead of the deleted Dart list. |
| `test/features/outcome/presentation/widgets/outcome_card_test.dart` | Modified: same fixture-sourcing change (lines 132–153). |
| `test/features/outcome/state/outcome_providers_test.dart` | Modified: the three timing tests are pinned to `kMinStoryLoadDuration` rather than a hardcoded 2s, so the 1200ms change doesn't silently invert their meaning. |
| `test/integration/mixed_outcomes_test.dart` | Modified only if it asserts on the 2s floor; otherwise untouched. |

---

## 2. Component specifications

### 2.1 `StoryBeat` + `StoryPool`

`story_beat.dart` — add `id` as the **first** required positional-named field, and the two codec
methods. Keep the existing class doc comment.

```dart
class StoryBeat {
  const StoryBeat({
    required this.id,
    required this.headline,
    required this.named,
    required this.anonymous,
  });

  /// Stable, immutable, never-recycled content ID (`death_017`) — the key the
  /// dedup cycle is stored against. Assigned in the content file, never
  /// derived from position, never regenerated on reword. See
  /// remote-story-config-options.md §8.1 for the three ID rules.
  final String id;

  final String headline;   // may contain {min}/{peak}, never {name}
  final String named;      // contains literal {name}, left unsubstituted
  final String anonymous;  // never contains {name}

  /// Throws [StoryPoolFormatException] on any missing/blank/non-String field.
  /// Unknown keys are ignored (forward-compatibility with a richer future
  /// schema published to already-shipped clients).
  factory StoryBeat.fromJson(Map<String, dynamic> json) { ... }

  Map<String, dynamic> toJson() => {...};
}
```

`toJson` is required not because the app writes content, but because the round-trip test in §8
(`decode(encode(pool)) == pool`) is the cheapest guard against a fromJson/schema drift.

`story_pool.dart`:

```dart
class StoryTierPool {
  const StoryTierPool({required this.beats, required this.icons});
  final List<StoryBeat> beats;   // List.unmodifiable
  final List<String> icons;      // List.unmodifiable
  bool get isEmpty => beats.isEmpty || icons.isEmpty;
}

class StoryPool {
  const StoryPool({
    required this.contentVersion,
    required this.death,
    required this.survived,
    required this.eternal,
  });
  final int contentVersion;
  final StoryTierPool death, survived, eternal;

  StoryTierPool tierFor(RunOutcome outcome);   // exhaustive switch, no default

  /// Every tier empty. The terminal state of the fallback chain — a service
  /// holding this returns `OutcomeStoryContent.naFor` for every tier.
  static const StoryPool empty = ...;
}
```

`StoryPool` lives in `domain/` and imports `RunOutcome` from `play_loop/domain/run_state.dart`,
matching the existing cross-feature domain import already present in
`local_outcome_story_service.dart`.

### 2.2 `StoryPoolCodec` — the single parse path

One static entry point. **Both the remote payload and the bundled asset go through it**; there is
no second, laxer parser for the asset (R1's whole justification).

```dart
class StoryPoolCodec {
  static StoryPool decode(String raw);          // throws StoryPoolFormatException
  static String encode(StoryPool pool);         // test/tooling only
}

class StoryPoolFormatException implements Exception {
  StoryPoolFormatException(this.reason);
  final String reason;
}
```

**Validation rules — each one either throws or is explicitly not enforced. No middle ground.**

| Rule | On violation |
|---|---|
| Raw string decodes as JSON and the root is a `Map` | throw |
| `schemaVersion` present, is `int`, `== kStorySchemaVersion` (1) | throw (`'unsupported schemaVersion N'`) |
| `contentVersion` is `int` if present, else defaults to `0` | no throw |
| `updatedAt` — **ignored entirely by the client**; it exists for humans reading the file | n/a |
| `tiers` present, is a `Map`, and contains all three of `death`/`survived`/`eternal` | throw — a partial pool is worse than a complete stale one |
| Each tier is a `Map` with `beats` (`List`) and `icons` (`List`) | throw |
| `beats.length <= kStoryMaxBeatsPerTier` (500) | throw |
| `icons.length` in `1..kStoryMaxIconsPerTier` (64) | throw |
| Each icon is a non-empty `String` | throw |
| Each beat has non-empty `String` `id`/`headline`/`named`/`anonymous` | throw |
| Every `id` unique **across the whole file**, not just within its tier | throw |
| Unknown top-level or per-beat keys | **ignored** — forward-compat |
| `{name}` appearing in `headline`/`anonymous`, or missing from `named` | **not enforced client-side** — see R3 |
| Empty `beats` array for a tier | **not a throw.** Valid, and correctly degrades to `naFor` for that tier only. A founder emptying one tier must not take the other two offline. |

> **R3 — placeholder rules are publish-time, not client-side.** Options §5 lists
> `{name}`-placement checks in the GitHub Action's validator. The client deliberately does **not**
> replicate them. Rationale: they are content-quality rules, not safety rules. Enforcing them
> client-side means one badly-worded beat rejects the entire payload and silently reverts every
> player to the bundled pool — a total content outage caused by a cosmetic typo. The client
> enforces only structural and memory-safety invariants. A mis-placed `{name}` renders as a
> literal `{name}` on one card; that is a strictly better failure than a global rollback.

`kStorySchemaVersion`, `kStoryMaxBeatsPerTier`, `kStoryMaxIconsPerTier`, and
`kStoryPoolMaxBytes` live at the top of `story_pool_codec.dart` (they are parse-domain constants,
not provider-layer timing constants — those live in `outcome_providers.dart`, §5.1).

**`decode` must not retain the raw string.** It takes `String raw`, calls `jsonDecode` into a
local, builds the pool, and returns. No field on any long-lived object ever holds `raw`. See §7.

### 2.3 `StoryCycleSelector`

Pure, no Flutter, no persistence — options §8.3's algorithm verbatim, expressed as a function of
mutable caller-owned state so it stays trivially testable.

```dart
class StoryCycleSelector {
  const StoryCycleSelector();

  /// Returns null iff [pool] is empty. Never throws.
  ///
  /// Mutates [seenIds] (adds the chosen ID; clears it first on a cycle
  /// exhaustion). The caller is responsible for persisting [seenIds] and the
  /// returned beat's ID afterwards.
  StoryBeat? pick(
    List<StoryBeat> pool,
    Set<String> seenIds,
    String lastShownId,
    Random random,
  );
}
```

Behaviour, exactly as options §8.3:

1. `candidates = pool.where((b) => !seenIds.contains(b.id))`
2. If `candidates.isEmpty`: `seenIds.clear()`; `candidates = pool.where((b) => b.id != lastShownId)`
3. If `candidates` is *still* empty (pool of exactly 1): `candidates = pool`
4. `chosen = candidates[random.nextInt(candidates.length)]`
5. `seenIds.add(chosen.id)`
6. return `chosen`

Two properties the tests must pin, because they are easy to "simplify" away:

- **The boundary beat is excluded from the first draw of the new cycle but is NOT seeded into the
  fresh `seenIds`** — it stays eligible for the rest of that cycle. (Options §8.3 note.)
- **`seenIds.clear()` happens before the reset draw, not after** — so the newly-chosen beat is the
  only member of the fresh set.

`lastShownId` is passed in and the new value is the returned beat's `id`; the selector does not
own it. `''` is the "nothing shown yet" sentinel and matches nothing.

**Empty-pool rule (applies to both selectors).** `StoryCycleSelector.pick` returns `null` on an
empty pool. `StorySelector.pick` (icons) currently calls `random.nextInt(pool.length)`
unguarded — `nextInt(0)` throws `RangeError`. Add an early guard so it cannot be reached with an
empty list; the *caller* (`RemoteOutcomeStoryService`) checks `tier.isEmpty` first and short-
circuits to `naFor`, so the guard is defence-in-depth, not the primary path.

### 2.4 `StoryPoolRepository`

Owns the whole fetch/cache/fallback chain. Knows nothing about dedup, selection, or rendering.

```dart
class StoryPoolRepository {
  StoryPoolRepository({
    required http.Client client,
    required PreferencesService prefs,
    required Uri endpoint,
    AssetBundle? bundle,          // defaults to rootBundle; injectable for tests
    DateTime Function()? now,     // injectable clock
  });

  /// The installed pool, or null before the first [load] completes.
  StoryPool? get current;

  /// Cold-start resolution: cached-prefs-string -> bundled asset -> empty.
  /// Memoized and single-flight: concurrent callers share one Future, and a
  /// second call after success returns the same [StoryPool] instance.
  /// **Never throws.**
  Future<StoryPool> load();

  /// Network refresh. No-op if within [kStoryPoolTtl] of the last successful
  /// fetch. **Never throws.** Returns true iff [current] was swapped.
  Future<bool> refreshIfStale();
}
```

**`load()` — exact sequence.**

1. `if (_current != null) return _current!;`
2. `if (_inFlight != null) return _inFlight!;` (single-flight guard; assign `_inFlight` before
   the first `await`)
3. Cached string: `prefs.storyPoolCache`. If non-empty, `StoryPoolCodec.decode` it inside
   `try/catch`. On success → install, go to 6.
4. On any failure in step 3 (including a `StoryPoolFormatException` from a schema-version bump
   the *previous* app version wrote): **clear the three cache prefs keys** (payload, etag,
   fetchedAt) so a poisoned cache can't be re-read every launch, then continue.
5. Bundled asset: `await bundle.loadString(kBundledStoryAsset)` → `StoryPoolCodec.decode` inside
   `try/catch`. On success → install. On failure → install `StoryPool.empty`.
6. **Immediately after a successful `bundle.loadString`, call
   `bundle.evict(kBundledStoryAsset)`.** `rootBundle` is a `CachingAssetBundle` and otherwise
   holds the full ~24 KB raw string alive for the process lifetime for no reason. See §7.
7. `_current = pool; _inFlight = null; return pool;`

`load()` never touches the network. It is disk/asset only and completes in single-digit
milliseconds, which is what makes options §9.1's "the outcome card resolves from memory" true.

**`refreshIfStale()` — exact sequence.** Every step is inside one outer `try/catch` that swallows
and returns `false`.

1. `if (now().difference(prefs.storyPoolFetchedAt) < kStoryPoolTtl) return false;`
2. `final etag = prefs.storyPoolEtag;`
3. `final response = await client.get(endpoint, headers: {if (etag.isNotEmpty) 'If-None-Match': etag}).timeout(kStoryFetchTimeout);`
4. `if (response.statusCode == 304)`: write `storyPoolFetchedAt = now()`. Return `false`.
   **Do not re-decode, do not touch the payload cache.**
5. `if (response.statusCode != 200)`: return `false`. **Do not write `fetchedAt`** — a 5xx should
   be retried on the next app start, not suppressed for 6 hours.
6. `if (response.bodyBytes.length > kStoryPoolMaxBytes)`: return `false`. Checked on
   **`bodyBytes.length`, before any UTF-8 decode to String**, so an oversized payload is never
   materialised as a Dart string.
7. `final raw = utf8.decode(response.bodyBytes)` — then `final pool = StoryPoolCodec.decode(raw);`
   A `StoryPoolFormatException` here returns `false` **and writes nothing.**
8. **Decode before persist, always.** Only now: `prefs.setStoryPoolCache(raw)`,
   `prefs.setStoryPoolEtag(response.headers['etag'] ?? '')`,
   `prefs.setStoryPoolFetchedAt(now())`. This is the invariant that makes the cache
   read in `load()` step 3 almost always succeed: **the cache only ever contains a payload this
   exact client version has already parsed successfully.**
9. `if (_current != null && pool.contentVersion == _current!.contentVersion && _current!.contentVersion != 0) return false;` — the options §8.6 "don't bother re-installing" short-circuit. Keeps
   `_current`'s object identity stable so §2.6's prune trigger doesn't refire.
10. `_current = pool; return true;`

> **R4 — `shared_preferences`, not a `path_provider` file.** Technical-notes §6 is followed
> exactly, over options §9.3's incidental phrasing "cached stories.json (app support dir)". The
> options doc's fallback *chain* is correct; only its storage medium is superseded. Reason: it
> keeps the app's durable-storage surface at exactly one mechanism, per technical-notes §6's
> argument, and a ≤128 KB single string value is well inside `shared_preferences`' comfortable
> range. Revisit only if the pool ever approaches the high hundreds of beats.

> **R5 — three cache prefs keys were never enumerated by either doc.** Options §8.2 lists the six
> dedup keys; technical-notes §6 says "store the raw fetched JSON string"; options §9.1 says
> "writes the new file + ETag + timestamp". Nobody wrote the key names down. This spec adds
> `story_pool_cache`, `story_pool_etag`, `story_pool_fetched_at` — see §6.

### 2.5 `StoryCycleStore`

Holds the dedup state. Exists as its own class (rather than as fields on the service) for one
concrete reason: **pruning is a pool-load concern and selection is a per-card concern**, and both
need the same three sets. Separating it keeps `StoryPoolRepository` free of dedup knowledge and
keeps the store unit-testable against a fake `PreferencesService` without any HTTP in the picture.

```dart
class StoryCycleStore {
  /// Hydrates all six values synchronously from prefs. Safe in a constructor:
  /// PreferencesService's getters are all synchronous over an already-loaded
  /// SharedPreferences instance.
  StoryCycleStore(this._prefs);

  Set<String> seenFor(RunOutcome outcome);
  String lastShownFor(RunOutcome outcome);

  /// Called by the selector's caller after a successful pick. Updates memory
  /// first, then fires the two prefs writes unawaited (write-through backup,
  /// matching PreferencesService's documented contract). Never throws.
  void record(RunOutcome outcome, String beatId);

  /// Intersects each tier's seen-set with that tier's live ID set and
  /// persists the pruned result — **once per pool install, never per card**
  /// (options §8.3 "Pruning"). Also clears `lastShown` for a tier whose
  /// last-shown ID is no longer in the pool. Never throws.
  void pruneAgainst(StoryPool pool);
}
```

`record` writes to prefs via `unawaited(...)`. A dropped write costs at most one duplicate story
after a crash; blocking the card render on a disk write costs every player a frame. The existing
`PreferencesService` contract ("write-through durability backup only") authorises this.

### 2.6 `RemoteOutcomeStoryService`

```dart
class RemoteOutcomeStoryService implements OutcomeStoryService {
  RemoteOutcomeStoryService({
    required StoryPoolRepository repository,
    required StoryCycleStore cycleStore,
    Random? random,
  });

  bool forceFailure = false;   // preserved verbatim from LocalOutcomeStoryService
}
```

Instance state: `_random`, `const StoryCycleSelector()`, `const StorySelector()` (icons only),
`const StoryRenderer()`, the three icon `int?` avoid-indices (`_lastDeathIcon` etc. — **beat
indices are gone**, replaced by the ID-keyed cycle store), and `int? _prunedAgainstIdentity`
(an `identityHashCode`, deliberately not a `StoryPool` reference — see M6/M8 below: holding
the actual old pool object here would keep it resident until the next `fetchStory` call).

`fetchStory(RunSummary summary)`:

1. `if (forceFailure) return OutcomeStoryContent.naFor;` — first line, before any await, so it
   remains fully inert (existing test asserts it consumes no `Random` draw and mutates nothing).
2. ```dart
   final pool = repository.current
       ?? await repository.load().timeout(kStoryFetchTimeout, onTimeout: () => StoryPool.empty);
   ```
   The `??` means the steady-state path has **zero awaits** past the async-function boundary.
3. ```dart
   final poolIdentity = identityHashCode(pool);
   if (poolIdentity != _prunedAgainstIdentity) {
     cycleStore.pruneAgainst(pool);
     _prunedAgainstIdentity = poolIdentity;
   }
   ```
   — identity-keyed (via `identityHashCode`, not `pool.contentVersion`, which defaults to `0`
   and can collide across genuinely different installs), so pruning runs exactly once per
   installed pool, including after a background hot-swap, and never per card. Tracking the
   hash rather than the pool object itself means the old pool is never kept resident by this
   field after a swap.
4. `final tier = pool.tierFor(summary.outcome); if (tier.isEmpty) return OutcomeStoryContent.naFor;`
5. Beat: `cycleSelector.pick(tier.beats, cycleStore.seenFor(o), cycleStore.lastShownFor(o), _random)`.
   `null` → `naFor`. Otherwise `cycleStore.record(o, beat.id)`.
6. Icon: `storySelector.pick(tier.icons, _random, avoidIndex: _lastXIcon)` — unchanged from
   today, per options §8.5. Store the returned index.
7. Render via `StoryRenderer` and return `OutcomeStoryContent(..., isFallback: false)`.

> **R2 — `LocalOutcomeStoryService` is deleted, not kept alongside.** Technical-notes §5 said the
> provider "swaps one line", implying the old class lingers. It would be dead code the moment the
> swap happens, and its only distinguishing feature (compile-time pools) is exactly what R1
> removes. Its testability value is fully replaced by injecting a stub `StoryPoolRepository` whose
> `current` returns a fixture pool — which is *better*, because tests can now vary the pool.

> **R6 — `isFallback` semantics are tightened.** Today it is true only on the `forceFailure` /
> `naFor` path. Options §9.3 wants it to also mean "we're serving bundled content because remote
> has been failing". Making it a two-meaning flag now, with no analytics consumer, is speculative.
> **Decision: `isFallback` keeps its exact current meaning (`naFor` only).** The "serving bundled
> content" signal is instead exposed as `StoryPoolRepository.currentSource`
> (`enum StoryPoolSource { remote, cache, bundled, none }`), set on install. It is not read by any
> UI or provider today; it exists so the future analytics hook options §9.3 anticipates has a
> clean, unambiguous thing to read, without overloading a flag the outcome-card widget already
> branches on.

---

## 3. The endpoint constant (hosting is NOT provisioned)

### 3.1 `lib/features/outcome/application/story_config_endpoint.dart`

This file exists solely so the founder has one obvious, greppable place to edit, and so nothing
else in the codebase hardcodes a URL.

```dart
/// ============================================================
///  THE ONE THING TO CHANGE WHEN YOU SET UP HOSTING.
/// ============================================================
///
/// Replace the host below with wherever you publish `stories.json`.
/// Nothing else in the app needs to change. Suggested hosts, in the order
/// recommended by remote-story-config-options.md §1/§7:
///
///   Cloudflare Pages   https://<project>.pages.dev/stories.json
///   Cloudflare R2      https://<bucket>.<account>.r2.dev/stories.json
///   Custom domain      https://content.stayalive.app/stories.json
///
/// REQUIREMENTS FOR WHATEVER HOST YOU PICK:
///   1. HTTPS. Plain http:// will be blocked by Android's default
///      cleartext-traffic policy and by browsers on the web build.
///   2. Must send an `ETag` response header (every CDN listed above does by
///      default). Without it, every session re-downloads the full ~24 KB
///      instead of getting a 4-byte 304. Not fatal, just wasteful.
///   3. Must send `Access-Control-Allow-Origin: *` — REQUIRED for the Flutter
///      **web** build, which is an active dev target. Cloudflare Pages does
///      NOT send this by default for cross-origin requests; add a `_headers`
///      file to the Pages project. See tools/story-content/README.md.
///   4. `Cache-Control: max-age=300` or similar. Do not use an immutable /
///      multi-hour edge cache (this is why jsDelivr's @main URLs were
///      rejected — options doc "Honourable mentions").
///
/// UNTIL THIS IS REAL: leave the placeholder as-is. The app is fully
/// functional against it — every fetch fails DNS, `refreshIfStale` swallows
/// it, and all 66 beats are served from `assets/stories_bundled.json`. There
/// is no error UI, no retry, no user-visible symptom. Shipping with the
/// placeholder is a supported state, not a broken one.
const String kStoryConfigUrl = 'https://REPLACE_ME.example.com/stories.json';
```

The repository takes `Uri endpoint`, and the provider builds it with `Uri.parse(kStoryConfigUrl)`.
`Uri.parse` on the placeholder succeeds (it is a well-formed URL), so nothing needs a null branch.

### 3.2 Explicit non-dependency

**No implementation task in this spec is blocked on hosting existing.** The flutter-developer
builds, tests (with `MockClient`), and ships against the placeholder. Pointing it at a real host
later is a one-line diff with no code review implications beyond §9.2's permission.

### 3.3 Where the seed file lives — and why there are two copies

| File | Role | Ships in the app? | Changes when? |
|---|---|---|---|
| `tools/story-content/stories.json` | **Canonical editable source.** What the founder edits and uploads to the CDN. In Phase 2 this becomes the GitHub Action's output. | **No** — `tools/` is not under `flutter: assets:`. | Whenever content changes (weekly/monthly, no app release needed — the entire point). |
| `assets/stories_bundled.json` | **Compiled-in fallback snapshot.** | **Yes** — real Flutter asset. | Only at app-release time, deliberately, by copying the current `tools/` copy over it. |

They are byte-identical today and are **allowed and expected to diverge** afterwards. That
divergence is the feature: remote content moves ahead of the shipped binary. Consequently there
must be **no test asserting the two files are equal** — a test like that would fight the design.
The bundled asset only has to satisfy: parses cleanly, all three tiers non-empty, IDs unique.

`tools/` is chosen over `assets/remote-config-seed/` because anything under `assets/` invites a
future `flutter: assets: - assets/` glob to accidentally bundle it, doubling the shipped payload
silently.

### 3.4 `tools/story-content/README.md` — required contents

The flutter-developer writes this file. It must contain, at minimum:

1. The two-copy explanation from §3.3 above, in plain language.
2. "How to publish an edit": edit `stories.json` → validate it's still valid JSON → upload/commit
   → live within `max-age` + `kStoryPoolTtl` (worst case ~6h for an existing session, immediate
   for a new one).
3. **The three ID rules from options §8.1, restated verbatim** — immutable, never recycled,
   globally unique. Highest-consequence rules in the whole feature; a recycled ID silently hides
   new content from returning players.
4. The current highest ID per tier (`death_050`, `survived_010`, `eternal_006`) and a note to
   update this line whenever IDs are added.
5. **The emoji-safety rationale rescued from the deleted `story_icons.dart`**, verbatim:
   - `⏰️` is U+23F0 + U+FE0F (multi-codepoint, not ZWJ) — fine as long as it's never
     `substring`'d, which it isn't.
   - Use `🆘`, never `🛟` — the ring-buoy is Unicode 14.0/2021 and risks tofu-rendering on older
     Android system emoji fonts, which would ship straight into the rasterized shared PNG. `🆘` is
     Unicode 6.0/2010 and safe on every device this app targets. **Apply this test to any new
     emoji: if it postdates ~2015, don't.**
   - `😮‍💨` contains a ZWJ; it is display-only and never measured, indexed, or truncated.
6. The `_headers` snippet for Cloudflare Pages CORS (§3.1 requirement 3).
7. A one-line note that `updatedAt` is ignored by the client and is for humans only.

---

## 4. R1 — Bundled JSON asset, not compiled Dart lists

> **R1 (the headline decision).** `death_beats.dart` / `survived_beats.dart` /
> `eternal_beats.dart` / `story_icons.dart` are **deleted** and replaced by
> `assets/stories_bundled.json`, parsed through `StoryPoolCodec.decode` — the exact same function
> the remote payload goes through. This overrides technical-notes §5's "kept, not deleted" and
> follows options §7/§9.3, which say "bundled asset fallback" and "the bundled asset itself is
> corrupt" (a phrase that only makes sense for parsed data).

**Justification, in priority order:**

1. **One parsing path or the guarantee is worthless.** With two representations, the bundled
   fallback is never exercised by `StoryPoolCodec`. You can then ship a "fallback" that the
   parser would reject, and only discover it when a player is offline — the exact moment you have
   no telemetry and no recourse. With one path, `flutter test` proves the fallback is loadable
   every single CI run.
2. **The Dart lists need IDs anyway.** Dedup keys on `id`. Keeping the Dart route means editing
   the `_d()`/`_s()`/`_e()` helper signatures and all 66 call sites to add `'death_001'`-style
   literals — the same edit volume as generating the JSON, but leaving two content
   representations to hand-sync forever.
3. **Parity at t=0 is free and provable.** `assets/stories_bundled.json` and
   `tools/story-content/stories.json` are generated from one source and are byte-identical today.
   With Dart lists there is no way to diff the shipped fallback against the published payload.
4. **It deletes code.** Four files and ~120 lines of hand-maintained Dart become one data file
   plus a codec that had to exist regardless.

**The cost, stated honestly and mitigated:** a JSON typo is caught at runtime, not compile time.
Mitigation is `story_pool_codec_test.dart`'s "bundled asset parses, 50/10/6 beats, 6/5/4 icons,
all IDs unique" test — a CI gate that is *strictly stronger* than the Dart compiler was (the
compiler never checked ID uniqueness, which is the invariant that actually matters).

Secondary cost: `rootBundle` needs a binding, so codec tests that touch the asset use
`TestWidgetsFlutterBinding.ensureInitialized()`. One line.

`pubspec.yaml`:

```yaml
  assets:
    - assets/sfx/
    - assets/stories_bundled.json
```

---

## 5. Provider graph

### 5.1 New constants in `outcome_providers.dart`

```dart
/// Loading floor. 2s -> 1200ms per options §9.2 — the fetch is no longer on
/// the card's critical path, so this is purely a dramatic-pause design lever.
/// REQUIRES game-ux-designer sign-off against the outcome-card mockup
/// (options §10 step 4) before this change is considered done.
const Duration kMinStoryLoadDuration = Duration(milliseconds: 1200);

/// Caps both the HTTP round trip in refreshIfStale() and the (disk-only,
/// normally sub-10ms) load() that fetchStory falls back on if the card is
/// somehow reached before the pool is warm. Options §9.2.
const Duration kStoryFetchTimeout = Duration(seconds: 4);

/// Minimum interval between network refreshes. Options §9.1.
const Duration kStoryPoolTtl = Duration(hours: 6);
```

`kStoryPoolMaxBytes = 128 * 1024` and the pool-size caps live in `story_pool_codec.dart` (§2.2).

### 5.2 Provider definitions

```dart
final Provider<http.Client> httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);   // mandatory — see §7
  return client;
});

final Provider<StoryPoolRepository> storyPoolRepositoryProvider =
    Provider<StoryPoolRepository>((ref) => StoryPoolRepository(
          client: ref.watch(httpClientProvider),
          prefs: ref.watch(preferencesServiceProvider),
          endpoint: Uri.parse(kStoryConfigUrl),
        ));

final Provider<StoryCycleStore> storyCycleStoreProvider =
    Provider<StoryCycleStore>((ref) => StoryCycleStore(ref.watch(preferencesServiceProvider)));

/// App-lifetime pool warm-up + background refresh (options §9.1). Resolves
/// from cache/asset (fast, no network), THEN kicks off the network refresh
/// fire-and-forget so this Future is never gated on connectivity.
final FutureProvider<StoryPool> storyPoolProvider = FutureProvider<StoryPool>((ref) async {
  final repo = ref.watch(storyPoolRepositoryProvider);
  final pool = await repo.load();
  unawaited(repo.refreshIfStale());   // never awaited; swaps repo.current in place
  return pool;
});

/// ONE-LINE SWAP. Everything downstream is untouched.
final Provider<OutcomeStoryService> outcomeStoryServiceProvider =
    Provider<OutcomeStoryService>((ref) => RemoteOutcomeStoryService(
          repository: ref.watch(storyPoolRepositoryProvider),
          cycleStore: ref.watch(storyCycleStoreProvider),
        ));
```

`outcomeStoryProvider` (the `autoDispose.family`) is **completely unchanged** — same body, same
`Future.wait` idiom, same per-`RunSummary`-identity caching. This is the payoff of the
`OutcomeStoryService` boundary.

All four new providers are plain, **non-`autoDispose`** `Provider`s / `FutureProvider`s, matching
`outcomeStoryServiceProvider`'s existing session-scoped lifetime. `storyPoolProvider`'s value
must survive across screens or the pool would be re-parsed on every navigation.

### 5.3 How `storyPoolProvider` interacts with the per-run `outcomeStoryProvider.family`

They do **not** compose. `outcomeStoryProvider` deliberately does **not** `ref.watch`
`storyPoolProvider`, because watching it would make every outcome card rebuild when a background
refresh lands mid-session — including one already on screen, which options §9.1 explicitly
forbids ("a swap never happens mid-card").

Instead both go through the shared `StoryPoolRepository` singleton:

```
                       ┌──────────────────────────┐
  SplashScreen ───────►│  storyPoolProvider       │ (warm-up + bg refresh)
   (fire & forget)     └────────────┬─────────────┘
                                    │ repo.load() / repo.refreshIfStale()
                                    ▼
                       ┌──────────────────────────┐
                       │ StoryPoolRepository      │  _current: StoryPool
                       │  (session singleton)     │  (single-flight memoized)
                       └────────────▲─────────────┘
                                    │ repository.current  (sync, no await)
                       ┌────────────┴─────────────┐
                       │ RemoteOutcomeStoryService│
                       └────────────▲─────────────┘
                                    │ fetchStory(summary)
              ┌─────────────────────┴──────────────────────┐
              │ outcomeStoryProvider.autoDispose.family    │ ← UNCHANGED
              │   Future.wait([fetch, 1200ms floor])       │
              └────────────────────────────────────────────┘
```

Because `load()` is memoized and single-flight, splash's warm-up and a cold outcome card racing
it share one Future and one parse. The card picks up a hot-swapped pool on its *next* fetch,
never mid-card — the `identityHashCode(pool) != _prunedAgainstIdentity` check in §2.6 step 3
is what makes the swap visible-and-pruned exactly once (without retaining the old pool).

### 5.4 `main.dart` vs. `SplashScreen` — where the warm-up goes

> **R7.** The warm-up goes in **`SplashScreen._runSplash()`**, as one fire-and-forget line. Not
> `main()`.

```dart
// in _runSplash(), next to the existing reminderController.reconcile() line:
unawaited(ref.read(storyPoolProvider.future));
```

Rationale for `SplashScreen` over the two alternatives:

- **`main()` awaiting the pool before `runApp`** — adds a disk/asset read to the pre-first-frame
  critical path. `main()`'s only current await is `PreferencesService.create()`, which is load-
  bearing (providers are overridden with its result). The pool is not. Rejected.
- **`main()` fire-and-forget** — requires manually constructing a `ProviderContainer` outside
  `ProviderScope`, or an ugly `ProviderScope` observer. Rejected as strictly worse ergonomics for
  the same effect.
- **`SplashScreen`** — already the app's designated warm-up surface, already burns
  1400+175 ms of wall clock, already runs exactly one fire-and-forget side effect
  (`reminderControllerProvider.reconcile()`) with an established precedent and comment style. The
  pool load finishes in a few ms inside that window; the network refresh continues in the
  background across the navigation. The outcome card is at minimum two screens and one full run
  (seconds) away. Zero risk of a cold card.

The warm-up **must not** be awaited into splash's existing `Future.wait` — navigation must never
be gated on it. `unawaited(...)` and `dart:async` import (already present in that file).

---

## 6. Persistence

### 6.1 `preferences_keys.dart`

Bump the version and add nine keys. Options §8.2 supplies six; R5 adds three.

```dart
/// Bumped 1 -> 2 for the remote-story-config keys below. No migration code is
/// needed: every new key's absent-value default (empty list / empty string /
/// epoch-zero) is already the correct fresh-install state, and a v1 install
/// upgrading to v2 correctly starts with an empty story cycle and a cold
/// cache.
const int kPrefsSchemaVersion = 2;

// --- Dedup cycle (options §8.2) ---

/// IDs of story beats already shown in the current cycle. StringList, default [].
const String kKeySeenStoryIdsDeath = 'seen_story_ids_death';
const String kKeySeenStoryIdsSurvived = 'seen_story_ids_survived';
const String kKeySeenStoryIdsEternal = 'seen_story_ids_eternal';

/// The single most recently shown beat ID per tier, used only to avoid an
/// immediate repeat across a cycle-reset boundary. String, default ''.
const String kKeyLastStoryIdDeath = 'last_story_id_death';
const String kKeyLastStoryIdSurvived = 'last_story_id_survived';
const String kKeyLastStoryIdEternal = 'last_story_id_eternal';

// --- Remote payload cache (this spec §2.4 R5) ---

/// The last successfully-PARSED remote payload, verbatim. String, default ''.
/// Cold-start bootstrap only — never the runtime source of truth. Only ever
/// written after StoryPoolCodec.decode has already succeeded on it.
const String kKeyStoryPoolCache = 'story_pool_cache';

/// ETag of the cached payload, sent as If-None-Match. String, default ''.
const String kKeyStoryPoolEtag = 'story_pool_etag';

/// Epoch millis of the last SUCCESSFUL fetch (200 or 304). int, default 0.
/// Not written on failure, so a failing CDN is retried next session rather
/// than suppressed for the TTL.
const String kKeyStoryPoolFetchedAt = 'story_pool_fetched_at';
```

### 6.2 `preferences_service.dart`

Nine getter/setter pairs in the file's existing shape — every read `try`/`catch`es to the
documented default, every write swallows. `getStringList`/`setStringList` for the three seen
sets, `getString`/`setString` for the four strings, `getInt`/`setInt` for `fetchedAt`.

`storyPoolFetchedAt` exposes `DateTime` (`DateTime.fromMillisecondsSinceEpoch(n)`) so the
repository doesn't do epoch arithmetic; default is `DateTime.fromMillisecondsSinceEpoch(0)`.

**No change to `clearAll()`** — `_prefs.clear()` already wipes all nine, which is correct:
"Reset progress" should restart the story cycle *and* drop the cache. Add a line to `clearAll`'s
doc comment saying so explicitly, since the cache-drop consequence is non-obvious (the next
launch re-fetches from the network, or falls back to the bundled asset offline — both fine).

**One live-state caveat to handle:** `StoryCycleStore` hydrates in its constructor and holds the
sets in memory. After `clearAll()`, the store's in-memory sets are stale-but-nonempty. Settings'
reset already navigates back to Home; the store is session-scoped and won't rehydrate. Fix:
`StoryCycleStore` exposes `void reset()` (clears all six in-memory values), and
`SettingsScreen`'s reset handler calls `ref.read(storyCycleStoreProvider).reset()` immediately
after `clearAll()`. This is a real bug the source docs didn't anticipate; without it, "Reset
progress" leaves the story cycle mid-way.

---

## 7. Memory-safety review (CLAUDE.md rule 7)

Not design intent — these are **acceptance criteria**. A reviewer should be able to check each
against the diff.

| # | Requirement | Where enforced | Failure mode it prevents |
|---|---|---|---|
| M1 | The parsed `StoryPool` is the **only** runtime source of truth. Nothing reads prefs or disk per card. | `RemoteOutcomeStoryService.fetchStory` reads `repository.current` (a field), never prefs. | Per-run disk I/O; a second, drifting representation of the pool. |
| M2 | **The raw JSON string is never retained past decode by any object of ours.** `StoryPoolCodec.decode(String)` takes it as a parameter and returns a pool; no long-lived object of ours has a `String _raw` field. In `refreshIfStale`, `raw` is a local that goes out of scope after the prefs write. **Known, accepted exception:** the same string, once written via `_prefs.setStoryPoolCache(raw)`, IS held resident for the app's whole process lifetime inside `shared_preferences`' own internal cache (that plugin keeps every key/value it has ever set in a process-lifetime Dart map) — this is a real consequence of the (deliberate, not-revisited-here) choice to use `shared_preferences` for this cache, not something M2 eliminates. What IS bounded is the SIZE of that resident copy, via `kStoryPoolMaxBytes`. | Code review: grep for any `String` field on `StoryPoolRepository` / the service (that check is still valid for our own objects — it just doesn't cover the plugin's internal cache). | Real payload ~15 KB, capped at `kStoryPoolMaxBytes` = 128 KB (~8.7x headroom) — bounds the worst case, does not make the residency itself go away. |
| M3 | **`bundle.evict(kBundledStoryAsset)` immediately after `loadString`.** | `StoryPoolRepository.load()` step 6. | `rootBundle` is a `CachingAssetBundle`; without eviction the asset's raw string is pinned for the process lifetime. This is a silent, easy-to-miss leak that M2 alone does not cover. |
| M4 | **Payload cap checked on `response.bodyBytes.length` BEFORE `utf8.decode`.** `kStoryPoolMaxBytes = 128 * 1024`. | `refreshIfStale` step 6. | A hostile/misconfigured host streaming a huge body gets materialised as a Dart string before anyone checks its size. Checking after decode is too late. |
| M5 | **Per-tier beat cap 500, per-tier icon cap 64**, enforced in the codec so both the remote and bundled paths are covered. | `StoryPoolCodec.decode`. | A bad content edit ballooning the resident pool. Options §8.3. |
| M6 | Pool lists are `List.unmodifiable`; `StoryBeat` and `StoryPool` are immutable. Exactly one pool instance is resident at a time (the old one is dropped on swap, not kept as history). | `StoryPool` construction. | Aliasing bugs; unbounded pool history. |
| M7 | Seen-sets are three `Set<String>`, **bounded by pool size by construction** via `pruneAgainst`, which runs once per pool install. ~66 × ~12 bytes ≈ 800 bytes total. | `StoryCycleStore.pruneAgainst`, triggered by the `identical()` check in §2.6 step 3. | Options §8.3: two years of content churn growing the persisted set without bound. |
| M8 | Pruning is **once per pool install, never per card** — the `identityHashCode(pool) != _prunedAgainstIdentity` guard, not a length check or a timestamp. Tracks an `int` identity, not a `StoryPool` reference, so the previous pool is never kept resident by this guard after a hot-swap. | §2.6 step 3. | An O(n) set-intersect plus three prefs writes on every single outcome card. |
| M9 | The per-pick `candidates` list is ≤500 *references*, allocated and immediately garbage. No history log, no accumulation across runs. | `StoryCycleSelector.pick`. | Options §8.3's explicitly-rejected "naive history log" design. |
| M10 | **`http.Client` is created once and closed on dispose.** `ref.onDispose(client.close)`. | `httpClientProvider`. | A leaked client holds an open connection pool. New failure mode — this app has never had a networking object before. |
| M11 | `load()` is single-flight: `_inFlight` assigned **before** the first `await`. | `StoryPoolRepository.load()` step 2. | Splash warm-up racing a cold outcome card → two concurrent parses, two transient pools, two prune passes. |
| M12 | `refreshIfStale()` is fire-and-forget from `storyPoolProvider` but must not outlive a disposed container in tests. The outer `try/catch` swallows post-dispose errors. | `storyPoolProvider`. | Test flake / "used after dispose" from an in-flight refresh. |
| M13 | `record()` fires prefs writes `unawaited`. No card render blocks on disk. | `StoryCycleStore.record`. | A frame-time stall on the reveal beat. |

**Explicit new-risk statement for the reviewer:** this change introduces the app's first network
socket, first HTTP response buffer, and first potentially-attacker-controlled input. M4 and M5 are
the two that specifically bound attacker-controlled memory; M2 and M3 bound self-inflicted
retention. None of the other twelve existed as risks before this feature.

---

## 8. Error-handling contract

`OutcomeStoryService`'s documented contract — *"Never throws: a failed fetch resolves to
`OutcomeStoryContent.naFor` rather than an exception, so the UI never needs an error state or a
retry"* — is preserved **exactly**. There is no new UI, no error branch, no banner, no retry
button. Options §9.3.

The chain, per options §9.3, with R4's storage substitution:

```
repository.current (RAM)  →  prefs cached payload  →  assets/stories_bundled.json
                                                   →  StoryPool.empty  →  naFor
```

| Case | Detected where | Behaviour | Persisted state after | Player sees |
|---|---|---|---|---|
| **Oversized payload (>128 KB)** | `refreshIfStale` step 6, on `bodyBytes.length`, before UTF-8 decode | Abort refresh, return `false`. `current` untouched. | Nothing written — not even `fetchedAt`, so it retries next session. Cache keeps the last good payload. | Nothing. Previous content continues. |
| **Malformed JSON / schema violation** | `StoryPoolCodec.decode` throws `StoryPoolFormatException` in `refreshIfStale` step 7 | Caught, abort, return `false`. | **Nothing written.** This is the decode-before-persist invariant: a payload that failed to parse never reaches the cache. | Nothing. |
| **`schemaVersion` mismatch** (e.g. server publishes `2`, this client only knows `1`) | Same as above — the codec's first check | Same: abort, keep current pool. An old client on a new schema serves cached-or-bundled content **forever**, correctly and silently, until the user updates the app. | Nothing written. | Nothing. This is the designed behaviour of the version field (options §8.6). |
| **Network timeout (>4 s)** | `.timeout(kStoryFetchTimeout)` in step 3 throws `TimeoutException` | Caught by the outer `try/catch`, return `false`. | Nothing written; retried next session. | Nothing. The card was never waiting on this — it resolves from `current` in microseconds. |
| **`SocketException` / `ClientException` / no connectivity** | Outer `try/catch` in `refreshIfStale` | Swallowed, return `false`. | Nothing written. | Nothing. |
| **Non-200/304 (403, 404, 5xx)** | `refreshIfStale` step 5 | Return `false`. | Nothing written (deliberately not `fetchedAt` — see §2.4 step 5). | Nothing. |
| **304 Not Modified** | step 4 | Success path. No decode, no swap. | `fetchedAt` updated only. | Nothing (correctly — content is unchanged). |
| **Corrupt cached prefs payload** (truncated by an app kill; or written by a newer app version with a schema this build rejects) | `load()` step 3's `try/catch` | Fall through to bundled asset, **and clear all three cache keys** so it can't poison every subsequent launch. | Cache keys cleared. | Nothing. |
| **Bundled asset missing/corrupt** | `load()` step 5's `try/catch` | Install `StoryPool.empty`. | — | `naFor` ("N/A") on every card. Unreachable in practice (CI parses the asset every run), retained as defence-in-depth exactly as options §9.3 specifies. |
| **A tier is empty in an otherwise-valid pool** | `fetchStory` step 4 | `naFor` for **that tier only**; the other two are unaffected. | — | "N/A" card for that outcome. |
| **`load()` exceeds 4 s** (pathological slow disk on a cold first launch) | `.timeout` in `fetchStory` step 2 | Resolve to `StoryPool.empty` → `naFor`. | — | One "N/A" card; the next card is fine (the load will have completed by then). |
| **`forceFailure == true`** | `fetchStory` step 1 | `naFor`, before any await. Consumes no `Random` draw, mutates no cycle state. | — | "N/A" — the existing dev/test path, unchanged. |

**Invariant the tester should assert directly:** no method on `StoryPoolRepository`,
`StoryCycleStore`, `StoryPoolCodec`-callers, or `RemoteOutcomeStoryService` propagates an
exception. Only `StoryPoolCodec.decode` itself throws, and it is called from exactly two places,
both wrapped.

---

## 9. Test plan

Mapping options §10 step 5's eleven cases to files. Per CLAUDE.md rule 5, the flutter-developer
runs these files plus the four modified existing outcome test files — not the whole suite.

### 9.1 `test/features/outcome/domain/story_cycle_selector_test.dart` (new)

| Case (§10 step 5) | Test |
|---|---|
| **Fresh cycle** | Empty `seenIds`, empty `lastShownId` → picks from the full pool; `seenIds` afterwards is exactly `{chosen.id}`. |
| **Mid-cycle** | With N of M seen, the chosen ID is never in `seenIds`; over a seeded run of M−N picks, every remaining ID appears exactly once. |
| **Exhaustion + reset** | Draw `pool.length` times from a 6-beat pool: all 6 distinct, `seenIds.length == 6`. The 7th draw clears and returns a beat; `seenIds.length == 1` after it. |
| **Boundary no-repeat** | The 7th draw is never the 6th draw's beat. Repeat across many seeds. |
| **Boundary re-eligibility** | The boundary-excluded beat is **not** in the fresh `seenIds` and *does* reappear later in the new cycle. (Pins the options §8.3 note that is easy to get wrong.) |
| **Pool of exactly 1** | Returns the single beat repeatedly, never throws (step 3 of the algorithm). |
| **Empty pool** | Returns `null`, never throws. |
| **Story added mid-cycle** | With 5/6 seen, add a new beat → the next pick is the new beat or the one unseen one, never a seen one. |
| **Story removed mid-cycle** | `seenIds` contains an ID absent from the pool; exhaustion is still computed against the live pool, so the cycle never deadlocks. Draw 2× pool length without hanging or throwing. |

### 9.2 `test/features/outcome/application/story_cycle_store_test.dart` (new)

| Case | Test |
|---|---|
| **Stale-ID pruning** | Seed prefs with seen IDs including three that aren't in the pool → `pruneAgainst` leaves only live IDs, and the pruned value is persisted. |
| **Prune clears a dead `lastShownId`** | `lastShown` pointing at a removed beat is reset to `''`. |
| Hydration | Constructor reads all six keys; absent keys → `{}` / `''`. |
| Write-through | `record` updates memory synchronously and prefs eventually. |
| Corrupt prefs | A `getStringList` that throws → defaults to `{}`, never propagates. |
| `reset()` | Clears all six in-memory values (the §6.2 Settings-reset bug). |

### 9.3 `test/features/outcome/domain/story_pool_codec_test.dart` (new)

| Case | Test |
|---|---|
| **Bundled asset is valid** | `rootBundle.loadString('assets/stories_bundled.json')` → decode → 50/10/6 beats, 6/5/4 icons, `contentVersion == 1`, **all 66 IDs unique**, IDs match `^(death\|survived\|eternal)_\d{3}$`. This is the CI gate that replaces the compile-time guarantee R1 gives up. |
| **Corrupt payload** | Truncated JSON, `[]` root, `{}` root → each throws `StoryPoolFormatException`, none throws anything else. |
| **Schema-version mismatch** | `schemaVersion: 2` and `schemaVersion: "1"` → throw. |
| Missing tier | `tiers` with only `death` → throw. |
| Duplicate ID | Same ID in two tiers → throw. |
| Beat cap | 501 beats in one tier → throw. |
| Icon cap | 0 icons → throw; 65 icons → throw. |
| Blank field | `id: ''`, missing `headline` → throw. |
| Forward-compat | Unknown top-level key and unknown per-beat key → parses fine. |
| Empty tier | A tier with `beats: []` and valid icons → parses; `tier.isEmpty == true`. |
| Round trip | `decode(encode(pool))` equals the original, field for field. |

Content-count assertions currently living in `story_selector_test.dart` lines 21–33 move here.

### 9.4 `test/features/outcome/application/story_pool_repository_test.dart` (new)

Uses `MockClient` from `package:http/testing.dart` and a fake `PreferencesService`. No real
network, no real disk.

| Case (§10 step 5) | Test |
|---|---|
| **Offline first launch** | Empty prefs cache + a client that always throws `SocketException` → `load()` returns the bundled pool, `currentSource == bundled`, never throws. All 66 beats available. |
| **Offline after cache** | Prefs holds a valid payload + throwing client → `load()` returns the *cached* pool (not the bundled one), `currentSource == cache`. |
| **Corrupt payload (remote)** | 200 with `'{'` → `refreshIfStale` returns `false`, `current` unchanged, **prefs cache untouched** (the decode-before-persist invariant). |
| **Corrupt payload (cache)** | Prefs holds `'not json'` → `load()` falls back to bundled **and clears all three cache keys**. |
| **Oversized payload** | 200 with a 600 KB body → rejected, `current` unchanged, nothing persisted. Assert on byte length, not char count. |
| **304 handling** | Cached payload + ETag present → request carries `If-None-Match`; a 304 leaves `current` identical (`identical()`, not `==`), updates `fetchedAt` only. |
| ETag capture | A 200 with an `ETag` header persists it; the next call sends it. |
| TTL | Within `kStoryPoolTtl` → no HTTP call at all (assert request count 0). Past it → exactly one. |
| Non-200 | 404 / 500 → `false`, and `fetchedAt` **not** written. |
| Timeout | A client that never completes → `.timeout` fires at 4 s, `false`, no throw. |
| Single-flight | Two concurrent `load()` calls → one asset read, identical returned instance. |
| Schema mismatch | 200 with `schemaVersion: 2` → `false`, cache untouched, bundled/cached pool retained. |
| Content-version short-circuit | 200 with the same `contentVersion` as `current` → returns `false`, `current` identity unchanged. |

### 9.5 `test/features/outcome/application/remote_outcome_story_service_test.dart` (renamed + extended)

All four existing groups from `local_outcome_story_service_test.dart` port over against a stub
repository returning a fixture pool. Plus:

- Beat repeat-avoidance is now the *cycle* guarantee, not just adjacent-avoidance: over
  `pool.length` consecutive death fetches, all beats are distinct.
- Icon avoidance is unchanged (adjacent-only, options §8.5) — the existing test stands.
- `pruneAgainst` is called exactly once across 20 fetches against a stable pool, and exactly once
  more after the repository hot-swaps to a new pool instance.
- An empty tier yields `naFor` for that tier while the other two still resolve normally.
- `forceFailure` remains fully inert (existing tests, unchanged assertions).

### 9.6 Modified existing files

- `outcome_providers_test.dart` — replace hardcoded 2s with `kMinStoryLoadDuration` arithmetic so
  the three timing tests keep their meaning at 1200 ms.
- `story_renderer_test.dart`, `outcome_card_test.dart` — source fixtures from the parsed bundled
  asset instead of the deleted Dart lists. Add one renderer assertion: `render()` preserves `id`.
- `story_selector_test.dart` — drop the pool-count assertions (moved to §9.3); keep pure selector
  behaviour against synthetic pools; add the empty-pool guard test.

### 9.7 Not covered by automated tests (manual, tester scope)

- Real network against a real host — impossible until hosting exists (§3.2). The tester verifies
  the **placeholder** behaviour: fresh install, airplane mode off, placeholder URL → app works
  identically, no visible error, DNS failure swallowed.
- Web build CORS (§3.1 requirement 3) — verifiable only once a host is live.

---

## 10. New dependency and the new permission

### 10.1 `pubspec.yaml`

```yaml
  http: ^1.5.0
```

Confirmed as the right choice per technical-notes §3: one unauthenticated GET, no interceptors,
no retries, no multipart — `dio`'s surface area is unjustified. `package:http/testing.dart`
(`MockClient`) ships inside `http`, so **no new dev dependency is needed** for §9.4.

This is the app's **first networking package**. Current dependency list is deliberately lean and
has had zero networking until now.

### 10.2 `android.permission.INTERNET` — FLAGGED FOR COMPLIANCE REVIEW

**Verified against the working tree today:**

- `android/app/src/main/AndroidManifest.xml` — declares `POST_NOTIFICATIONS` and
  `RECEIVE_BOOT_COMPLETED`. **`INTERNET` is genuinely absent.**
- `android/app/src/debug/AndroidManifest.xml` — **does** declare `INTERNET`, with the stock
  Flutter comment ("required for development… hot reload").

> **This is a trap, and it is the single most likely way this feature ships broken.** Because the
> debug manifest grants `INTERNET`, **every fetch will work perfectly in `flutter run` and in all
> debug/profile testing, and then silently fail in the release build** — where it will be
> swallowed by `refreshIfStale`'s catch-all and degrade invisibly to the bundled asset. Nobody
> would notice. The remote-config feature would appear to work all the way through QA and be
> completely non-functional in production.

Required addition to **`android/app/src/main/AndroidManifest.xml`**, above the existing
`<uses-permission>` lines:

```xml
<!-- Remote outcome-story content (docs/architecture/remote-story-config-*.md):
     a single unauthenticated HTTPS GET of a static ~24 KB JSON file, at most
     once per 6 hours per device. No user data is transmitted, no analytics,
     no tracking, no third-party SDK. The app is fully functional offline via
     assets/stories_bundled.json. -->
<uses-permission android:name="android.permission.INTERNET" />
```

**For the app-store-specialist / play-store-specialist stages that follow implementation:**

1. This is the app's **first-ever internet permission**. It changes the permission set shown on
   the Play listing.
2. **Play Data Safety form** — the request sends no user data. It is an outbound GET with no body,
   no query parameters, no identifiers, no cookies. The only data leaving the device is what any
   HTTP request implies (IP address, User-Agent), received by the CDN. The Data Safety
   declaration should remain "no data collected" unless the chosen CDN's logging changes that
   assessment — **re-check once a host is actually picked**, since a host with analytics on by
   default would change the answer.
3. No cleartext-traffic exception is needed or wanted — §3.1 requirement 1 mandates HTTPS, and
   Android's default `usesCleartextTraffic=false` is left alone deliberately.
4. iOS: no `Info.plist` change would be needed (ATS permits HTTPS by default), but iOS is out of
   scope per the standing no-Apple-ID constraint.

---

## 11. Build order for the flutter-developer

Each step compiles and is independently reviewable.

1. `pubspec.yaml`: `http` dependency + the `assets/stories_bundled.json` asset entry. (Both
   content files are already written to the repo.)
2. `StoryBeat.id` + `fromJson`/`toJson`; fix `StoryRenderer.render` to thread `id`.
   **Everything breaks here** — that's expected and is the point of doing it second.
3. `story_pool.dart`, `story_pool_codec.dart` + `story_pool_codec_test.dart`. Get the bundled
   asset parsing green before anything else. Delete the four beat/icon Dart files at this point.
4. `story_cycle_selector.dart` + its test. Pure, fastest to get right, no dependencies.
5. Prefs: nine keys, nine accessor pairs, schema bump; `story_cycle_store.dart` + its test.
6. `story_config_endpoint.dart`, `story_pool_repository.dart` + its `MockClient` test.
7. `remote_outcome_story_service.dart`; delete `local_outcome_story_service.dart`; rename and
   port its test.
8. `outcome_providers.dart`: constants, four new providers, the one-line swap, 2s → 1200 ms.
9. `SplashScreen` warm-up line; `SettingsScreen` `cycleStore.reset()` line.
10. `AndroidManifest.xml` INTERNET permission — **as its own commit**, so the compliance stage has
    a clean thing to review.
11. Fix up the four modified existing test files.
12. `tools/story-content/README.md` per §3.4.

**Definition of done** additionally requires (CLAUDE.md rules 5–6): game-ux-designer sign-off on
the 1200 ms floor against the outcome-card mockup (options §10 step 4), and targeted test runs
over the new + four modified outcome test files — not the full suite.
