# Sumi Cloudflare Worker

Proxies LLM calls via **OpenRouter** (so the API key never ships in the app) and
sends the silent pushes that wake Sumi's proactive engine. OpenRouter is
OpenAI-compatible; the model is set by the `OPENROUTER_MODEL` var in
`wrangler.toml` (default `anthropic/claude-sonnet-4.6`).

## Endpoints
- `POST /completions` — `{ model, messages }` → `{ text }`
- `POST /vision` — `{ image (base64), prompt, mediaType? }` → `{ text }`
- `POST /register` — `{ token }` stores an APNs device token in KV
- `scheduled()` — cron-driven silent push to all registered devices

All requests require `Authorization: Bearer <SUMI_APP_SECRET>` when that secret
is set.

## One-time setup

```bash
cd sumi-ios/Workers
npm install
npx wrangler login                       # opens browser to your Cloudflare acct

# Create the KV namespace and paste the printed id into wrangler.toml
npx wrangler kv namespace create DEVICE_TOKENS

# Secrets (you'll be prompted to paste each value):
npx wrangler secret put OPENROUTER_API_KEY  # sk-or-...
npx wrangler secret put SUMI_APP_SECRET     # any long random string; also set in the app
npx wrangler secret put APNS_AUTH_KEY       # full contents of the APNs .p8 file
npx wrangler secret put APNS_KEY_ID         # 10-char key id from the APNs key
npx wrangler secret put APNS_TEAM_ID        # U97LL9V6WP

npx wrangler deploy                          # prints your https://sumi-worker.<sub>.workers.dev URL
```

## After deploy
1. Put the printed Worker URL in the app's Keychain (`sumi.worker.url`) and the
   `SUMI_APP_SECRET` value in `sumi.worker.secret` — see the app's onboarding /
   settings, or set them in a debug build.
2. Test the proxy:
   ```bash
   curl -s https://YOUR-WORKER-URL/completions \
     -H "authorization: Bearer YOUR_SUMI_APP_SECRET" \
     -H "content-type: application/json" \
     -d '{"model":"claude-sonnet-4-6","messages":[{"role":"user","content":"say hi in five words"}]}'
   ```
3. Trigger a test push on the next cron, or run `npx wrangler tail` to watch logs.

## Cron timezone
Cloudflare cron is **UTC**. The schedules in `wrangler.toml` are commented with
their US-Eastern equivalents — adjust for your timezone.
