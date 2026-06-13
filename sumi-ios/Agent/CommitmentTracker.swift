//
//  CommitmentTracker.swift
//  sumi-ios
//
//  Reads back the commitments mined by CommitmentExtractor, scores their urgency,
//  and exposes resolution — the data the FollowUpTrigger surfaces from.
//

import Foundation
import EventKit

/// Whether a person has an upcoming calendar event within a window. Abstracted so
/// the tracker is testable without EventKit permission.
protocol UpcomingEventsProviding: Sendable {
    func hasUpcomingEvent(
        involving personName: String,
        within window: TimeInterval,
        at date: Date
    ) async -> Bool
}

/// Production provider backed by EventKit. Returns `false` when access is not
/// granted — never prompts or crashes.
struct EventKitUpcomingEventsProvider: UpcomingEventsProviding {
    func hasUpcomingEvent(involving personName: String, within window: TimeInterval, at date: Date) async -> Bool {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }

        let predicate = store.predicateForEvents(withStart: date, end: date.addingTimeInterval(window), calendars: nil)
        let needle = personName.lowercased()
        guard !needle.isEmpty else { return false }

        return store.events(matching: predicate).contains { event in
            if let title = event.title?.lowercased(), title.contains(needle) { return true }
            return event.attendees?.contains { ($0.name?.lowercased().contains(needle)) ?? false } ?? false
        }
    }
}

/// Tracks open commitments and how urgent each one is.
actor CommitmentTracker {
    /// Commitments younger than this are still "fresh" — not yet worth nudging.
    static let staleThreshold: TimeInterval = 24 * 60 * 60
    /// Lookahead for "the person you owe has something coming up".
    static let eventWindow: TimeInterval = 48 * 60 * 60

    private let memory: MemoryStore
    private let events: any UpcomingEventsProviding
    private let now: @Sendable () -> Date

    init(
        memory: MemoryStore,
        events: any UpcomingEventsProviding = EventKitUpcomingEventsProvider(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.memory = memory
        self.events = events
        self.now = now
    }

    /// Unresolved commitments that have been open longer than 24h.
    func openCommitments() async -> [Commitment] {
        let current = now()
        let all = (try? await memory.openCommitments()) ?? []
        return all.filter { current.timeIntervalSince($0.createdAt) > Self.staleThreshold }
    }

    /// Marks a commitment satisfied.
    func markResolved(_ id: UUID) async {
        try? await memory.resolveCommitment(id)
    }

    /// Urgency in 0.50...0.95: base 0.50, +0.10 per day open, +0.20 when the
    /// target person has an event in the next 48h.
    func urgencyScore(for commitment: Commitment) async -> Float {
        let current = now()
        let daysOpen = Float(Int(current.timeIntervalSince(commitment.createdAt) / 86_400))
        var score: Float = 0.50 + 0.10 * daysOpen

        if let person = commitment.targetPerson, !person.isEmpty,
           await events.hasUpcomingEvent(involving: person, within: Self.eventWindow, at: current) {
            score += 0.20
        }
        return min(score, 0.95)
    }
}
