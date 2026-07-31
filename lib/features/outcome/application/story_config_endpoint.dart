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
/// UNTIL THIS IS REAL: leave the placeholder as-is. The app is fully
/// functional against it — every fetch fails DNS, `refreshIfStale` swallows
/// it, and all 66 beats are served from `assets/stories_bundled.json`. There
/// is no error UI, no retry, no user-visible symptom. Shipping with the
/// placeholder is a supported state, not a broken one.
const String kStoryConfigUrl = 'https://REPLACE_ME.example.com/stories.json';
