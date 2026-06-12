//
//  ProactiveEngine.swift
//  sumi-ios
//
//  Evaluates triggers, applies gating (quiet hours, daily cap, suppression,
//  relevance threshold), and fires at most one surface per run.
//

import Foundation
import EventKit
import Contacts
import OSLog

/// The brain of the proactive layer.
///
/// Gating rules (CLAUDE.md): quiet hours 9pm–7am; max 3 surfaces/day; relevance
/// threshold 0.80; a twice-dismissed trigger is suppressed. All time-of-day and
/// daily-count inputs are injectable so tests are deterministic.
actor ProactiveEngine {
    /// Minimum relevance for a surface to fire.
    static let relevanceThreshold: Float = 0.80
    /// Maximum surfaces per day.
    static let dailyCap = 3

    /// Registered triggers. Empty until 2.3c registers `MorningBriefTrigger`.
    let allTriggers: [any ProactiveTrigger]

    private let memory: MemoryStore
    private let calendarStore: EKEventStore
    private let contactStore: CNContactStore
    private let composer: NotificationComposer
    private let suppressed: SuppressedTriggers
    private let dailyCounter: DailySurfaceCounter
    /// Injectable clock so quiet-hours/daily checks are testable.
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "ProactiveEngine")

    init(
        memory: MemoryStore,
        triggers: [any ProactiveTrigger] = [],
        calendarStore: EKEventStore = EKEventStore(),
        contactStore: CNContactStore = CNContactStore(),
        composer: NotificationComposer = NotificationComposer(),
        suppressed: SuppressedTriggers = SuppressedTriggers(),
        dailyCounter: DailySurfaceCounter = DailySurfaceCounter(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.memory = memory
        self.allTriggers = triggers
        self.calendarStore = calendarStore
        self.contactStore = contactStore
        self.composer = composer
        self.suppressed = suppressed
        self.dailyCounter = dailyCounter
        self.calendar = calendar
        self.now = now
    }

    /// Whether the current time falls in quiet hours (9pm–7am).
    func isQuietHours(at date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 21 || hour < 7
    }

    /// Evaluates all triggers and fires the single best eligible surface, if any.
    func evaluate() async {
        let current = now()

        guard !isQuietHours(at: current) else {
            logger.debug("Skipping evaluation — quiet hours.")
            return
        }
        guard dailyCounter.count(on: current) < Self.dailyCap else {
            logger.debug("Skipping evaluation — daily cap reached.")
            return
        }
        guard !allTriggers.isEmpty else { return }

        // Run all triggers concurrently and collect non-nil surfaces.
        var surfaces: [ProactiveSurface] = []
        await withTaskGroup(of: ProactiveSurface?.self) { group in
            for trigger in allTriggers {
                group.addTask { [memory, calendarStore, contactStore] in
                    await trigger.evaluate(
                        memory: memory,
                        calendar: calendarStore,
                        contacts: contactStore
                    )
                }
            }
            for await surface in group {
                if let surface { surfaces.append(surface) }
            }
        }

        // Highest relevance first; take the best one that passes all gates.
        let ranked = surfaces.sorted { $0.relevanceScore > $1.relevanceScore }
        for surface in ranked {
            guard surface.relevanceScore >= Self.relevanceThreshold else { continue }
            guard surface.isFresh(at: current) else { continue }
            guard !suppressed.isSuppressed(surface.triggerID, at: current) else { continue }

            await composer.fire(surface: surface)
            dailyCounter.increment(on: current)
            logger.info("Fired proactive surface: \(surface.triggerID, privacy: .public)")
            return
        }
    }
}
