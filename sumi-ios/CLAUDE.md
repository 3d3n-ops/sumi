# Sumi — iOS Personal Agent
# CLAUDE.md — read every session, keep under 120 lines

## Identity
Sumi is a proactive-first personal agent for iOS 26+.
It surfaces to the user — the user does not open it.
The only UI is a minimal Settings screen.

## Stack
iOS 26+, Swift 6.1, SwiftUI (settings only)
Xcode 26.3, XcodeBuildMCP wired for terminal builds
SPM dependencies: SQLite.swift (for sqlite-vec), swift-markdown-ui

## Folder structure
Source root is sumi-ios/ (a synchronized root group — files added under it are
auto-included in the build target). Module name: sumi_ios. App entry:
sumi-ios/sumi_iosApp.swift. Unit tests: sumi-iosTests/ (Swift Testing framework).
sumi-ios/AppIntents/     — all Siri-facing App Intents
sumi-ios/Agent/          — LLMRouter, ReAct loop, tool registry
sumi-ios/Memory/         — SwiftData models, EmbeddingService, MemoryStore
sumi-ios/Proactive/      — BGTask engine, trigger types, ProactiveSurface
sumi-ios/Integrations/   — EventKit, Contacts, Reminders, Notes, Mail tools
sumi-ios/UI/             — Settings only (SwiftUI)
sumi-ios/Workers/        — Cloudflare Worker JS (separate subfolder)

## Hard rules — never violate
- NEVER store API keys in code or UserDefaults. Keychain only.
- NEVER show UI the user must open. Surfaces via notification only.
- ALL LLM calls route through LLMRouter — never call APIs directly.
- EVERY memory write runs entity extraction before storing.
- BGTask handlers must complete within 25 seconds total.
- App Intent responses are spoken — no markdown, no bullets, no headers.
- SwiftData on main actor only. Embeddings computed off main actor.
- No SiriKit. App Intents only.
- Max 3 proactive surfaces per day (default). Quiet hours 9pm–7am.
- Relevance threshold for proactive: 0.80 minimum.

## LLMRouter routing logic
- Simple recall / fast response  →  Foundation Models (on-device, free)
- Screenshot or vision required  →  Claude vision API (cloud)
- Complex reasoning / drafting   →  Claude claude-sonnet-4-6 (cloud)
- All API calls proxied via Cloudflare Worker — never use key in app.

## Proactive engine rules
- Runs via BGAppRefreshTask: com.sumi.proactive
- Woken by silent push from Worker (6:45am, meeting-30min, 3pm)
- Evaluates trigger queue, fires notification only if threshold met
- Never surfaces during active calendar event (EventKit check)
- Dismissed twice = suppress that trigger type for 7 days

## Memory tiers
- identity:  persistent facts about user (preferences, relationships)
- context:   rolling 14-day active window (projects, open commitments)
- episodic:  last 48h interactions and decisions

## Build commands
- Build:  xcodebuild build -scheme sumi-ios -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
- Test:   xcodebuild test -scheme sumi-ios -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
- Lint:   swiftlint lint --quiet

## When Claude gets something wrong, add a rule here:
