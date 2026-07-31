# Remote Story Config — Options Comparison & Recommendation

**Status:** Decision document. Nothing implemented. Written for the founder to pick from.
**Date:** 2026-07-31
**Scope:** Outcome-card story content (headline + story) — how to host it, how to edit it,
how to stop repeats, and what the loading screen should do once a real fetch exists.

---

## 0. What we're actually moving

Today all card copy is compiled into the binary:

| File | Contents |
|---|---|
| `lib/features/outcome/domain/death_beats.dart` | 50 beats |
| `lib/features/outcome/domain/survived_beats.dart` | 10 beats |
| `lib/features/outcome/domain/eternal_beats.dart` | 6 beats |
| `lib/features/outcome/domain/story_icons.dart` | 6 / 5 / 4 emoji |

**66 beats total.** As JSON that is roughly **15–25 KB uncompressed, ~6 KB gzipped.**

That number matters more than anything else in this document. This is a *tiny, rarely-changing,
non-user-generated, read-only text blob*. It is the single cheapest category of thing to host on
the internet. Any option below can serve it for $0 at a few thousand DAU. So **cost is almost
never the deciding factor here — editing ergonomics and setup burden are.**

### The one architectural rule that shapes all costing

**The app must fetch the pool once per session (or less), not once per outcome card.**

The whole 66-beat pool lives in RAM as immutable objects (~20 KB). The outcome card selects from
memory. If we instead fetched per card, we'd 3x the request volume for zero benefit and break the
RAM-resident design in CLAUDE.md rule 7. Every cost figure below assumes:

> 3,000 DAU × 1.5 sessions/day × 1 config fetch per session ≈ **4,500 fetches/day ≈ 135k/month**,
> ~20 KB each ≈ **90 MB/day worst case**, and far less in practice once `ETag`/`If-None-Match`
> makes most responses an empty `304 Not Modified`.

### Separate the two jobs

Most of the confusion in this decision comes from conflating them:

- **Authoring surface** — where the founder types the words. Wants: friendly UI, no JSON syntax
  errors, revision history.
- **Delivery surface** — what the phone actually GETs. Wants: free, fast, cacheable, boring,
  no SLA drama.

The best answer for each is **not the same product**, and you don't have to pick one product that
does both.

---

## 1. Option A — Static JSON on a CDN (Cloudflare Pages / R2), plain HTTP GET

A `stories.json` file in a Git repo, auto-deployed to Cloudflare Pages on push. App does
`GET https://content.stayalive.app/stories.json` with the `http` package.

- **Cost at 3k DAU:** **$0.** Cloudflare Pages free tier is unlimited bandwidth and unlimited
  requests; 20,000 files per site, 25 MiB per file, 500 builds/month. We use one file and maybe
  four builds a month. R2's free tier (10 GB storage, 10M Class B reads/month, **zero egress
  fees, permanently**) is the same story if you'd rather upload a file than push a commit.
- **Cost beyond free tier:** There is effectively no beyond. You would need ~50 million sessions
  a day to make this interesting.
- **How the founder edits:** Open the repo on github.com, click the pencil icon on
  `stories.json`, type, click "Commit changes". Cloudflare rebuilds in ~30 seconds. **This is raw
  JSON editing** — a missing comma breaks the file. Mitigated by a CI check that refuses to
  deploy invalid JSON (see Option E, which is exactly this option plus a nicer front door).
- **Implementation complexity:** **Lowest of every option here.** One new pub dependency
  (`http`). No native config, no `google-services.json`, no Gradle plugin, no extra app size
  beyond a few KB, no SDK init on startup. Identical behaviour on Android and web. We hand-roll
  the caching (~80 lines), which we'd want to own anyway.
- **IDs:** Authored into the JSON as a literal `"id"` field. Fully manual — but see §7: *every*
  option ends up here except Firestore, and manual IDs in the content are the most durable form
  because they survive changing backends.
- **Offline:** We control it. `ETag` + cached file in the app-support directory (via
  `path_provider`, already a dependency) + bundled asset fallback. Works fully offline forever
  after first launch, and works offline on *first* launch too thanks to the bundled asset.
- **Rollback:** **Best in class.** `git revert`, push, live in 30 seconds. Full diff history of
  every word ever changed, with authorship and timestamps.

---

## 2. Option B — Firebase Remote Config (one JSON parameter)

One RC parameter, `outcome_story_pool`, whose value is the JSON blob. Edited in the Firebase
console.

- **Cost at 3k DAU:** **$0.** RC moved to usage-based pricing on **1 Sep 2026**: 100,000 fetch
  requests/day free on both Spark and Blaze, then $0.06 per 10,000 up to 10M/day. We'd use ~4,500
  a day — about 4.5% of the free allowance. You'd need ~65,000 DAU before you paid a cent, and
  even 500k DAU is roughly $4/day.
- **Size limits:** 3,000 parameters max, and **1,000,000 characters total across all parameter
  values** per project. Our pool is ~25,000 characters, so there's room for roughly 2,500 stories
  before the cap is a concern. Not a constraint.
- **How the founder edits:** Firebase console → Remote Config → click the parameter → **a
  textarea containing raw JSON**. So it is *still raw JSON editing*, just in a console instead of
  GitHub, and with a worse editor (no syntax highlighting worth the name, no diff view before
  publish). What the console *does* add is genuinely good: a staged "publish" step with a change
  description, version history, and a one-click rollback to any previous version.
- **Implementation complexity:** **Highest of the shortlist.** Requires `firebase_core` +
  `firebase_remote_config`, a Firebase project, `google-services.json`, the Google Services Gradle
  plugin, web SDK config, and Firebase init in `main()` before `runApp`. Adds roughly 1–2 MB to
  the APK and measurable cold-start time to an app whose entire current dependency list is
  deliberately lean and has **zero networking packages**. This is the option that most changes the
  shape of the project.
- **What you get for that weight:** RC's SDK handles fetch, cache, offline persistence and the
  minimum-fetch-interval throttle for you. We would not hand-roll caching. That's a real saving —
  maybe 80 lines and a class of bugs.
- **IDs:** Manual, in the JSON. Same as Option A.
- **Offline:** Excellent and free — RC persists the last activated values on device and serves
  them with no network.
- **Rollback:** Excellent. Version history + rollback button in the console.
- **Strategic note:** RC was free-and-unmetered until Sep 2026 and is now metered. That's a signal
  worth weighting: it's a product whose pricing can change under you, for a job a static file does
  for free forever.

---

## 3. Option C — Cloud Firestore (a collection of story documents)

A `stories` collection, one document per beat, with a `tier` field.

- **Cost at 3k DAU — and this one genuinely depends on your data model:**
  - **One document holding the whole pool:** 4,500 reads/day against a 50,000 reads/day free
    tier → **$0**. Fine.
  - **One document per story (the natural, nice-to-edit model):** every fetch reads 66 documents
    → **297,000 reads/day**. Minus the 50,000 free = 247,000 billable/day at $0.18 per 100k
    ≈ **$0.44/day ≈ $13/month**, scaling linearly with both DAU *and* the number of stories you
    write. Adding stories increases your bill. That is a bad incentive for a content pool.
  - So the affordable Firestore model is "one big JSON document" — at which point you've rebuilt
    Option A with a much heavier SDK.
- **How the founder edits:** Firestore console gives a **per-record form UI** — add a document,
  fill in `headline`, `named`, `anonymous`. This is the nicest *console* editing experience of the
  Firebase options and the only one that isn't raw JSON. But it's slow for bulk work, there's no
  preview, and critically: **edits go live the instant you press save.**
- **Implementation complexity:** Highest overall. Full Firebase native setup *plus*
  `cloud_firestore`, which is the largest of the Firebase SDKs. Also needs security rules written
  correctly (public read, no write) or you have an open database.
- **IDs:** **The only option that gives you IDs for free.** Firestore document IDs are stable,
  unique, and preserved across edits by the platform. Genuinely useful for §7's dedup logic. You'd
  still want to author readable custom IDs rather than accept the random auto-IDs.
- **Offline:** Good — Firestore has built-in offline persistence.
- **Rollback:** **None.** There is no version history and no undo. A bad edit is live immediately
  and permanently until manually corrected. For a content system a non-technical person edits,
  this is the most serious flaw on this page.

---

## 4. Option D — Google Sheets as the source (published JSON/CSV, or SheetDB/Sheety)

A spreadsheet with columns `id | headline | named | anonymous`, read by the app either directly
via Google's `gviz/tq` endpoint or through a middleware like SheetDB.

- **Cost at 3k DAU:**
  - **Direct `gviz`:** free, but undocumented, unversioned, no SLA, and Google throttles at its
    own discretion.
  - **SheetDB:** free tier is **500 requests per month**. We need ~135,000. Paid starts ~$9/month
    and the entry tiers are still capped well below our volume. **Effectively unusable as a direct
    client endpoint.**
  - **Sheety:** same shape, paid from ~$10/month.
  - **Airtable, for completeness:** free plan is **1,000 API calls per month**. Dead on arrival
    for direct client fetching, for the same reason.
- **How the founder edits:** **By far the best.** A spreadsheet. Sort, filter, bulk-paste from a
  doc, leave comments, invite a copywriter, see everything at once. No syntax to get wrong. This
  is the option a non-technical founder would actually enjoy using, and it's why this option can't
  simply be dismissed.
- **Implementation complexity:** Deceptively awkward. The `gviz` endpoint returns JSON wrapped in
  a JavaScript callback (`/*O_o*/google.visualization.Query.setResponse({...});`) that must be
  string-trimmed before parsing, the sheet must be world-readable (not just "published"), there's
  no `ETag`, no CDN, latency is 500–1500 ms, and the response format is not a stable contract.
- **IDs:** A manual `id` column. Easy for the founder to maintain; also easy to accidentally
  duplicate or renumber, so the pipeline must validate.
- **Offline:** Same hand-rolled caching as Option A, but without `ETag` support you always
  transfer the full payload.
- **Rollback:** Surprisingly good — Google Sheets version history lets you restore any prior state.
- **Verdict:** **Excellent authoring surface, poor delivery surface.** Don't point the app at it.
  Point a build step at it — which is Option E.

---

## 5. Option E — Recommended: Sheet (authoring) → GitHub Action (validate + publish) → CDN (delivery)

This is Option A's client, unchanged, with Option D's editing experience bolted on the back.

```
Founder edits Google Sheet
        │  (or edits stories.json directly on github.com — both work)
        ▼
GitHub Action (manual "Run workflow" button, or nightly)
   ├── pulls the sheet as CSV
   ├── validates: IDs unique, IDs non-empty, no ID reused from the retired list,
   │              placeholders are only {name}/{min}/{peak},
   │              {name} appears in `named` and never in `headline`/`anonymous`,
   │              row count sane, total payload < 512 KB
   ├── derives `named` + `anonymous` from one `verbPhrase` column
   │   (mirroring today's `_d()` helper, so the founder writes 2 fields, not 4)
   └── commits stories.json  ─────►  Cloudflare Pages auto-deploys
        ▼
App: GET https://content.stayalive.app/stories.json  (If-None-Match)
```

- **Cost:** **$0.** GitHub Actions is free on public repos and 2,000 minutes/month on free private
  accounts; this job runs for ~20 seconds a few times a month. Cloudflare Pages is free and
  unlimited. Google Sheets is free.
- **Editing:** A spreadsheet, then one button click. Or, on day one before the Action exists,
  editing the JSON on github.com directly.
- **Complexity:** Client is identical to Option A (one `http` dependency, no native setup). The
  Action is ~60 lines of Python or Node, written once.
- **IDs:** Manual column, but **machine-validated** — the Action is the thing that guarantees IDs
  are unique and never silently recycled, which is the property §7's dedup logic actually depends
  on. No backend gives you that for free.
- **Offline:** Same as Option A. `ETag` + cached file + bundled asset.
- **Rollback:** Two independent layers — Git revert on the published JSON, *and* Sheets revision
  history on the source. Best of any option here.
- **Publish latency:** ~1 minute (Action + deploy). Irrelevant for content that changes monthly.
- **Crucially, this is phaseable:** ship the client half now, add the Sheet half later, with
  **zero client changes**. The app only ever knows about one URL.

---

## 6. Comparison table

| | **A. Static JSON + CDN** | **B. Firebase Remote Config** | **C. Firestore** | **D. Sheets direct / SheetDB** | **E. Sheet → Action → CDN** |
|---|---|---|---|---|---|
| **Cost @ 3k DAU** | $0 | $0 (4.5% of free tier) | $0 (single doc) / **~$13/mo** (doc-per-story) | $0 (gviz) / **unusable** (SheetDB free) | **$0** |
| **Cost @ 50k DAU** | $0 | $0 | $0 / ~$230/mo | n/a | **$0** |
| **Founder edits by** | Raw JSON on github.com | Raw JSON in a console textarea | Per-record console forms | **Spreadsheet** | **Spreadsheet** (+ 1 click) |
| **Syntax errors possible** | Yes (CI-guardable) | Yes (no guard) | No | No | No |
| **New pub deps** | `http` | `firebase_core`, `firebase_remote_config` | `firebase_core`, `cloud_firestore` | `http` | `http` |
| **Native setup** | **None** | `google-services.json`, Gradle plugin, web config | Same + security rules | **None** | **None** |
| **App size / cold start** | ~0 | +1–2 MB, +init | +2–3 MB, +init | ~0 | ~0 |
| **Stable IDs** | Manual in JSON | Manual in JSON | **Platform-assigned** | Manual column | Manual + **CI-validated** |
| **Offline caching** | Hand-rolled (~80 LOC) | **Built into SDK** | **Built into SDK** | Hand-rolled, no ETag | Hand-rolled (~80 LOC) |
| **Rollback** | **Git revert** | Console version history | **None** | Sheets history | **Git + Sheets** |
| **Vendor/pricing risk** | Very low | Medium (just went metered) | Medium | High (undocumented endpoint) | Very low |
| **Time to first working version** | ~1 day | ~2 days | ~2–3 days | ~1 day | ~1 day client, +0.5 day Action |

---

## 7. Recommendation (ranked)

### 1st — Option E, delivered in two phases

**Phase 1 (now): Option A.** `stories.json` committed to a repo, served by Cloudflare Pages,
fetched with the `http` package, `ETag`-cached to a local file, with the current hardcoded pool
shipped as a bundled asset fallback. One dependency, zero native config, $0, git-versioned,
instantly revertable. This alone satisfies "add or remove a story without redeploying the app."

**Phase 2 (when the founder actually finds JSON editing annoying): the Sheet + Action.** No client
change. Purely additive. Defer it until it's earned.

**Why this wins:** the ask is "the best and cheapest way." The cheapest way to serve 20 KB of text
is a static file on a CDN with free egress, and nothing will ever beat $0. The *best* way for a
non-technical person to edit content is a spreadsheet. Option E is the only one that gets both,
and it gets them without adding Firebase's native setup, app-size, and cold-start tax to an app
that has deliberately shipped with no networking dependency at all. It also keeps the content in
Git, which means every word change is diffable and revertable — a property Firestore doesn't have
at any price.

### 2nd — Option B, Firebase Remote Config

A completely defensible choice, and the right one **if** you expect to want Firebase anyway
(Analytics, Crashlytics, A/B testing story variants, staged rollouts by user segment). RC's
built-in caching, offline persistence, version history and rollback button are genuinely good, and
the free tier is 20x our need. The cost is real though: it changes this app from
"zero-networking-dependency, lean cold start" to "Firebase app," for content editing that is
*still raw JSON in a textarea*. If Firebase is coming later regardless, this becomes 1st.

### 3rd — Option D, Sheets direct

Only as a deliberate throwaway spike to test whether remote content is worth doing at all. The
undocumented endpoint and lack of caching make it unsuitable for shipping.

### 4th — Option C, Firestore

Overkill. It's a real-time query database being used as a text file, it's the heaviest SDK, and
**it has no rollback** — which is the single worst property to have in a system a non-technical
person edits directly. Its one genuine advantage (platform-assigned stable IDs) is worth less than
it sounds, because §7's validation approach gets you the same guarantee for free.

### Honourable mentions considered and rejected

- **Firebase Hosting** (Spark: 10 GB storage, **360 MB/day transfer**) — free and simple, but
  360 MB/day is ~18,000 full payload fetches/day. Fine at 3k DAU, breaks around 12k DAU. Cloudflare
  Pages has no such ceiling, so there's no reason to accept one.
- **GitHub Pages** — free, but a *soft* 100 GB/month bandwidth limit and explicitly not intended as
  an app API backend. Works, but Cloudflare Pages is the same effort with none of the ambiguity.
- **jsDelivr fronting GitHub raw** — free, unlimited, production-grade. The catch: **branch-pinned
  URLs are cached for 12 hours**, and cache purging requires emailing them for API access. A
  12-hour unpredictable publish delay is tolerable for monthly copy edits but annoying when you're
  fixing a typo a player screenshotted. Cloudflare Pages purges on deploy.
- **`raw.githubusercontent.com` directly** — don't. Rate-limited, not a CDN, and GitHub's terms
  discourage it.
- **Sanity / other headless CMS** — free tier is generous (1M CDN requests/month, 250k API
  requests/month, 10k documents) and the editing UI is excellent. Rejected as over-engineered for
  66 rows of text, and the free tier **hard-blocks rather than overages**, meaning a traffic spike
  takes your content offline rather than costing you $2.
- **Supabase** — free projects **pause after 7 days of inactivity**. Disqualifying for a
  read-mostly config endpoint.
- **Do nothing (ship content in app updates)** — worth stating as the baseline: it costs $0 and
  zero engineering, but a typo fix takes a full store review cycle on both platforms. That's the
  actual pain being solved.

---

## 8. Point 2 — the dedup-until-exhausted design (backend-independent)

This design is **identical regardless of which option above is chosen.** It depends only on the
pool having stable IDs.

### 8.1 `StoryBeat` gains an `id`

```dart
class StoryBeat {
  const StoryBeat({
    required this.id,          // NEW
    required this.headline,
    required this.named,
    required this.anonymous,
  });
  final String id;
  // ...
}
```

**ID format:** `<tier>_<zero-padded 3-digit sequence>` — `death_001`, `survived_007`,
`eternal_003`.

**Rules, which the publish-time validator enforces:**

1. IDs are **immutable**. Editing a story's wording keeps its ID. Only assign a new ID when it's
   genuinely a *new* story.
2. IDs are **never recycled**. Delete `death_017` and the number is retired forever; the next new
   death beat gets `death_051`, not `017`. (Recycling would resurrect a stale "seen" entry and
   hide a brand-new story from returning players.)
3. IDs are unique within the whole file, not just within a tier.

Why not a slug like `death_blinked_gone`? Because the founder will inevitably reword the headline
and then feel obliged to rename the slug, silently creating a "new" story and re-showing it to
everyone. Opaque sequence numbers remove that temptation. Why not platform-assigned IDs (Firestore)?
Because they'd lock the ID space to one vendor; IDs living in the content survive a backend swap.

### 8.2 Persistence — matching the existing `PreferencesService` pattern

New keys in `lib/core/persistence/preferences_keys.dart`, and bump
`kPrefsSchemaVersion` from `1` to `2` (no migration code needed — absent keys already default to
empty, which is a correct fresh-cycle state):

```dart
/// IDs of story beats already shown in the current cycle, per tier.
/// StringList, default [].
const String kKeySeenStoryIdsDeath = 'seen_story_ids_death';
const String kKeySeenStoryIdsSurvived = 'seen_story_ids_survived';
const String kKeySeenStoryIdsEternal = 'seen_story_ids_eternal';

/// The single most recently shown beat ID per tier, used only to avoid an
/// immediate repeat across a cycle-reset boundary. String, default ''.
const String kKeyLastStoryIdDeath = 'last_story_id_death';
const String kKeyLastStoryIdSurvived = 'last_story_id_survived';
const String kKeyLastStoryIdEternal = 'last_story_id_eternal';
```

Accessors follow the file's existing shape exactly: every read `try`/`catch`es to a documented
default, every write swallows its own failure. Six getters + six setters, using
`getStringList`/`setStringList` and `getString`/`setString`.

`clearAll()` already wipes these — correct, "Reset progress" should restart the story cycle.

### 8.3 The selection algorithm

A new `StoryCycleSelector` in `lib/features/outcome/domain/`, sitting alongside (not replacing)
the existing `StorySelector` — the old index-based `pick` is still exactly right for **icons**
(see 8.5).

```
pick(pool, seenIds, lastShownId, random):
  candidates = pool.where(b => !seenIds.contains(b.id))

  if candidates.isEmpty:                       // cycle exhausted
      seenIds.clear()                          // start a new cycle
      candidates = pool.where(b => b.id != lastShownId)
      if candidates.isEmpty:                   // pool of exactly 1
          candidates = pool

  chosen = candidates[random.nextInt(candidates.length)]
  seenIds.add(chosen.id)
  lastShownId = chosen.id
  return chosen
```

Notes on the reset boundary: the just-shown beat is excluded from the *first* draw of the new
cycle but is **not** added to the fresh `seenIds`, so it remains eligible for the rest of that
cycle. This mirrors `StorySelector.pick`'s `avoidIndex` intent — close the jarring
back-to-back-identical case, don't over-engineer beyond it.

Uniform draw from the surviving candidates is `O(n)` over a 50-element list. Irrelevant, and far
simpler than maintaining a shuffled deck.

### 8.4 When the remote pool changes shape

This is exactly why the seen-set is keyed by **ID**, never by index or count:

| Change | Behaviour | Correct? |
|---|---|---|
| **Story added mid-cycle** | Its ID isn't in `seenIds`, so it's immediately a candidate | Yes — new content surfaces to existing players right away, which is the point of remote config |
| **Story removed mid-cycle** | Its ID lingers in `seenIds` but no longer matches anything in the pool. Exhaustion is computed as `candidates.isEmpty` *against the live pool*, so a stale ID can never deadlock the cycle | Yes — degrades to a no-op |
| **Story reworded** | ID unchanged → still counts as seen | Yes |
| **Whole tier replaced** | Every old ID is stale, every new ID unseen → effectively a fresh cycle | Yes |
| **Indices shift (reorder)** | Irrelevant, nothing is index-keyed | Yes |

**Pruning:** once per pool load (i.e. when a fetched or cached pool is installed, not per card),
intersect each tier's `seenIds` with that tier's live ID set and persist the pruned result. This
bounds the stored set at the pool size forever and self-heals accumulated cruft. Without pruning,
a founder churning content over two years could grow the set unboundedly — small in absolute
terms, but the app's RAM-resident design (CLAUDE.md rule 7) says bound it anyway.

**Memory-safety notes for this feature (rule 7):**
- Seen-set is `Set<String>` in memory, one per tier, bounded by pool size (~66 × ~12 bytes ≈ 800
  bytes total). Prefs is the write-through backup, memory is the source of truth — matching the
  documented `PreferencesService` contract.
- Parsing must cap: reject a downloaded payload over **512 KB**, and cap each tier at **500
  beats**, so a bad edit or a hostile response can't balloon the resident pool.
- Pool is parsed exactly once per load into `List.unmodifiable`; the outcome card allocates
  nothing but the chosen beat.
- The `candidates` list allocated per pick is ≤ 50 references and is immediately garbage; no
  per-run accumulation, unlike a naive "history log" design.

### 8.5 Icons stay as they are

The three icon pools are 4–6 entries. Applying dedup-until-exhausted to a 4-item pool makes the
sequence *more* predictable, not less. Keep the existing `StorySelector` + `avoidIndex` in-memory
behaviour for icons. Do ship the icon arrays in the remote payload though, so emoji can be
tuned without a redeploy too.

### 8.6 JSON schema

```json
{
  "schemaVersion": 1,
  "contentVersion": 42,
  "updatedAt": "2026-07-31T10:00:00Z",
  "tiers": {
    "death": {
      "icons": ["⏰️", "😵", "💀", "🪦", "⚰️", "💥"],
      "beats": [
        {
          "id": "death_001",
          "headline": "Blinked. Gone.",
          "named": "{name} blinked at the exact wrong moment.",
          "anonymous": "Blinked at the exact wrong moment."
        }
      ]
    },
    "survived": { "icons": [], "beats": [] },
    "eternal":  { "icons": [], "beats": [] }
  }
}
```

`schemaVersion` lets the client reject a future format it can't parse (falling back to cache/asset
rather than crashing). `contentVersion` is a monotonic counter, useful for logging and for a
"don't bother re-parsing" short-circuit.

**Migration note:** today's `death_beats.dart` generates `named`/`anonymous` from a single
`verbPhrase` via the `_d()` helper. The wire format carries all three final strings explicitly.
The Sheet (Option E) should keep a `verbPhrase` column and let the publish Action do the
derivation, so the founder still authors two fields per death beat, not four. The initial
`stories.json` is generated once by running the existing helpers and dumping the result.

---

## 9. Point 3 — loading-screen timing once the fetch is real

### 9.1 Move the fetch off the outcome card

The most important change: **the network fetch is not on the outcome card's critical path at all.**

- A `storyPoolProvider` resolves the pool at app start from **cached file → bundled asset**, which
  is synchronous-fast, and kicks off a **background** refresh.
- The background refresh only runs if `now − lastFetchAt > 6 hours` (a `kStoryPoolTtl`), with a
  **4-second timeout**. On success it writes the new file + `ETag` + timestamp and swaps the
  in-memory pool. A swap never happens mid-card; the next card picks it up.
- `outcomeStoryProvider` therefore still resolves from memory in microseconds.

This is the design that keeps us inside the 100k/day, 360 MB/day, whatever-tier free limits with
enormous headroom, and it's why "1 fetch per session" is the number used throughout §1–§6.

### 9.2 The loading floor

**Keep the `Future.wait([fetch, minFloor])` idiom exactly as it is** in
`outcome_providers.dart` — it's the right shape, it matches `SplashScreen`, and it belongs in the
provider layer rather than the data source.

**Change `kMinStoryLoadDuration` from 2 s to 1200 ms.** The current 2 s was sized to feel like a
plausible network round-trip while masking instant local data. Now that it's honestly just
perceived-polish framing on the reveal beat, 2 s is a long time to stare at a spinner *every
single run* in a game whose loop is seconds long. 1200 ms still reads as a deliberate dramatic
pause; 2 s starts reading as jank. This is a UX judgement worth checking with the game-ux-designer,
but the engineering point is that the floor is now purely a design lever, not a lie.

**Add a `kStoryFetchTimeout` of 4 s** guarding the rare case where the outcome card is reached
before the very first pool load has completed (cold first launch, slow disk). On timeout, fall
through to the bundled asset. So the card is never blocked for more than ~4 s in the worst case
and ~1.2 s in every realistic case.

### 9.3 Error / offline fallback chain

```
in-memory pool  →  cached stories.json (app support dir)  →  bundled asset stories.json
                                                          →  OutcomeStoryContent.naFor
```

The key consequence: **because a valid pool ships inside the binary, the first three steps can
essentially never all fail.** So:

- **No error UI, no retry button, no offline banner.** The existing contract in
  `OutcomeStoryService` ("never throws; a failed fetch resolves to `naFor`") is preserved exactly,
  and the UI keeps its single code path.
- `OutcomeStoryContent.naFor` stays exactly where it is and keeps its current role: genuine
  defence-in-depth, reachable only if the bundled asset itself is corrupt — i.e. effectively never
  in production, but still the thing `forceFailure` and the screen's `error:` branch exercise in
  tests.
- `isFallback: true` becomes more useful than it is today: it's the flag a future analytics hook
  would read to notice "we're serving bundled content because remote has been failing," which is
  exactly the signal you want if a bad deploy takes the JSON offline.

A nice property of this chain: a player who installs the app on a plane and never connects still
gets the full 66-story experience from the bundled asset, with dedup working normally, and
silently upgrades to remote content the first time they get signal.

---

## 10. Suggested next steps once a decision is made

1. Founder picks an option (this doc's recommendation: **E, phased — start with A**).
2. product-architect writes the implementation spec (schema, provider graph, service boundaries).
3. flutter-developer implements: `id` on `StoryBeat`, `StoryCycleSelector`, six new prefs
   accessors, `RemoteOutcomeStoryService` + cache layer, bundled asset, provider rewiring, timing
   constants.
4. game-ux-designer signs off on the 1200 ms floor against the outcome-card mockup.
5. tester covers: fresh cycle, mid-cycle, exhaustion + reset, boundary no-repeat, story
   added/removed mid-cycle, stale-ID pruning, offline first launch, offline after cache, corrupt
   payload, oversized payload, 304 handling.

---

## Sources

- [Firebase Remote Config pricing](https://firebase.google.com/docs/remote-config/pricing)
- [Firebase Remote Config parameters & limits](https://firebase.google.com/docs/remote-config/parameters)
- [Firebase Remote Config pricing change 2026 (commentary)](https://hyperstone.ai/blog/firebase-remote-config-pricing/)
- [Firestore pricing](https://firebase.google.com/docs/firestore/enterprise/pricing)
- [Firebase pricing overview 2026](https://www.budgetforge.dev/tools/firebase-pricing-2026)
- [Cloudflare Pages pricing & limits 2026](https://www.devtoolreviews.com/reviews/cloudflare-pages-pricing-bandwidth-limits-2026)
- [Cloudflare R2 pricing / free tier](https://developers.cloudflare.com/r2/pricing)
- [Cloudflare R2 free tier guide 2026](https://nubbo.app/blog/cloudflare-r2-free-tier/)
- [GitHub Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits)
- [jsDelivr](https://github.com/jsdelivr/jsdelivr) and [jsDelivr purge tool](https://www.jsdelivr.com/tools/purge)
- [SheetDB pricing / review](https://ajmani.dev/sheetdb-review/)
- [Airtable free plan limits 2026](https://aitoolpick.org/blog/airtable-free-plan-limits-2026/)
- [Sanity technical limits](https://www.sanity.io/docs/content-lake/technical-limits) and [Sanity pricing](https://www.sanity.io/pricing)
- [Supabase billing FAQ](https://supabase.com/docs/guides/platform/billing-faq)
