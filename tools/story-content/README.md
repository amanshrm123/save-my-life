# Story content — editing and publishing

This directory holds the **canonical editable source** for the outcome-card
story content that ships remotely (see
`docs/architecture/remote-story-config-implementation-spec.md` for the full
design; this file exists so someone editing content doesn't have to go read
that whole spec first).

## Why there are two copies of this content

| File | Role | Ships in the app? | Changes when? |
|---|---|---|---|
| `tools/story-content/stories.json` (this directory) | **Canonical editable source.** What you edit and upload to the CDN. In Phase 2 this becomes a GitHub Action's output instead of a hand-edit. | **No** — `tools/` is not under the Flutter `assets:` list. | Whenever content changes (weekly/monthly, no app release needed — that's the whole point of this feature). |
| `assets/stories_bundled.json` | **Compiled-in fallback snapshot**, used offline or before the first successful remote fetch. | **Yes** — a real Flutter asset. | Only at app-release time, deliberately, by copying the current `tools/story-content/stories.json` over it. |

These two files are byte-identical right after a release and are **expected
to diverge** afterwards — that divergence is the feature working as
designed: remote content moves ahead of whatever binary a player has
installed. There is deliberately no automated check that the two files are
equal; a test asserting that would fight the design.

## How to publish an edit

1. Edit `tools/story-content/stories.json` directly (any text editor — it's
   plain JSON).
2. Validate it's still valid JSON (e.g. `python3 -m json.tool
   tools/story-content/stories.json > /dev/null`, or paste into any JSON
   validator). A structurally invalid file is silently rejected by every
   installed client (they keep serving whatever they last had) — there is no
   error surfaced anywhere, so catching a mistake before upload is on you.
3. Bump `contentVersion` by 1 (lets already-fetched clients skip
   re-installing a payload with no new content — see the app's
   `StoryPoolRepository.refreshIfStale`).
4. Update `updatedAt` to the current UTC timestamp — informational only,
   **ignored entirely by the client**; it exists for humans reading the
   file.
5. Upload/commit the file to wherever `kStoryConfigUrl`
   (`lib/features/outcome/application/story_config_endpoint.dart`) points.
6. It goes live for:
   - a **new session** on any device (i.e. the app cold-started — killed
     and relaunched), immediately.
   - an **already-running session**: **never, no matter how long it runs.**
     The staleness check (`StoryPoolRepository.refreshIfStale`, gated by
     `kStoryPoolTtl`) only ever runs once per process, from the splash
     screen's one-time warm-up (`storyPoolProvider`). There is no periodic
     timer and no app-resume hook that re-triggers it, so a session that's
     already open will keep serving whatever content it started with until
     the player fully closes and reopens the app — at which point the next
     cold start picks up the new content (subject to `Cache-Control:
     max-age` and `kStoryPoolTtl` as above).
7. At the next app release, copy this file over `assets/stories_bundled.json`
   so the compiled-in fallback catches up too.

## The three ID rules (restated verbatim — highest-consequence rules in the whole feature)

Every beat's `id` (e.g. `death_017`) must be:

1. **Immutable** — once published, a beat's `id` never changes, even if you
   reword the beat.
2. **Never recycled** — a retired/deleted beat's `id` is never reused for a
   different beat, ever.
3. **Globally unique** — unique across all three tiers combined, not just
   within its own tier.

**A recycled ID silently hides new content from returning players.** The
client's dedup cycle is keyed on `id`, not position or content — if a new
beat reuses a retired ID, any player who already "saw" that ID (under the
old beat) will have the new beat silently marked as already-seen and it will
never surface for them until every other ID in that tier cycles through
first.

## Current highest ID per tier

**Update this line whenever IDs are added:**

- `death_050`
- `survived_010`
- `eternal_006`

The next new beat in a tier gets the next number up (e.g. the next death
beat is `death_051`), zero-padded to 3 digits.

## Emoji safety (rescued from the deleted `story_icons.dart`)

Icons are plain Unicode emoji strings in each tier's `icons` array. Some
emoji are riskier than others on the range of Android devices/system emoji
fonts this app targets:

- `⏰️` is U+23F0 + U+FE0F (multi-codepoint, not ZWJ) — fine as long as it's
  never `substring`'d, which it isn't (icons are display-only, never
  measured/indexed/truncated).
- Use `🆘`, never `🛟` — the ring-buoy (`🛟`) is Unicode 14.0/2021 and risks
  tofu-rendering (a blank box) on older Android system emoji fonts, which
  would ship straight into the rasterized shared PNG used for social
  sharing. `🆘` is Unicode 6.0/2010 and safe on every device this app
  targets.
- **Apply this test to any new emoji: if it postdates ~2015, don't.**
- `😮‍💨` contains a ZWJ (zero-width joiner); it is display-only and never
  measured, indexed, or truncated, so it's safe to use despite being a
  compound sequence.

## `updatedAt` is for humans only

The `updatedAt` field at the top of `stories.json` is **ignored entirely by
the client**. It exists purely so a human looking at the file (or a diff)
can tell when it was last touched. There's no need to keep it perfectly
accurate, but do update it on every edit as a courtesy to the next editor.

## Cloudflare Pages CORS (`_headers`)

If you host `stories.json` on Cloudflare Pages, it does **not** send
`Access-Control-Allow-Origin` by default for cross-origin requests — which
the Flutter **web** build (an active dev target for this app) needs. Add a
`_headers` file to the root of the Pages project (alongside `stories.json`)
containing:

```
/stories.json
  Access-Control-Allow-Origin: *
  Cache-Control: max-age=300
```

See `lib/features/outcome/application/story_config_endpoint.dart` for the
full list of hosting requirements (HTTPS, `ETag`, cache headers) before
pointing the app at a real endpoint.
