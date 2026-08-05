// Static legal pages (rendered from repo-root PRIVACY.md/TERMS.md by
// scripts/render-legal-pages.js immediately before every deploy — see that
// script's own doc comment). Long cache: these change rarely, and unlike
// stories.json there's no player-facing staleness requirement driving a
// short max-age.
const LEGAL_PAGE_ROUTES = {
  '/privacy': 'privacy.html',
  '/terms': 'terms.html',
};

async function serveLegalPage(assetPath, env) {
  const assetResponse = await env.ASSETS.fetch(new Request(new URL(`/${assetPath}`, 'http://internal')));
  if (!assetResponse.ok) {
    return new Response(`${assetPath} not found — did scripts/render-legal-pages.js run before deploy?`, {
      status: 404,
    });
  }
  const headers = new Headers(assetResponse.headers);
  headers.set('cache-control', 'public, max-age=3600');
  if (!headers.has('content-type')) {
    headers.set('content-type', 'text/html; charset=utf-8');
  }
  return new Response(await assetResponse.text(), { status: 200, headers });
}

async function serveStoryConfig(request, env) {
  const assetUrl = new URL('/stories.json', request.url);
  const assetResponse = await env.ASSETS.fetch(new Request(assetUrl));

  if (!assetResponse.ok) {
    return new Response('stories.json not found', { status: 404 });
  }

  const etag = assetResponse.headers.get('etag');

  const headers = new Headers(assetResponse.headers);
  headers.set('access-control-allow-origin', '*');
  headers.set('cache-control', 'public, max-age=300');
  if (!headers.has('content-type')) {
    headers.set('content-type', 'application/json');
  }

  // The ASSETS binding doesn't evaluate conditional-request headers on
  // its own when fetched programmatically like this (unlike a direct
  // edge request to a static asset) — check If-None-Match ourselves and
  // return a genuine, empty-body 304 so clients that already have the
  // current payload aren't re-sent the full ~15KB body every 6 hours.
  const ifNoneMatch = request.headers.get('if-none-match');
  if (etag && ifNoneMatch && ifNoneMatch === etag) {
    return new Response(null, { status: 304, headers });
  }

  const body = await assetResponse.text();
  return new Response(body, { status: 200, headers });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    // Trailing-slash tolerant: "/privacy" and "/privacy/" both hit the
    // same page — a bare `/privacy` link (no trailing slash) is what the
    // app actually opens, but this costs nothing to also accept.
    const normalizedPath = pathname.replace(/\/$/, '') || '/';

    const legalAsset = LEGAL_PAGE_ROUTES[normalizedPath];
    if (legalAsset) {
      return serveLegalPage(legalAsset, env);
    }

    // Every other path (including the historical "any path at all" default
    // this Worker started with) keeps serving the story-config content, so
    // existing app installs pointed at the bare Worker origin are
    // unaffected by adding these two new routes.
    return serveStoryConfig(request, env);
  },
};
