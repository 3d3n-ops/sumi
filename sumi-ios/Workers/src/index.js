// Sumi Cloudflare Worker
//
// Two jobs:
//   1. LLM proxy — /completions and /vision call OpenRouter (OpenAI-compatible)
//      with the key that lives only here (never in the app). The app talks only
//      to this Worker.
//   2. Proactive push — /register stores APNs device tokens; the cron-driven
//      scheduled() handler sends a silent (content-available) push to wake the
//      app's proactive engine.
//
// Secrets (set via `wrangler secret put`):
//   OPENROUTER_API_KEY  - OpenRouter API key (sk-or-...)
//   SUMI_APP_SECRET     - shared bearer the app sends; gates every request
//   APNS_AUTH_KEY       - APNs auth key .p8 contents (PEM)
//   APNS_KEY_ID         - 10-char APNs key id
//   APNS_TEAM_ID        - Apple Developer team id (U97LL9V6WP)
// Vars (in wrangler.toml):
//   OPENROUTER_MODEL    - model slug, e.g. anthropic/claude-sonnet-4.6
//   APNS_TOPIC          - bundle id (Eden-Etuk.sumi-ios)
//   APNS_HOST           - api.push.apple.com (prod) or api.sandbox.push.apple.com
// Bindings:
//   DEVICE_TOKENS       - KV namespace storing registered device tokens

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL = "anthropic/claude-sonnet-4.6";
const MAX_TOKENS = 512;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }
    if (!authorized(request, env)) {
      return json({ error: "unauthorized" }, 401);
    }

    try {
      switch (url.pathname) {
        case "/completions":
          return await handleCompletions(request, env);
        case "/vision":
          return await handleVision(request, env);
        case "/register":
          return await handleRegister(request, env);
        default:
          return json({ error: "not found" }, 404);
      }
    } catch (err) {
      return json({ error: String(err && err.message ? err.message : err) }, 500);
    }
  },

  // Cron-driven silent push. Schedules are defined in wrangler.toml (UTC).
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(pushToAllDevices(env));
  },
};

// MARK: - Auth

function authorized(request, env) {
  if (!env.SUMI_APP_SECRET) return true; // dev: no secret configured
  const header = request.headers.get("authorization") || "";
  const token = header.replace(/^Bearer\s+/i, "");
  return token === env.SUMI_APP_SECRET;
}

// MARK: - LLM proxy

async function handleCompletions(request, env) {
  const body = await request.json();
  // OpenAI-compatible: system messages stay in the array as-is.
  let messages = body.messages || [];
  if (messages.length === 0) {
    messages = [{ role: "user", content: "(no input)" }];
  }
  const text = await callOpenRouter(env, messages);
  return json({ text });
}

async function handleVision(request, env) {
  const body = await request.json();
  const mediaType = body.mediaType || "image/png";
  const messages = [
    {
      role: "user",
      content: [
        { type: "text", text: body.prompt || "Describe this image." },
        { type: "image_url", image_url: { url: `data:${mediaType};base64,${body.image}` } },
      ],
    },
  ];
  const text = await callOpenRouter(env, messages);
  return json({ text });
}

async function callOpenRouter(env, messages) {
  const model = env.OPENROUTER_MODEL || DEFAULT_MODEL;
  const resp = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      "content-type": "application/json",
      // Optional ranking/attribution headers OpenRouter recommends.
      "HTTP-Referer": env.OPENROUTER_REFERER || "https://sumi.app",
      "X-Title": "Sumi",
    },
    body: JSON.stringify({ model, max_tokens: MAX_TOKENS, messages }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`openrouter ${resp.status}: ${detail.slice(0, 300)}`);
  }
  const data = await resp.json();
  const choice = (data.choices || [])[0];
  return (choice && choice.message && choice.message.content) || "";
}

// MARK: - Device registration

async function handleRegister(request, env) {
  const body = await request.json();
  const token = (body.token || "").trim();
  if (!token) return json({ error: "missing token" }, 400);
  await env.DEVICE_TOKENS.put(token, JSON.stringify({ registeredAt: Date.now() }));
  return json({ ok: true });
}

// MARK: - APNs push

async function pushToAllDevices(env) {
  const list = await env.DEVICE_TOKENS.list();
  if (list.keys.length === 0) return;
  const jwt = await apnsProviderToken(env);
  await Promise.all(list.keys.map((k) => sendSilentPush(env, jwt, k.name)));
}

async function sendSilentPush(env, jwt, deviceToken) {
  const host = env.APNS_HOST || "api.push.apple.com";
  const resp = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": env.APNS_TOPIC,
      "apns-push-type": "background",
      "apns-priority": "5",
      "apns-expiration": "0",
      "content-type": "application/json",
    },
    body: JSON.stringify({ aps: { "content-available": 1 } }),
  });
  // 410 = token no longer valid; prune it.
  if (resp.status === 410) {
    await env.DEVICE_TOKENS.delete(deviceToken);
  }
}

// Signed ES256 provider token for APNs (valid up to 1h; minted per cron run).
async function apnsProviderToken(env) {
  const header = { alg: "ES256", kid: env.APNS_KEY_ID };
  const payload = { iss: env.APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;

  const key = await importPKCS8(env.APNS_AUTH_KEY);
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );
  return `${signingInput}.${b64urlBytes(new Uint8Array(sig))}`;
}

async function importPKCS8(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

// MARK: - Helpers

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function b64url(str) {
  return b64urlBytes(new TextEncoder().encode(str));
}

function b64urlBytes(bytes) {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
