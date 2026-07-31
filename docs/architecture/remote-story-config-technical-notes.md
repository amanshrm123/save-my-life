# Remote Outcome-Story Config: Backend/Client-Integration Feasibility Notes

**Scope note:** this is a narrow technical-implementation gut-check, not the
product/cost decision. The product-architect owns the tradeoff call; this doc
answers "if we picked X, how hard is the client build and what breaks."

**Context this reasons over:**
- Zero backend/networking code exists today. `pubspec.yaml` has no `http`,
  `dio`, or any `firebase_*` package — only `shared_preferences`,
  `path_provider`, `share_plus`, `url_launcher`, notifications, audio, timezone.
- Content today is 3 hardcoded `List<StoryBeat>` (`deathBeats` — 50 entries,
  `survivedBeats`, `eternalBeats` — smaller pools) behind `story_beat.dart`'s
  3-field `StoryBeat(headline, named, anonymous)` model. Total payload size if
  serialized to JSON today is roughly 20–40 KB across all three pools — small
  by any of these mechanisms' limits.
- `OutcomeStoryService` is a 1-method abstract interface
  (`Future<OutcomeStoryContent> fetchStory(RunSummary summary)`) implemented
  today by `LocalOutcomeStoryService`, which also owns pure in-memory
  last-shown-index bookkeeping (`StorySelector`) and templating
  (`StoryRenderer`). `outcome_providers.dart`'s `outcomeStoryProvider` wraps
  the fetch in a `Future.wait([fetch, Future.delayed(2s)])` loading-floor.
- This content is cosmetic/flavor text, never competitively scored or
  monetized — no server-authoritative or IAP-receipt-validation concerns
  apply to this feature. Flagging that explicitly since it's usually the
  first thing to check and it's a clean "not applicable" here.

---

## 1. Firebase Remote Config

**Integration path:** add `firebase_core` + `firebase_remote_config`. Requires
`flutterfire_cli` (or manual) setup: register the app in a Firebase project,
generate `firebase_options.dart`, drop `google-services.json` into
`android/app/`, apply the Google Services Gradle plugin in
`android/app/build.gradle.kts` and project-level `build.gradle.kts`. iOS needs
`GoogleService-Info.plist` plus Firebase's CocoaPods integration in the
`ios/` Runner target — **blocked today per the standing constraint that there
is no Apple ID**, so iOS-side setup can't be verified/tested by anyone on
this team right now even though the Dart code would compile.

**Lifecycle in a Riverpod provider**, roughly:
```
final remoteConfigProvider = Provider<FirebaseRemoteConfig>((ref) {
  final rc = FirebaseRemoteConfig.instance;
  // one-time settings: minimumFetchInterval, fetchTimeout
  return rc;
});

// service impl:
await remoteConfig.setConfigSettings(RemoteConfigSettings(
  fetchTimeout: Duration(seconds: 10),
  minimumFetchInterval: Duration(hours: 1), // or Duration.zero in dev
));
await remoteConfig.setDefaults({'story_beats_v1': <bundled fallback JSON>});
await remoteConfig.fetchAndActivate(); // bool: did new config activate
final raw = remoteConfig.getString('story_beats_v1');
```
`fetchAndActivate()` is one round trip that both fetches and swaps in the
active config atomically; `getString` is then synchronous/cached locally by
the SDK. This needs `Firebase.initializeApp()` in `main()` before `runApp`,
which is itself an async step that has to complete before any provider using
Remote Config is touched — a new startup dependency that doesn't exist today
(today's `main()` only awaits `PreferencesService.create()`).

**App-size/cold-start overhead:** adding `firebase_core` +
`firebase_remote_config` pulls in Firebase's Android (Google Play Services
Measurement/Installations transitively) and iOS native SDKs. Realistic
Android APK/AAB size increase is in the low single-digit MB range once you
account for Play Services Installations + the Remote Config SDK itself (less
than adding full Analytics/Crashlytics, but not zero). Cold start adds a
Firebase App init step and, on first-ever launch, a network round trip if you
call `fetchAndActivate()` before showing content (mitigated by seeding
`setDefaults()` with the bundled pool so first launch never blocks on
network — see recommendation below). For an app that currently has **no**
native SDK dependencies at all, this is the largest structural change of the
three options, even though the Dart-level provider code is short.

**Fit for "one JSON blob":** clean. One string parameter (e.g.
`story_beats_v1`) holding `{"death": [...], "survived": [...], "eternal": [...]}`
covers it in a single fetch. Remote Config parameter values have historically
had a size ceiling in the tens-of-KB range per value — comfortably above the
~20–40 KB this content needs today, but worth re-confirming against current
Firebase docs before committing, since a 3x content-pool expansion could
approach it.

## 2. Cloud Firestore

**Same SDK-overhead question:** yes, identical `firebase_core` set up cost
as above, plus `cloud_firestore` (and its own native dependency, `Firestore`
itself, on both platforms) — comparable or slightly heavier footprint than
Remote Config alone since Firestore's client SDK includes an offline
persistence/cache layer you'd need to explicitly disable if you don't want it
(it defaults to on, which duplicates the disk-caching decision this doc is
already being asked to make at the app layer — see §6, this is a reason to
lean away from Firestore for this specific need).

**Document shape — 3 documents vs N-documents-per-beat:** 3 documents (one
per category, each an array field of beat maps) is clearly the right call
over one-document-per-beat, for both cost and code simplicity:
- Firestore bills **per document read**, not per byte within reasonable
  limits (1 MiB/doc cap, and this content is nowhere near that). 50 death
  beats as 50 separate documents means 50 reads to hydrate one pool — 50x the
  read cost of 1 document holding a 50-element array, for data that's always
  consumed as "the whole pool" anyway (this app already loads the entire pool
  into memory today as a static `List`, never a single random beat by ID).
  There's no query pattern here that benefits from per-beat documents (no
  filtering by beat, no per-beat pagination) — the founder's own "add/remove
  arbitrary content" mental model maps directly onto "add an element to the
  array," which a single document with array fields handles.
- 3 documents total (`config/deathBeats`, `config/survivedBeats`,
  `config/eternalBeats`, or one `config/storyBeats` doc with three array
  fields — even simpler, 1 read total) means the whole feature costs 1–3
  document reads per cold app-session, not per-run — the fetch happens once
  and is cached client-side for the rest of the session per the existing
  `outcomeStoryServiceProvider`'s session-scoped, non-`autoDispose` lifetime.

**One-shot fetch pattern (not a live listener):** straightforward —
`FirebaseFirestore.instance.collection('config').doc('storyBeats').get()`
returns a `Future<DocumentSnapshot>` once; never attach `.snapshots()` (that's
the listener/live-update API and is the wrong tool here — this content has no
real-time-update requirement, and a listener would also hold a persistent
open channel for zero benefit, working against the RAM-resident philosophy
for no gain). Explicitly pass
`GetOptions(source: Source.server)` on first-session fetch if you want to
bypass Firestore's own local cache and force a real network hit, or
`Source.cache` as an explicit offline fallback — this is the one place
Firestore's built-in caching genuinely could replace the app's own
`shared_preferences` cache, but doing so means depending on Firestore's
opaque on-disk SQLite cache instead of a value this app fully owns and
controls, which is a worse fit for "day-to-day debuggability" than a plain
JSON string in prefs.

## 3. Plain HTTP fetch of a static JSON file (`http`/`dio` + CDN)

This is the lightest structural change: add exactly one package
(`http` is simpler and sufficient here — `dio` is deliberately not the
recommendation because this feature is a single unauthenticated GET with no
interceptors/retries/multipart needs, and `dio`'s extra surface area for that
is unjustified for one call site), no native SDK, no `google-services.json`,
no platform project registration, nothing to configure per-platform.

**Fetch-parse-cache implementation, as a Riverpod provider replacing
`LocalOutcomeStoryService`** (prose sketch, not full code):
- New `RemoteOutcomeStoryService implements OutcomeStoryService` (same
  interface, so `outcome_providers.dart`'s `outcomeStoryServiceProvider`
  swaps one `Provider<OutcomeStoryService>` binding — nothing downstream
  changes).
- On construction (or lazily on first `fetchStory` call), it needs the three
  `List<StoryBeat>` pools in memory — same shape `LocalOutcomeStoryService`
  already needs, just sourced at runtime instead of compile time.
- A small internal `_ensureLoaded()` step: if pools aren't yet populated,
  `http.get(uri)` the JSON file, decode with `jsonDecode`, map each category's
  array into `List<StoryBeat>` via a small `StoryBeat.fromJson` factory
  (currently doesn't exist — `StoryBeat` has no `fromJson`/`toJson` today,
  this is new code, not a repurposing of existing code), then delegate to the
  exact same `StorySelector.pick` + `StoryRenderer.render` pipeline
  `LocalOutcomeStoryService` already uses unchanged.
- On fetch failure (network error, malformed JSON, `4xx`/`5xx`), fall back to
  a small **bundled-in-the-app copy** of the same content (the current
  hardcoded `deathBeats`/`survivedBeats`/`eternalBeats` lists don't need to be
  deleted — keep them as the offline/failure-fallback seed, imported by the
  new service instead of by `LocalOutcomeStoryService`) rather than
  `OutcomeStoryContent.naFor` — `naFor` should stay reserved for the
  already-tested simulated-failure path per `forceFailure`, not become the
  everyday behavior every time a player is offline. This is a meaningfully
  better player experience than Remote Config's/Firestore's typical "empty
  string/empty doc, throw and catch" failure shape, because a plain HTTP
  fetch has no SDK-level defaults mechanism to lean on — the app has to build
  its own, but that fallback already needs to exist for offline play
  regardless of mechanism chosen.
- Threading into `Future.wait([fetch, minDuration])`: no change needed at all
  — `outcomeStoryProvider` already treats `fetchStory` as an opaque
  `Future<OutcomeStoryContent>`; the HTTP round trip (or its cache-hit
  short-circuit) simply happens inside `RemoteOutcomeStoryService.fetchStory`
  or an earlier one-time `_ensureLoaded()` step, same as Remote Config's
  `fetchAndActivate()` or Firestore's `.get()` would.

**Cache-busting / CDN propagation delay (jsdelivr specifically):** jsdelivr's
`@main`/`@latest`-style URLs against a GitHub repo are cached aggressively at
the edge (commonly ~7 days, sometimes purgeable manually via jsdelivr's purge
API but not reliably fast) — a founder editing content and expecting it live
"now" will be the single biggest source of confusion with this option if not
handled deliberately. Two mitigations, both cheap:
1. **Commit-hash-pinned URL, bumped on every content edit** — e.g.
  `cdn.jsdelivr.net/gh/<org>/<repo>@<commit-sha>/story-beats.json`. This is
  cache-safe (each commit SHA is a permanently-immutable URL, safe to cache
  forever) but means the *app* needs to know which commit-SHA URL is current,
  which just relocates the "how does the client learn the new URL"
  problem — you'd need a second, small, aggressively-*not*-cached pointer
  file (or Remote Config, ironically, used only to hold that one URL string)
  to redirect at.
2. Simpler in practice: don't use jsdelivr's GitHub-fronting mode at all for
  content that changes on its own schedule — host the JSON on literally any
  static host that supports normal HTTP cache headers you control (GitHub
  Pages, a Cloudflare Pages/Worker, an S3/R2 bucket, even GitHub raw content
  directly, `raw.githubusercontent.com`, which is far less aggressively
  cached than jsdelivr's CDN layer) and set `Cache-Control: max-age=<a few
  minutes>` yourself. This sidesteps the propagation-delay problem entirely
  at the cost of picking a host, which is a product/cost call, not a
  client-integration one — flagging it here only because it changes which
  jsdelivr-specific mitigation is actually needed.

## 4. Testability across all three

`LocalOutcomeStoryService implements OutcomeStoryService` is trivially
fakeable today because the interface is one method returning a plain Dart
value — nothing about that changes for any of the three options, since the
interface itself never leaks SDK types:
- **Remote Config / Firestore:** in real code, `FirebaseRemoteConfig.instance`
  / `FirebaseFirestore.instance` are themselves not easily fakeable without
  either `fake_cloud_firestore`/a Remote Config test double package or an
  abstraction layer — but that concern lives *inside* the new
  `Remote*OutcomeStoryService` implementation, never inside
  `OutcomeStoryService` callers or `outcome_providers.dart`. Tests for
  `outcomeStoryProvider`, `StorySelector`, `StoryRenderer`, and the outcome
  screen keep using a fake/stub `OutcomeStoryService` exactly as today
  (there's already a precedent for this pattern in `FakeAdService`). The one
  new testing surface is the new service's own unit tests, which for
  Firebase-backed options do need either the official emulator suite or a
  fake-package dependency to exercise for real — a real (if small) new CI
  cost neither of the other two options has.
- **HTTP/CDN:** easiest to test of the three — `http.Client` is trivially
  mockable (`http.Client` -> inject a fake/mocked client, or use
  `package:http`'s `MockClient`), no emulator, no native SDK involved in
  tests at all.

**Verdict: none of the three breaks the existing interface/fakeability
story** — the abstraction boundary (`OutcomeStoryService`) was already drawn
in the right place for this. HTTP is simply the cheapest to write tests for;
Firebase options add one legitimate new test-infra dependency (emulator or
fake package) that doesn't exist in this repo today.

---

## 5. Adapter sketch for the most-buildable option

Given the zero-backend starting point, **plain HTTP + static JSON is the
straightforward build** (see summary below for the concrete opinion). Sketch:

- Add `http: ^1.x` to `pubspec.yaml` (single new dependency, no native
  project changes, no `google-services.json`/`Info.plist`, works on the
  already-supported Android+web dev targets).
- Add `StoryBeat.fromJson(Map<String, dynamic>)` (and, if useful for the
  bundled-fallback path or future authoring tools, `toJson`) to
  `story_beat.dart` — the one small addition to an existing domain type.
- New `lib/features/outcome/application/remote_outcome_story_service.dart`:
  `class RemoteOutcomeStoryService implements OutcomeStoryService`, holding
  the same six last-shown-index `int?`s and `StorySelector`/`StoryRenderer`
  instances `LocalOutcomeStoryService` already holds (literally copy that
  bookkeeping — it's pure and mechanism-agnostic), plus three
  `List<StoryBeat>` fields populated once per app session by an
  `_ensureLoaded()` that fetches-parses-or-falls-back-to-bundled-defaults.
- `outcome_providers.dart` changes exactly one line: the
  `outcomeStoryServiceProvider` body swaps
  `LocalOutcomeStoryService()` for `RemoteOutcomeStoryService(httpClient: ...)`.
  `outcomeStoryProvider`'s `Future.wait([fetch, minDuration])` idiom, the
  `autoDispose.family<OutcomeStoryContent, RunSummary>` shape, and every
  downstream widget are untouched — this is the whole point of the interface
  existing.
- `death_beats.dart`/`survived_beats.dart`/`eternal_beats.dart` are kept, not
  deleted — they become the compiled-in fallback content
  `RemoteOutcomeStoryService` falls back to on any fetch/parse failure
  (matching `OutcomeStoryContent`'s own existing "never throw, degrade
  instead" philosophy already documented on the interface).

---

## 6. Caching recommendation

**Recommendation: `shared_preferences` storing the raw fetched JSON string —
not a `path_provider` file cache.**

Reasoning, explicitly against the RAM-resident philosophy (repo CLAUDE.md
rule 7):
- The content is small (tens of KB today, unlikely to grow past low
  hundreds of KB even with generous future expansion) — well within
  `shared_preferences`' comfortable range (it's backed by a flat key-value
  store, not a database; a single ~50–200 KB string value is not the kind of
  usage pattern that stresses it, unlike, say, storing a growing per-run
  history there).
- Adding `path_provider`-based file caching would introduce a *second*
  persistence mechanism into an app whose only existing durable-storage
  pattern is `PreferencesService` — the whole app's persistence surface today
  is deliberately one class, one file-format decision (`shared_preferences`),
  documented explicitly in `preferences_service.dart` as "a write-through
  durability backup only — the app's in-memory providers are the runtime
  source of truth." A file cache would be a second, parallel durability
  mechanism doing the exact same job (surviving a cold start until the next
  successful re-fetch), for content an order of magnitude smaller than what
  `shared_preferences` already routinely handles elsewhere in this app. That
  is disk-sprawl the RAM-resident philosophy explicitly wants to avoid when
  something lighter already suffices — and here, something lighter clearly
  suffices.
- The RAM-resident philosophy's actual concern (per rule 7) is about the
  *runtime* state — the parsed `List<StoryBeat>` pools should live purely as
  an in-memory field on `RemoteOutcomeStoryService`, populated once per app
  session and never round-tripped through disk mid-session. The
  `shared_preferences` string is purely a cold-start bootstrap value (fetch
  fresh in the background every session; and only fall back to reading the
  cached string, then to the compiled-in bundled defaults, if that session's
  fetch fails) — it is never the runtime source of truth, exactly mirroring
  how every other `PreferencesService` field in this app already behaves. No
  new architectural pattern is introduced; this reuses the existing one for a
  new field.
- Practical failure modes to call out, per rule 7: (a) a **corrupt/truncated
  cached JSON string** (e.g. previous write cut short by an app kill) — mirror
  `PreferencesService`'s existing pattern exactly: wrap the read+decode in a
  `try/catch` and fall back to the compiled-in bundled `StoryBeat` lists,
  never throw into the UI, same shape every other prefs read here already
  uses; (b) **holding onto the raw JSON string in memory after parsing** — no
  reason to; decode once at load time into the `List<StoryBeat>` pools and let
  the raw string go out of scope, don't keep both representations resident;
  (c) **unbounded growth if the founder keeps adding content over time and
  the string is never pruned** — not a near-term concern at current pool
  sizes, but worth a soft ceiling/warning if pool sizes are ever expected to
  reach the high hundreds of entries, since at that point re-litigating
  file-based caching would become reasonable (not today).

---

## Summary (for the requester)

**Plain HTTP fetch of a static JSON file (`http` package) is the most
straightforward option to build from this app's current zero-backend
state** — one new dependency, no native SDK, no per-platform
`google-services.json`/`Info.plist` setup (relevant since iOS is currently
blocked on no Apple ID anyway), and it slots behind the existing
`OutcomeStoryService` interface with a one-line change in
`outcome_providers.dart`. Firebase Remote Config is the next most reasonable
if the founder specifically wants Firebase's console/dashboard config UI
rather than editing a JSON file directly, but it's a materially bigger
structural addition (first-ever native SDK dependency, `Firebase.initializeApp()`
startup step, per-platform registration). Firestore is the weakest fit here —
its live-listener/offline-persistence machinery solves problems this
"fetch-once, cache client-side" content doesn't have, and 3 documents (one
per category) is the right shape *if* Firestore is chosen, never
one-document-per-beat.

**Caching: use `shared_preferences` for the raw JSON string, not a
`path_provider` file.** It reuses this app's one existing persistence
mechanism instead of adding a second, for a payload well within
`shared_preferences`' normal range — and it stays a pure cold-start bootstrap
value, never the runtime source of truth, matching this app's RAM-resident
philosophy exactly as every other cached field in `PreferencesService`
already does.
