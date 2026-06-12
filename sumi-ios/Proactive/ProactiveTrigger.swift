//
//  ProactiveTrigger.swift
//  sumi-ios
//
//  The protocol every proactive trigger conforms to.
//

import Foundation
import EventKit
import Contacts

/// A source of potential proactive surfaces.
///
/// The engine evaluates all registered triggers concurrently. A trigger returns
/// `nil` when it has nothing relevant to surface. Implementations must be cheap
/// and respect the BGTask time budget — heavy work belongs off the main actor.
protocol ProactiveTrigger: Sendable {
    /// Stable identifier used for suppression bookkeeping and dedup.
    var triggerID: String { get }

    /// Evaluates current state and returns a surface to fire, or `nil`.
    func evaluate(
        memory: MemoryStore,
        calendar: EKEventStore,
        contacts: CNContactStore
    ) async -> ProactiveSurface?
}
