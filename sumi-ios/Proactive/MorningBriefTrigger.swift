//
//  MorningBriefTrigger.swift
//  sumi-ios
//
//  Produces a one-sentence morning briefing from today's calendar + recent
//  commitments, with a foreground-computed cache so background runs skip the LLM.
//

import Foundation
import EventKit
import Contacts
import OSLog

/// Synthesizes a one-sentence spoken briefing. `LLMRouter` is the production
/// conformer; tests inject a fake so the trigger needs no network or on-device model.
protocol BriefSynthesizing: Sendable {
    func synthesizeBrief(prompt: String) async -> String
}

extension LLMRouter: BriefSynthesizing {
    func synthesizeBrief(prompt: String) async -> String {
        // Briefing is light drafting — route normally with no memory context here;
        // context is already folded into `prompt` by the trigger.
        await respond(query: prompt, context: [], image: nil)
    }
}

/// Cached briefing payload persisted to UserDefaults after a foreground session.
struct BriefCache: Codable, Sendable {
    var message: String
    var computedAt: Date
    var expiresAt: Date
}

/// The morning brief trigger.
///
/// Scores 0.95 when there are events today, else 0.60. Expires at 10am. Uses a
/// fresh (<2h, unexpired) cache when available to avoid an LLM call in the
/// background; otherwise recomputes.
struct MorningBriefTrigger: ProactiveTrigger {
    let triggerID = "morning.brief"

    /// Max cache age before the trigger recomputes.
    static let cacheFreshness: TimeInterval = 2 * 60 * 60
    static let cacheKey = "sumi.brief.cache"

    private let router: any BriefSynthesizing
    private let defaults: UserDefaults
    private let calendarProvider: any CalendarEventsProviding
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "MorningBriefTrigger")

    init(
        router: any BriefSynthesizing,
        defaults: UserDefaults = .standard,
        calendarProvider: any CalendarEventsProviding = EventKitCalendarProvider(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.router = router
        self.defaults = defaults
        self.calendarProvider = calendarProvider
        self.calendar = calendar
        self.now = now
    }

    func evaluate(memory: MemoryStore, calendar: EKEventStore, contacts: CNContactStore) async -> ProactiveSurface? {
        let current = now()

        // Cache hit: fresh and unexpired → skip the LLM entirely.
        if let cache = loadCache(),
           cache.expiresAt > current,
           current.timeIntervalSince(cache.computedAt) < Self.cacheFreshness {
            logger.debug("Morning brief served from cache.")
            return makeSurface(message: cache.message, hasEvents: nil, at: current, expiresAt: cache.expiresAt)
        }

        // Cache miss/stale: compute fresh.
        let events = await calendarProvider.todaysEvents(at: current)
        let message = await computeBrief(events: events, memory: memory, at: current)
        let expiresAt = tenAM(of: current)
        return makeSurface(message: message, hasEvents: !events.isEmpty, at: current, expiresAt: expiresAt)
    }

    /// Foreground pre-compute: builds the brief and writes it to the cache so a
    /// later background run can serve it without the LLM.
    func refreshCache(memory: MemoryStore, calendar: EKEventStore) async {
        let current = now()
        let events = await calendarProvider.todaysEvents(at: current)
        let message = await computeBrief(events: events, memory: memory, at: current)
        let cache = BriefCache(message: message, computedAt: current, expiresAt: tenAM(of: current))
        saveCache(cache)
    }

    // MARK: - Internal

    private func computeBrief(events: [BriefEvent], memory: MemoryStore, at date: Date) async -> String {
        // Gather lightweight memory context for events that have attendees.
        var contextSnippets: [String] = []
        for event in events where event.hasAttendees {
            if let results = try? await memory.search(event.title, topK: 2) {
                let contents = await MainActor.run { results.map { $0.content } }
                contextSnippets.append(contentsOf: contents)
            }
        }

        // Recent commitments (episodic) from the last 48h add to the briefing.
        if let commitments = try? await memory.search("commitment deadline reminder", topK: 3) {
            let recent = await MainActor.run {
                commitments
                    .filter { date.timeIntervalSince($0.timestamp) < 48 * 60 * 60 }
                    .map { $0.content }
            }
            contextSnippets.append(contentsOf: recent)
        }

        let prompt = Self.buildPrompt(events: events, context: contextSnippets)
        return await router.synthesizeBrief(prompt: prompt)
    }

    private func makeSurface(message: String, hasEvents: Bool?, at date: Date, expiresAt: Date) -> ProactiveSurface {
        let score: Float = (hasEvents ?? true) ? 0.95 : 0.60
        return ProactiveSurface(
            message: message,
            primaryActionTitle: "Open Calendar",
            primaryAction: .openCalendar,
            relevanceScore: score,
            expiresAt: expiresAt,
            triggerID: triggerID
        )
    }

    private func tenAM(of date: Date) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = 10; comps.minute = 0; comps.second = 0
        return calendar.date(from: comps) ?? date.addingTimeInterval(3600)
    }

    private func loadCache() -> BriefCache? {
        guard let data = defaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(BriefCache.self, from: data)
    }

    private func saveCache(_ cache: BriefCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: Self.cacheKey)
    }

    static func buildPrompt(events: [BriefEvent], context: [String]) -> String {
        var parts = ["Summarize the user's day in one short spoken sentence. No lists."]
        if events.isEmpty {
            parts.append("There are no events scheduled today.")
        } else {
            parts.append("Today's events: " + events.map { $0.title }.joined(separator: ", ") + ".")
        }
        if !context.isEmpty {
            parts.append("Relevant context: " + context.joined(separator: " "))
        }
        return parts.joined(separator: " ")
    }
}

/// Minimal, Sendable view of a calendar event the trigger needs.
struct BriefEvent: Sendable, Equatable {
    var title: String
    var hasAttendees: Bool
    var startDate: Date
    /// Number of attendees, when known (0 otherwise).
    var attendeeCount: Int = 0
}

/// Abstraction over fetching today's events so the trigger is testable without
/// EventKit permission. `EventKitCalendarProvider` is the production conformer.
protocol CalendarEventsProviding: Sendable {
    func todaysEvents(at date: Date) async -> [BriefEvent]
}

/// Production provider backed by EventKit. Returns an empty list when access is
/// not granted — never prompts or crashes.
struct EventKitCalendarProvider: CalendarEventsProviding {
    func todaysEvents(at date: Date) async -> [BriefEvent] {
        let store = EKEventStore()
        let status = EKEventStore.authorizationStatus(for: .event)
        // Only read when already authorized; never trigger a permission prompt here.
        guard status == .fullAccess else { return [] }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            BriefEvent(
                title: event.title ?? "Untitled",
                hasAttendees: (event.attendees?.isEmpty == false),
                startDate: event.startDate ?? start,
                attendeeCount: event.attendees?.count ?? 0
            )
        }
    }
}
