// Bearoster calendar share relay: serves subscribable iCalendar feeds from
// KV. KV model: key = `share:{readToken}` (the token embedded in the
// subscription URL), value = { secretHash, ics, updatedAt }.
//
// GET/HEAD need only the read token — the URL is the credential. PUT/DELETE
// additionally require the per-share write secret as a bearer token, stored
// here only as a SHA-256 hash.

const MAX_BODY_BYTES = 1_000_000;
// Speed bump marking app-originated share creation; not a secret. Real
// write protection is the per-share write secret.
const APP_MARKER = "bearoster-share-v1";
const TOKEN_PATTERN = /^\/c\/([A-Za-z0-9_-]{22,128})$/;

export default {
  async fetch(request, env) {
    if (!["GET", "HEAD", "PUT", "DELETE"].includes(request.method)) {
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD, PUT, DELETE" },
      });
    }

    const token = new URL(request.url).pathname.match(TOKEN_PATTERN)?.[1];
    if (!token) return new Response("Not found", { status: 404 });
    const key = `share:${token}`;

    if (request.method === "GET" || request.method === "HEAD") {
      const entry = await env.SHARES.get(key, { type: "json" });
      if (!entry || typeof entry.ics !== "string") {
        return new Response("Not found", { status: 404 });
      }
      return new Response(request.method === "HEAD" ? null : entry.ics, {
        status: 200,
        headers: {
          "Content-Type": "text/calendar; charset=utf-8",
          "Cache-Control": "public, max-age=600",
          "X-Content-Type-Options": "nosniff",
        },
      });
    }

    const secret =
      (request.headers.get("Authorization") || "").match(/^Bearer (.+)$/)?.[1] ?? "";
    if (!secret) return new Response("Unauthorized", { status: 401 });

    const stored = await env.SHARES.get(key, { type: "json" });
    const authorized = stored
      ? hexDigestsMatch(await sha256Hex(secret), stored.secretHash)
      : false;

    if (request.method === "DELETE") {
      if (!stored) return new Response(null, { status: 204 });
      if (!authorized) return new Response("Forbidden", { status: 403 });
      await env.SHARES.delete(key);
      return new Response(null, { status: 204 });
    }

    // PUT: overwrite needs the write secret; brand-new shares need the app
    // marker so the namespace cannot be seeded by third parties anonymously.
    if (stored) {
      if (!authorized) return new Response("Forbidden", { status: 403 });
    } else if (request.headers.get("X-Bearoster-App") !== APP_MARKER) {
      return new Response("Forbidden", { status: 403 });
    }

    const body = await request.text();
    const byteLength = new TextEncoder().encode(body).length;
    if (byteLength === 0 || byteLength > MAX_BODY_BYTES) {
      return new Response("Payload too large", { status: 413 });
    }
    if (!body.startsWith("BEGIN:VCALENDAR")) {
      return new Response("Not an iCalendar body", { status: 400 });
    }

    await env.SHARES.put(
      key,
      JSON.stringify({
        secretHash: await sha256Hex(secret),
        ics: body,
        updatedAt: new Date().toISOString(),
      })
    );
    return new Response(null, { status: 204 });
  },
};

function hexDigestsMatch(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
