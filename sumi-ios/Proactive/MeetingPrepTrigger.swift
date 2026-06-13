//
//  MeetingPrepTrigger.swift
//  sumi-ios
//
//  Surfaces a quick-prep nudge ~30 minutes before a meeting that has attendees.
//

import Foundation
import EventKit
import Contacts

/// Fires when a meeting with attendees starts within the next 30 minutes.
///
/// Reuses `CalendarEventsProviding` (today's events, with attendee counts) so it's
/// testable without EventKit permission. The surface is templated — no LLM call —
/// keeping it cheap enough for a background run.
struct MeetingPrepTrigger: ProactiveTrigger {
    let triggerID = "meeting.prep"

    /// How far ahead a meeting must start to qualify for a prep nudge.
    static let leadWindow: TimeInterval = 30 * 60
    /// Score for a qualifying meeting (above the 0.80 fire threshold).
    static let score: Float = 0.85

    private let calendarProvider: any CalendarEventsProviding
    private let now: @Sendable () -> Date

    init(
        calendarProvider: any CalendarEventsProviding = EventKitCalendarProvider(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.calendarProvider = calendarProvider
        self.now = now
    }

    func evaluate(memory: MemoryStore, calendar: EKEventStore, contacts: CNContactStore) async -> ProactiveSurface? {
        let current = now()
        let events = await calendarProvider.todaysEvents(at: current)

        // Meetings with attendees starting within the next 30 minutes, soonest first.
        let upcoming = events
            .filter { $0.hasAttendees }
            .filter { event in
                let delta = event.startDate.timeIntervalSince(current)
                return delta > 0 && delta <= Self.leadWindow
            }
            .sorted { $0.startDate < $1.startDate }

        guard let meeting = upcoming.first else { return nil }

        let minutes = max(1, Int((meeting.startDate.timeIntervalSince(current) / 60).rounded()))
        let count = max(meeting.attendeeCount, 1)
        let people = count == 1 ? "1 person" : "\(count) people"
        let message = "\(people) in your call in \(minutes) min — want a quick brief?"

        return ProactiveSurface(
            message: message,
            primaryActionTitle: "Open Calendar",
            primaryAction: .openCalendar,
            relevanceScore: Self.score,
            expiresAt: meeting.startDate,
            triggerID: triggerID
        )
    }
}
