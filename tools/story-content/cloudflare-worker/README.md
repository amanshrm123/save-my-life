# Cloudflare Worker — `kStoryConfigUrl`'s live host

This is the source for the Cloudflare Worker currently deployed at
`https://soft-waterfall-3e3e.amanshrm74.workers.dev` (see `kStoryConfigUrl` in
`lib/features/outcome/application/story_config_endpoint.dart`). Tracked here
so a content redeploy — or recreating the Worker from scratch on a new
Cloudflare account — doesn't depend on anyone remembering what's live only on
the Cloudflare dashboard.

## What it does

**Story content** — serves `../stories.json` (the canonical editable content
one directory up) with the headers the app actually requires (see
`story_config_endpoint.dart`'s doc comment for the full requirements list):

- `Access-Control-Allow-Origin: *` — required for the Flutter web build.
- `Cache-Control: public, max-age=300`.
- The asset's own `ETag`, forwarded through — and the Worker itself checks
  incoming `If-None-Match` and returns a genuine empty-body `304` on a match,
  since Cloudflare's Static Assets binding does **not** evaluate conditional
  headers on its own when fetched programmatically from inside a Worker
  script (only on a direct edge request to a static asset, which this
  isn't — the Worker script always runs first).

**Legal pages** — `GET /privacy` and `GET /terms` serve the repo-root
`PRIVACY.md`/`TERMS.md`, rendered to static HTML (see
`scripts/render-legal-pages.js`). This is what Settings' "Privacy policy"/
"Terms" rows (`lib/features/settings/presentation/settings_screen.dart`)
actually open — and the URL both app stores require in their submission
metadata. Any other path (including the bare Worker origin, unchanged for
existing installs) still serves the story content, exactly as before these
two routes existed.

## How to redeploy after editing content

```sh
# from this directory:
cp ../stories.json public/stories.json
node scripts/render-legal-pages.js
npx wrangler deploy
```

That's it — `wrangler.toml`'s `name = "soft-waterfall-3e3e"` targets the
existing Worker, so this overwrites it in place at the same URL. No dashboard
interaction needed. Requires `npx wrangler login` once per machine (opens a
browser to authorize against the Cloudflare account this Worker lives on).

`public/stories.json`, `public/privacy.html`, and `public/terms.html` are
intentionally **not** committed (see `.gitignore` in this directory) — the
repo-root `.md`/JSON source files are each the single source of truth;
generating/copying into `public/` immediately before every deploy avoids a
second copy of this content silently drifting out of sync. If you only
changed `PRIVACY.md`/`TERMS.md`, you can skip the `cp ../stories.json` line;
if you only changed story content, you can skip the render script — but
running both unconditionally is harmless and simplest to remember.
