//
//  FollowUpTrigger.swift
//  sumi-ios
//
//  Surfaces the most urgent open commitment so Sumi can nudge the user about
//  something they said they'd do but haven't.
//

import Foundation
import EventKit
import Contacts

/// Fires when an open commitment is urgent enough (> 0.80) to be worth a nudge.
///
/// Builds a `CommitmentTracker` around the engine-supplied `memory` so it always
/// reads the same store, and injects an upcoming-events provider (real EventKit in
/// production, a fake in tests) for the urgency bonus.
struct FollowUpTrigger: ProactiveTrigger {
    let triggerID = "commitment.followup"

    private let events: any UpcomingEventsProviding
    private let now: @Sendable () -> Date

    init(
        events: any UpcomingEventsProviding = EventKitUpcomingEventsProvider(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.events = events
        self.now = now
    }

    func evaluate(memory: MemoryStore, calendar: EKEventStore, contacts: CNContactStore) async -> ProactiveSurface? {
        let current = now()
        let tracker = CommitmentTracker(memory: memory, events: events, now: now)

        let open = await tracker.openCommitments()
        guard !open.isEmpty else { return nil }

        // Score each and keep the most urgent.
        var best: (commitment: Commitment, score: Float)?
        for commitment in open {
            let score = await tracker.urgencyScore(for: commitment)
            if best == nil || score > best!.score {
                best = (commitment, score)
            }
        }
        guard let best, best.score > ProactiveEngine.relevanceThreshold else { return nil }

        let daysOpen = max(1, Int(current.timeIntervalSince(best.commitment.createdAt) / 86_400))
        let dayPhrase = daysOpen == 1 ? "1 day" : "\(daysOpen) days"
        let message = "\(best.commitment.text) — still open \(dayPhrase) later."

        // Nudge toward a message if we know who it's for, else open Reminders.
        let action: SumiAction = best.commitment.targetPerson
            .map { SumiAction.composeMessage(to: $0) } ?? .openReminders

        return ProactiveSurface(
            message: message,
            primaryActionTitle: "Do it now",
            primaryAction: action,
            relevanceScore: best.score,
            expiresAt: current.addingTimeInterval(4 * 60 * 60),
            triggerID: triggerID
        )
    }
}
