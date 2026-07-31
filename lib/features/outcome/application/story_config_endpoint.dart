/// ============================================================
///  THE ONE THING TO CHANGE WHEN YOU SET UP HOSTING.
/// ============================================================
///
/// Replace the host below with wherever you publish `stories.json`.
/// Nothing else in the app needs to change. Suggested hosts, in the order
/// recommended by remote-story-config-options.md §1/§7:
///
///   Cloudflare Pages   https://`<project>`.pages.dev/stories.json
///   Cloudflare R2      https://`<bucket>`.`<account>`.r2.dev/stories.json
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
/// LIVE (2026-07-31): a Cloudflare Worker with a Static Assets binding,
/// serving `tools/story-content/stories.json` verbatim. Verified against
/// every requirement above — `ETag`, `Access-Control-Allow-Origin: *`,
/// `Cache-Control: public, max-age=300`, and a genuine 304 on a matching
/// `If-None-Match` (the worker checks this itself; Cloudflare's ASSETS
/// binding doesn't evaluate conditional headers when fetched
/// programmatically like this, unlike a direct edge request to a static
/// asset). To publish a content edit: update
/// `tools/story-content/stories.json`, then redeploy the worker (source
/// lives outside this repo, on the founder's Cloudflare account).
const String kStoryConfigUrl =
    'https://soft-waterfall-3e3e.amanshrm74.workers.dev';
