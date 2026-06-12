# Sumi — Sprint Prompts
# Paste each prompt directly into Claude Code at the start of each sprint phase.

---

## SPRINT 0 — PROJECT SCAFFOLD
Duration: 1 day
Goal: Buildable project with correct folder structure, SPM dependencies wired, entitlements set

### What you do manually first
1. Create new Xcode project: App, "Sumi", SwiftUI, Swift, iOS 26+
2. Create folder structure: AppIntents/, Agent/, Memory/, Proactive/, Integrations/, UI/
3. Add required entitlements: App Groups, Background Modes, Siri, Push Notifications
4. Add Privacy usage strings to Info.plist (Calendars, Contacts, Reminders, Speech)
Then hand to Claude Code.

### Prompt 0 — Scaffold
```
I have created a new Xcode 26 project called Sumi with folder structure:
AppIntents/, Agent/, Memory/, Proactive/, Integrations/, UI/

Do the following:

1. Add SPM dependencies:
   - SQLite.swift: https://github.com/stephencelis/SQLite.swift from: "0.15.0"
   - swift-markdown-ui: https://github.com/gonzalezreal/swift-markdown-ui from: "2.0.0"

2. Create placeholder Swift files in each folder with correct module structure.

3. Create CLAUDE.md in project root with the content from our build bible.

4. Create .claude/commands/ with new-intent.md, new-trigger.md,
   spoken-check.md, privacy-audit.md, bg-budget.md stubs.

5. Create .claude/settings.json with a PostToolUse hook on *.swift edits
   that runs swiftlint and checks for API key strings (sk-ant, apiKey, api_key).

6. Build the project and confirm it compiles with zero warnings.
```

---

## SPRINT 1 — MEMORY FOUNDATION
Duration: ~4 days
Goal: Every Sumi interaction is remembered, embedded, and retrievable. Nothing visible yet — just the brain.

### Components
| Component       | File                          | Purpose                                        |
|-----------------|-------------------------------|------------------------------------------------|
| MemoryEntry     | Memory/MemoryEntry.swift      | SwiftData model — the atom of memory           |
| MemoryTier      | Memory/MemoryTier.swift       | Enum: identity / context / episodic            |
| EmbeddingService| Memory/EmbeddingService.swift | NaturalLanguage → 512-dim vectors, off main actor |
| VectorStore     | Memory/VectorStore.swift      | sqlite-vec cosine search with BLOB fallback    |
| EntityExtractor | Memory/EntityExtractor.swift  | NER: people, places, projects, commitments     |
| MemoryStore     | Memory/MemoryStore.swift      | Actor: write(), search(), decay(), relate()    |

### Prompt 1.1 — SwiftData Schema
```
Build the Memory layer schema for Sumi in Sumi/Memory/.

1. MemoryEntry.swift — SwiftData @Model:
   - id: UUID
   - timestamp: Date
   - tier: MemoryTier (enum: identity, context, episodic)
   - content: String (the raw text of the memory)
   - importance: Float (starts 1.0, decays over time)
   - entities: [String] (extracted names, places, projects)
   - relatedIDs: [UUID] (linked memories)
   - embeddingKey: String (foreign key into VectorStore)

2. MemoryTier.swift — enum with description var returning:
   - identity: "persistent facts about the user"
   - context: "active 14-day window"
   - episodic: "recent 48-hour interactions"

3. Add ModelContainer setup in SumiApp.swift using .inMemory false.

Follow CLAUDE.md: SwiftData on main actor only. Write unit tests for model
creation and persistence. Build and confirm zero errors.
```

### Prompt 1.2 — Embeddings + Vector Store
```
Build EmbeddingService and VectorStore for Sumi.

1. EmbeddingService.swift — actor:
   - Uses NaturalLanguage.framework NLEmbedding
   - func embed(_ text: String) async -> [Float]?
   - Runs entirely off main actor
   - Returns 512-dimensional vector
   - Caches embeddings for strings already seen (LRU, max 500)

2. VectorStore.swift — actor backed by sqlite-vec via SQLite.swift:
   - Database file: App Group container so BGTasks can access it
   - On init: detect sqlite-vec availability by attempting to create a canary
     vec0 virtual table. Set isVecAvailable = true/false. Log loudly if unavailable.
   - func insert(key: String, vector: [Float]) async
     · Dual-write: insert into vec0 virtual table AND a raw BLOB table (vec_blobs)
     · Both writes happen on every insert regardless of isVecAvailable
   - func search(query: [Float], topK: Int) async -> [(key: String, score: Float)]
     · If isVecAvailable: use vec0 cosine search
     · Fallback: load all vectors from vec_blobs, compute cosine similarity in Swift
     · For < 5000 entries the fallback is fast enough — profile before optimizing
   - func delete(key: String) async — deletes from both tables
   - After search, check resolved MemoryEntry keys for orphans and re-embed lazily

Write unit tests: insert 10 entries, search returns correct top-3. Test fallback
path explicitly by forcing isVecAvailable = false. Build and confirm zero errors.
```

### Prompt 1.3 — Entity Extractor + MemoryStore
```
Build EntityExtractor and MemoryStore for Sumi.

1. EntityExtractor.swift — struct:
   - func extract(from text: String) async -> [String]
   - Uses NLTagger with .nameType scheme
   - Extracts: personalNames, placeNames, organizationNames
   - Also runs keyword extraction for project names and topics
   - Returns deduplicated array of entity strings

2. MemoryStore.swift — actor, the main interface for all memory:
   - Holds ref to ModelContext (main actor), EmbeddingService, VectorStore, EntityExtractor
   - func write(_ content: String, tier: MemoryTier) async -> MemoryEntry
     · extracts entities first (CLAUDE.md rule)
     · computes embedding
     · inserts into VectorStore with key = entry.id.uuidString
     · saves SwiftData entry
   - func search(_ query: String, topK: Int = 5) async -> [MemoryEntry]
     · embeds query, vector search, resolve keys to MemoryEntry objects
     · lazy re-embed any orphaned keys found during resolution
   - func decayImportance() async
     · reduce importance by 0.02/day for episodic, 0.005/day for context
     · delete entries with importance < 0.05
     · NOTE: call this only from BGProcessingTask (com.sumi.maintenance), never BGAppRefreshTask

Write integration test: write 5 memories, search returns relevant one.
Build. Run /privacy-audit to verify no data leaks.
```

---

## SPRINT 2 — PROACTIVE SURFACE
Duration: ~4 days
Goal: Sumi fires the first morning briefing without being asked.

### Components
| Component              | Purpose                                                   |
|------------------------|-----------------------------------------------------------|
| LLMRouter              | Routes queries: Foundation Models vs Claude API vs vision |
| CloudflareWorkerClient | All outbound API calls — keys never in app                |
| ProactiveSurface       | Value type: message + action + score + expiry             |
| ProactiveTrigger       | Interface all triggers conform to                         |
| MorningBriefTrigger    | Reads calendar + memory → speaks briefing                 |
| ProactiveEngine        | BGTask scheduler, trigger evaluation, gate logic          |
| NotificationComposer   | One sentence + two actions, no walls of text              |

### Prompt 2.1 — LLMRouter + Cloudflare Client
```
Build LLMRouter and CloudflareWorkerClient for Sumi in Sumi/Agent/.

1. CloudflareWorkerClient.swift — actor:
   - Reads worker URL from Keychain (key: "sumi.worker.url")
   - func completions(messages: [[String:String]], model: String) async throws -> String
   - func vision(imageBase64: String, prompt: String) async throws -> String
   - URLSession with 30s timeout
   - Throws SumiError.noWorkerURL if key missing (graceful — no crash)

2. LLMRouter.swift — actor:
   - Holds FoundationModelsSession and CloudflareWorkerClient
   - enum RouteType: onDevice, cloudSonnet, cloudVision
   - func route(query: String, hasImage: Bool, complexity: Float) -> RouteType
     · hasImage → .cloudVision always
     · complexity < 0.4 → .onDevice
     · else → .cloudSonnet
   - func respond(query: String, context: [MemoryEntry], image: Data?) async -> String
     · assembles prompt with memory context injected
     · routes and calls appropriate backend
     · spoken-quality response only (from CLAUDE.md rules)

CLAUDE.md rule: never put API keys in code. Worker URL from Keychain only.
Build and run /privacy-audit.
```

### Prompt 2.2 — ProactiveSurface + Trigger Protocol
```
Build the ProactiveSurface model and ProactiveTrigger protocol in Sumi/Proactive/.

1. ProactiveSurface.swift — value type (struct):
   - message: String  (one sentence, spoken-quality)
   - primaryActionTitle: String  (e.g. "Do it now")
   - primaryAction: SumiAction  (enum of possible actions)
   - dismissTitle: String  (e.g. "Not now")
   - relevanceScore: Float  (0.0–1.0)
   - expiresAt: Date
   - triggerID: String  (for suppression tracking)

2. ProactiveTrigger.swift — protocol:
   - var triggerID: String { get }
   - func evaluate(memory: MemoryStore, calendar: EKEventStore,
                   contacts: CNContactStore) async -> ProactiveSurface?

3. SumiAction.swift — enum:
   - openReminders, composeMessage(to: String), openCalendar,
     addNote(content: String), dismiss

4. SuppressedTriggers.swift — UserDefaults wrapper:
   - track dismiss counts per triggerID
   - func isSuppressed(_ id: String) -> Bool  (suppressed if dismissed 2x in 7 days)
   - func recordDismissal(_ id: String)

Build. Write unit test for suppression logic.
```

### Prompt 2.3a — BGTask Infrastructure
```
Build the BGTask infrastructure for Sumi in Sumi/Proactive/. Do NOT wire ProactiveEngine yet.

1. Register two BGTask identifiers in AppDelegate:
   - com.sumi.proactive  (BGAppRefreshTask — light trigger evaluation)
   - com.sumi.maintenance  (BGProcessingTask — memory decay, vector cleanup)

2. BGTask handler pattern — implement for com.sumi.proactive:
   - Hard timeout at 20 seconds using TaskGroup race (not 25s — leave 5s cleanup margin):
     · Task A: actual work (placeholder for now — just log "task fired")
     · Task B: sleep(20s) then throw BudgetExceededError
     · First to finish cancels the other
   - task.expirationHandler: cancel work task, call task.setTaskCompleted(success: false)
   - On completion: reschedule next refresh immediately

3. BGProcessingTask handler for com.sumi.maintenance:
   - requiresExternalPower: false, requiresNetworkConnectivity: false
   - Placeholder: log "maintenance fired"
   - Expiration handler: task.setTaskCompleted(success: false)

4. func scheduleProactiveRefresh() — call on app launch and after each task completes.

Test: use LLDB to simulate launch:
  e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.sumi.proactive"]
Build and confirm zero errors. Run /bg-budget.
```

### Prompt 2.3b — ProactiveEngine + NotificationComposer
```
Build ProactiveEngine and NotificationComposer for Sumi. Wire into BGTask handler from 2.3a.

1. ProactiveEngine.swift — actor:
   - allTriggers: [any ProactiveTrigger] (empty for now, MorningBriefTrigger added in 2.3c)
   - dailySurfaceCount tracked in UserDefaults (resets at midnight)
   - func evaluate() async:
     · guard not in quiet hours (9pm–7am)
     · guard dailySurfaceCount < 3
     · run all triggers concurrently with TaskGroup
     · collect non-nil surfaces, sort by relevanceScore
     · take highest scoring surface that passes SuppressedTriggers check
     · call NotificationComposer.fire(surface:)

2. NotificationComposer.swift:
   - func fire(surface: ProactiveSurface) async
     · UNUserNotificationCenter — one notification
     · body = surface.message (one sentence)
     · add UNNotificationAction for primary + dismiss
     · categoryIdentifier = "sumi.proactive"

3. Wire ProactiveEngine.evaluate() into the com.sumi.proactive BGTask handler (replacing placeholder).

Build. Test with a mock trigger that always returns a surface with score 0.95.
Run /bg-budget.
```

### Prompt 2.3c — MorningBriefTrigger
```
Build MorningBriefTrigger for Sumi and wire into ProactiveEngine.

IMPORTANT: Profile this trigger running in the FOREGROUND first before calling
from BGTask. Measure wall time for the full EventKit + MemoryStore + LLMRouter chain
on a device with a realistic calendar. If it exceeds 8 seconds, cache the result
during foreground and read from cache in BGTask.

MorningBriefTrigger.swift — conforms to ProactiveTrigger:
- triggerID = "morning.brief"
- evaluate():
  · fetch today's EKEvents from EventKit
  · for each event with attendees, search MemoryStore for context
  · check for unread commitment memories from last 48h
  · call LLMRouter to synthesize a one-sentence briefing
  · score = 0.95 if events exist, 0.60 if empty day
  · expires at 10am same day

Caching pattern:
- After any foreground session, pre-compute and cache brief in UserDefaults key "sumi.brief.cache"
- Cache includes: message String, computedAt Date, expiresAt Date
- In evaluate(): if cache is fresh (< 2h old, not expired), return from cache — skip LLMRouter
- Only recompute if cache is missing or stale

Register in ProactiveEngine.allTriggers.

Test with Simulator BGTask simulation. Build and run /bg-budget.
```

---

## SPRINT 3 — VOICE + APP INTENTS
Duration: ~5 days
Goal: User can talk to Sumi via Siri. Every conversation turn writes to memory.

### Intents
| Intent                  | Siri phrase example                          | Returns                        |
|-------------------------|----------------------------------------------|--------------------------------|
| MorningBriefingIntent   | "Hey Siri, ask Sumi what's my day"           | Spoken daily summary           |
| SearchMemoryIntent      | "Hey Siri, ask Sumi what I said about X"     | Recalled context, spoken       |
| ContextualReminderIntent| "Hey Siri, ask Sumi to remind me about this" | Creates reminder with memory link |
| ContactSummaryIntent    | "Hey Siri, ask Sumi about my history with Alex" | Relationship context, spoken |

### Prompt 3.1 — App Intents Foundation
```
Build the App Intents foundation for Sumi in Sumi/AppIntents/.

1. SumiShortcutsProvider.swift — AppShortcutsProvider:
   - Will register all Sumi intents with Siri
   - AppShortcut wrapping phrase patterns for each intent
   - Phrase patterns must be natural, conversational, varied

2. IntentResponseBuilder.swift — helper:
   - func spoken(_ text: String) -> String
     · strips markdown, headers, bullets
     · ensures max 3 sentences
     · adds natural spoken cadence (no "Here is your summary:")
   - This runs on EVERY intent response before returning

3. MemoryWriteback.swift — shared helper:
   - func record(intent: String, query: String, response: String) async
   - Writes interaction to MemoryStore as .episodic tier
   - Called at end of every intent perform()

Build. No intents yet — just foundation. Run /spoken-check (will pass vacuously).
```

### Prompt 3.2 — Memory + Briefing Intents
```
Build SearchMemoryIntent and MorningBriefingIntent for Sumi.

1. SearchMemoryIntent.swift:
   - @Parameter query: String  ("what to look for")
   - perform():
     · search MemoryStore for query
     · if no results: "I don't have anything on that yet."
     · else: synthesize via LLMRouter with top-5 memories as context
     · pass through IntentResponseBuilder.spoken()
     · call MemoryWriteback.record()
     · return .result(dialog: IntentDialog(spoken))
   - App Shortcuts: "ask Sumi what I said about .query",
     "ask Sumi to recall .query", "ask Sumi about .query"

2. MorningBriefingIntent.swift:
   - No parameters
   - perform():
     · Run MorningBriefTrigger.evaluate() directly
     · If surface returned: speak surface.message
     · If not: "Nothing urgent today — your schedule looks clear."
     · MemoryWriteback.record()
   - App Shortcuts: "ask Sumi what's my day", "ask Sumi for my briefing",
     "ask Sumi what's on today"

Build. Test both intents with Simulator Siri. Run /spoken-check.
```

### Prompt 3.3 — Reminder + Contact Intents
```
Build ContextualReminderIntent and ContactSummaryIntent for Sumi.

1. ContextualReminderIntent.swift:
   - @Parameter topic: String  (what to be reminded about)
   - @Parameter when: DateComponents? (optional time)
   - perform():
     · search MemoryStore for recent context about topic
     · create EKReminder with title built from topic + memory context
     · add notes field with recalled context snippet
     · save to default Reminders list
     · respond: "Done. I'll remind you about [topic] [when]."
     · MemoryWriteback.record()
   - App Shortcuts: "ask Sumi to remind me about .topic"

2. ContactSummaryIntent.swift:
   - @Parameter personName: String
   - perform():
     · CNContactStore lookup for personName
     · search MemoryStore for entity match on personName
     · search EventKit for shared calendar events
     · synthesize via LLMRouter: who they are, last interaction,
       open items, upcoming events
     · IntentResponseBuilder.spoken(), MemoryWriteback.record()
   - App Shortcuts: "ask Sumi about .personName",
     "ask Sumi for my history with .personName"

Build. Test all 4 intents on physical device (not just Simulator — Siri behaves
differently on device). Register all in SumiShortcutsProvider. Run /spoken-check
and /privacy-audit before TestFlight.
```

---
## ✅ TESTFLIGHT CHECKPOINT — after Sprint 3
Ship to TestFlight. Target 30–50 testers. Specifically recruit:
- Users who force-quit apps habitually
- Users with dense calendars
- Users on older/lower-memory devices (Foundation Models fallback)
- Users who use Siri regularly vs. never
---

## SPRINT 4 — COMMITMENT TRACKING
Duration: ~5 days
Goal: Sumi notices what you said you'd do and follows up.

### Prompt 4.1 — Commitment Extractor
```
Build CommitmentExtractor for Sumi in Sumi/Agent/.

CommitmentExtractor.swift — actor:
  - func extract(from text: String) async -> [Commitment]

Commitment.swift — struct:
  - id: UUID
  - text: String  (the raw commitment, e.g. "send Sarah the deck")
  - extractedFrom: String  (source context)
  - createdAt: Date
  - targetPerson: String?  (extracted entity)
  - dueHint: Date?  (if mentioned)
  - isResolved: Bool

Extraction logic:
  - Use LLMRouter with Foundation Models (fast, on-device)
  - Prompt: extract commitments from text as JSON array
  - Patterns to catch: "I'll...", "I need to...", "remind me to...",
    "I should...", "let me...", "I'll send...", "I promised..."
  - Return empty array if none found (not every message has commitments)

Integration: call CommitmentExtractor at end of every MemoryStore.write()
Save extracted Commitment objects as .context tier MemoryEntry objects.

Write unit tests with 10 sample texts — verify extraction accuracy. Build.
```

### Prompt 4.2 — Commitment Tracker + Follow-Up Trigger
```
Build CommitmentTracker and FollowUpTrigger for Sumi.

1. CommitmentTracker.swift — actor:
   - func openCommitments() async -> [Commitment]
     · fetch all .context MemoryEntry objects with commitment tag
     · cross-reference: check Reminders for matching content (fuzzy)
     · cross-reference: check recent memory for resolution signals
     · return only unresolved, older than 24h
   - func markResolved(_ id: UUID) async
   - func urgencyScore(for commitment: Commitment) -> Float
     · base 0.50, +0.10 per day since created, +0.20 if person has
       upcoming event in next 48h, capped at 0.95

2. FollowUpTrigger.swift — conforms to ProactiveTrigger:
   - triggerID = "commitment.followup"
   - evaluate():
     · get openCommitments(), score each
     · take highest urgency commitment scoring > 0.80
     · surface message: "[commitment text] — still open [N days later]"
     · primaryActionTitle: "Do it now"
     · primaryAction: .openReminders or .composeMessage based on commitment
     · expiresAt: 4 hours from now

3. Register FollowUpTrigger in ProactiveEngine.allTriggers.

Build. Write test: create commitment 4 days ago, verify trigger fires.
```

---

## SPRINT 5 — INTEGRATIONS DEPTH
Duration: ~5 days
Goal: Mail, Messages, Notes wired. Sumi has enough cross-app context to be genuinely smart.

### Prompt 5.1 — Calendar + Contacts + Reminders Tools
```
Build CalendarTool, ContactsTool, and RemindersTool in Sumi/Integrations/.

Each tool is an actor conforming to SumiTool protocol:
  - var toolID: String { get }
  - var description: String { get }  // what this tool can do, for LLM

1. CalendarTool:
   - func todayEvents() async -> [EKEvent]
   - func upcomingEvents(days: Int) async -> [EKEvent]
   - func eventsInvolving(personName: String) async -> [EKEvent]
   - func prepWindowFor(event: EKEvent) -> Date  // 30 min before

2. ContactsTool:
   - func lookup(name: String) async -> CNContact?
   - func recentContacts(limit: Int) async -> [CNContact]
   - func contactContext(contact: CNContact, memory: MemoryStore) async -> String
     · combine contact data + memory search for that person

3. RemindersTool:
   - func openReminders() async -> [EKReminder]
   - func create(title: String, notes: String?, due: Date?) async -> EKReminder
   - func complete(reminder: EKReminder) async

Register all three in a ToolRegistry actor in Sumi/Agent/. Build.
```

### Prompt 5.2 — Notes + Mail + Messages Tools
```
Build NotesTool, MailTool, and MessagesTool in Sumi/Integrations/.

1. NotesTool — via App Intents bridge to Notes app:
   - func create(title: String, body: String) async
   - func search(keyword: String) async -> [String]  // note titles matching
   - Use CNNoteStorePickerDelegate or App Intents Notes schema

2. MailTool — via MailKit / MFMailComposeViewController:
   - func draftReply(to: String, subject: String, body: String) async
     · opens compose sheet pre-filled (user confirms send)
   - func recentThreadSummary(from: String) async -> String
     · uses LLMRouter to summarize if thread available

3. MessagesTool:
   - func draft(to: String, body: String) async
     · MFMessageComposeViewController pre-filled
   - func openConversation(with: String) async
     · deeplink to Messages app

CRITICAL: mail and messages NEVER send without user confirmation.
Always open compose UI — never silent send.

Add MeetingPrepTrigger to ProactiveEngine:
  - 30 min before any meeting with attendees
  - Pulls CalendarTool + ContactsTool + MemoryStore context
  - Surface: "[N] people in your call in 30 min — want a quick brief?"

Build. Run /privacy-audit. Run /bg-budget.
```

---

## SPRINT 6 — SETTINGS UI + APP STORE POLISH
Duration: ~4 days
Goal: Clean settings, smooth onboarding, privacy policy, App Store ready.

### Prompt 6.1 — Settings UI
```
Build the Settings UI for Sumi in Sumi/UI/. SwiftUI only.

SumiSettingsView.swift — NavigationStack with List:

Section: "Intelligence"
  - Toggle: On-Device (Foundation Models) — default on
  - Toggle: Cloud reasoning (Claude API) — default on
  - Text field: Worker URL (saved to Keychain, not shown in full)

Section: "Proactive"
  - Toggle: Morning briefing — time picker (default 7:00am)
  - Toggle: Meeting prep (30 min before meetings)
  - Toggle: Follow-up reminders
  - Stepper: Max alerts per day (1–5, default 3)
  - Time range: Quiet hours start/end

Section: "Siri Integration"
  - NavigationLink → SiriTipsView showing example phrases for each intent
  - Button: "Add to Siri" for each shortcut

Section: "Integrations"
  - Row per integration: Calendar ✓, Contacts ✓, Reminders ✓, Notes, Mail, Messages
  - Tapping unauthorized one → request permission

Section: "Memory"
  - Text: "X memories stored"
  - Text: "Sumi last ran: [relative time]" — helps users verify BGTask is working
  - Button: "Clear all memory" → destructive confirmation alert

Section: "About"
  - Version, Privacy Policy link, Delete Account

Design: system-default SwiftUI List. Clean, not custom.
All toggles persist to UserDefaults. Worker URL to Keychain.
Build.
```

### Prompt 6.2 — Onboarding
```
Build a 4-screen onboarding flow for Sumi in Sumi/UI/Onboarding/.

OnboardingView.swift — TabView with .tabViewStyle(.page):

Screen 1 — Welcome:
  - Large "Sumi" wordmark
  - Subhead: "Your personal agent. Works while you live."
  - Body: "Sumi learns who you are, remembers what you said,
           and surfaces things before you think to ask."
  - CTA: "Get started"

Screen 2 — Permissions:
  - Request in order: Notifications, Calendar, Contacts, Reminders
  - Each as a card: icon, name, one-line plain-english benefit (not "Sumi needs X"
    but "Sumi reads your calendar to brief you before meetings")
  - "Allow" button per permission — request system dialog
  - Skip option (degraded experience warning)

Screen 3 — Siri Setup:
  - Show 3 example phrases with waveform animation
  - "Hey Siri, ask Sumi what's my day"
  - "Hey Siri, ask Sumi what I said about [topic]"
  - "Hey Siri, ask Sumi about my history with [name]"
  - Note: "Sumi works through Siri — you won't need to open this app."

Screen 4 — Background:
  - Explain: Sumi runs quietly in the background
  - IMPORTANT: "Don't force-quit Sumi — it stops working if you do"
  - CTA: "Start Sumi" — sets onboarding complete flag, dismiss

Build. Show onboarding only on first launch (UserDefaults flag).
```

### Prompt 6.3 — Final Pre-Submission
```
Run final pre-submission checks for Sumi App Store submission.

1. Run /privacy-audit — fix all violations
2. Run /spoken-check — fix all intent responses
3. Run /bg-budget — verify all BGTask handlers < 25s (hard timeout at 20s)

4. Add Privacy Manifest (PrivacyInfo.xcprivacy):
   - Declare: NSPrivacyAccessedAPITypes for UserDefaults
   - Data collection: none — all data stays on device
   - No third-party SDKs requiring manifest entries

5. Check all Info.plist usage strings are human-readable:
   - NSCalendarsUsageDescription: clear one sentence
   - NSContactsUsageDescription: clear one sentence
   - NSRemindersUsageDescription: clear one sentence
   - NSSpeechRecognitionUsageDescription: clear one sentence

6. Test on physical device (not just simulator):
   - Background task fires after app background for 5+ min
   - All 4 Siri intents respond within 3 seconds
   - Notification actions work from locked screen

7. Build release scheme, run full test suite, confirm zero failures.
8. Archive and upload to App Store Connect.

Report any issues found. Fix each before archiving.
```

---

## REFERENCE: COMPLETE SPRINT MAP

| Sprint            | Goal                 | Key Deliverable                              | TestFlight? |
|-------------------|----------------------|----------------------------------------------|-------------|
| 0 — Scaffold      | Buildable project    | CLAUDE.md, folder structure, SPM wired       | No          |
| 1 — Memory        | Brain exists         | SwiftData + sqlite-vec + MemoryStore         | No          |
| 2 — Proactive     | First magic moment   | Morning briefing fires without being asked   | No          |
| 3 — Voice         | User can talk to it  | All 4 Siri intents working                   | YES →       |
| 4 — Agent         | It follows up        | Commitment tracking, FollowUpTrigger         | Update      |
| 5 — Integrations  | Genuinely smart      | Mail, Messages, Notes, MeetingPrep           | Update      |
| 6 — Polish        | App Store ready      | Onboarding, Settings, Privacy Manifest       | App Store   |

## MONTHLY COST AT LAUNCH

| Item                                                          | Cost           |
|---------------------------------------------------------------|----------------|
| Foundation Models inference                                   | $0 — on device |
| Claude API (500 active users, ~3 cloud calls/day each)        | ~$45–90/mo     |
| Cloudflare Workers                                            | $0 — free tier |
| Apple Developer Program                                       | $99/yr         |
| Total at 500 users                                            | ~$50–95/mo     |

Target ratio: 70% on-device / 30% cloud at steady state.
