//
//  CalendarTool.swift
//  sumi-ios
//
//  Read-only calendar access for the agent. Never prompts for permission and
//  returns empty when access isn't granted — callers degrade gracefully.
//

import Foundation
import EventKit

/// Calendar reads: today, upcoming, and events involving a person.
actor CalendarTool: SumiTool {
    let toolID = "calendar"
    let description = "Reads the user's calendar: today's events, upcoming events over the next N days, and events involving a named person."

    /// Minutes before an event that prep should surface.
    static let prepLeadTime: TimeInterval = 30 * 60

    private let store: EKEventStore
    private let calendar: Calendar

    init(store: EKEventStore = EKEventStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    private var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Events occurring today.
    func todayEvents(now: Date = .now) async -> [EKEvent] {
        guard isAuthorized else { return [] }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
    }

    /// Events from now through `days` ahead.
    func upcomingEvents(days: Int, now: Date = .now) async -> [EKEvent] {
        guard isAuthorized, days > 0 else { return [] }
        guard let end = calendar.date(byAdding: .day, value: days, to: now) else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: now, end: end, calendars: nil))
    }

    /// Upcoming events (next 30 days) whose title or attendees mention `personName`.
    func eventsInvolving(personName: String, now: Date = .now) async -> [EKEvent] {
        let needle = personName.lowercased()
        guard !needle.isEmpty else { return [] }
        let events = await upcomingEvents(days: 30, now: now)
        return events.filter { event in
            if let title = event.title?.lowercased(), title.contains(needle) { return true }
            return event.attendees?.contains { ($0.name?.lowercased().contains(needle)) ?? false } ?? false
        }
    }

    /// The moment prep for `event` should surface (30 min before it starts).
    nonisolated func prepWindowFor(event: EKEvent) -> Date {
        Self.prepWindow(before: event.startDate ?? .now)
    }

    /// Pure helper: the prep window before a start time.
    static func prepWindow(before start: Date) -> Date {
        start.addingTimeInterval(-prepLeadTime)
    }
}
