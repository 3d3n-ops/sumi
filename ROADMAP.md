# Sumi — Roadmap

> Re-anchored 2026-06-13 on the product vision, replacing the linear sprint plan
> in `sumi-ios/SPRINT-PROMPTS.md` (which is now history — Sprints 0–6.3 shipped).

## The vision

Sumi is a **personal assistant with context of you from the Apple ecosystem** that
acts like a **life coach / accountability partner** — helping you do great work and
be as productive as possible.

- The **home** is a **daily briefing of your life**: recent updates and what Sumi is
  proactively working on for things you've already delegated. *Not* a chatbot.
- The **chat** is a **command center**: give instructions and work side-by-side
  with Sumi.
- The **integrations (App Intents / tools) must actually work**, and **permissions
  must be crystal clear and really granted**, so it feels like Sumi can do almost
  anything for you.

## Where we are (honest)

Strong foundations, but not yet the product:

- ✅ Memory (on-device SwiftData + vector search, entity extraction).
- ✅ Proactive engine (BGTasks, gating, morning-brief / follow-up / meeting-prep
  triggers → notifications).
- ✅ Tool *wrappers* (Calendar/Contacts/Reminders read, reminder create,
  Mail/Messages compose) — **but not wired to the LLM**.
- ✅ Onboarding, Settings, design system, Privacy Manifest.
- ❌ No home/briefing surface — the app opens to chat.
- ❌ No agent execution — the LLM can't invoke tools; chat only *describes* actions.
- ❌ Permissions don't really grant (calendar is never requested; onboarding
  "Personal context" only flips preference flags).

## AI provisioning (be honest)

Sumi's AI runs in **Sumi's secure cloud** (Claude via OpenRouter, proxied by our
Cloudflare Worker). The API key never ships in the app. **Your memory and personal
data are stored on your device**; only the text needed for a given request is sent
to the AI service, and **your data is never sold or used to train models.** We do
**not** claim on-device inference. (Foundation Models on-device is a future option,
not the current path.)

## Priority order: A → B → C

### Phase A — Agent execution core *(the unlock)*
The LLM can actually *do* things, with **propose → you approve → execute → report**.

- **A1. Worker tool-use passthrough** (`Workers/src/index.js`): `/completions`
  accepts OpenAI-style `tools`/`tool_choice` and returns the full assistant message
  (`content` + `tool_calls`), backward-compatible when no tools are sent.
- **A2. Callable tools** (`Agent/`, `Integrations/`): an `AgentTool` protocol
  (name, description, JSON-Schema parameters, `requiresApproval`, `call(args)`),
  with adapters over the existing Calendar/Contacts/Reminders/Mail/Messages tools,
  registered in `ToolRegistry` (currently consumed nowhere).
- **A3. AgentLoop** (`Agent/AgentLoop.swift`): ReAct/tool-use loop — call the LLM
  with tool schemas, execute read tools immediately, **pause mutating/outward tools
  for user approval**, append results, loop (iteration + time cap), return.
- **A4. Command-center UI**: render the plan as a checklist + approval card
  ("Read flight ✓ → Added to Calendar ✓ → Draft to Mom → review"); chat drives the
  loop instead of single-shot completion.

### Phase B — Permissions that actually grant
Onboarding/Settings request **real** EventKit (events + reminders), Contacts (and
later HealthKit). Tools surface a typed *not-authorized* state instead of silently
returning empty; denied → deep-link to Settings.

### Phase C — Home briefing surface
App root becomes a `TabView` (**Home** + **command-center chat**). Home shows
today's briefing, "what Sumi is working on" (open commitments + scheduled proactive
items), and recent activity. Chat is one tab over.

## Deferred
- **6.4 auth** — Sign in with Apple + per-user rate limiting (pre-launch; needs the
  App Store provisioning profile regenerated with the SiwA capability).
- **Deepen context** — HealthKit, fuller EventKit, on-screen awareness.
- **On-device model** — wire Foundation Models if/when we want true on-device.
- **Coaching layer** — goals, check-ins, progress, on top of A–C.

## How we ship
Each phase lands as CI-gated PRs to `main`. Local Macs can't build iOS 26, so the
PR build is the only gate; agent behavior + visuals are verified on TestFlight
(build number = the `testflight.yml` run number, dispatched manually).
