export default {
  async fetch(request, env) {
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
  },
};
