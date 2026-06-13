//
//  CommitmentTrackerTests.swift
//  sumi-iosTests
//
//  Urgency scoring, staleness filtering, and resolution — no EventKit, no network.
//

import Foundation
import SwiftData
import Testing
@testable import sumi_ios

/// Fake upcoming-events provider: reports an event only for named people.
struct FakeUpcomingEvents: UpcomingEventsProviding {
    var peopleWithEvents: Set<String> = []
    func hasUpcomingEvent(involving personName: String, within window: TimeInterval, at date: Date) async -> Bool {
        peopleWithEvents.contains(personName)
    }
}

struct CommitmentTrackerTests {

    /// Fixed "now" so day-based scoring is deterministic.
    private let now: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15; comps.hour = 9
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private func makeMemory() throws -> MemoryStore {
        let container = try ModelContainer(
            for: MemoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-commit-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(
            modelContainer: container,
            embeddingService: DeterministicEmbedder(),
            vectorStore: vectorStore
        )
    }

    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test func urgencyGrowsWithAge() async throws {
        let memory = try makeMemory()
        let tracker = CommitmentTracker(memory: memory, events: FakeUpcomingEvents(), now: { self.now })

        let fourDays = Commitment(text: "send the report", createdAt: daysAgo(4))
        let score = await tracker.urgencyScore(for: fourDays)
        // 0.50 + 0.10 * 4 = 0.90, no event bonus.
        #expect(abs(score - 0.90) < 0.0001)
    }

    @Test func eventBonusAndCap() async throws {
        let memory = try makeMemory()
        let tracker = CommitmentTracker(
            memory: memory,
            events: FakeUpcomingEvents(peopleWithEvents: ["Sarah"]),
            now: { self.now }
        )

        // 0.50 + 0.40 (4 days) + 0.20 (event) = 1.10 → capped at 0.95.
        let urgent = Commitment(text: "send Sarah the deck", createdAt: daysAgo(4), targetPerson: "Sarah")
        #expect(await tracker.urgencyScore(for: urgent) == 0.95)

        // Same age, person has no upcoming event → no bonus.
        let noEvent = Commitment(text: "send Alex the deck", createdAt: daysAgo(4), targetPerson: "Alex")
        #expect(abs(await tracker.urgencyScore(for: noEvent) - 0.90) < 0.0001)
    }

    @Test func openCommitmentsExcludeFreshAndResolved() async throws {
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "old open commitment", createdAt: daysAgo(3)))
        try await memory.writeCommitment(Commitment(text: "fresh commitment", createdAt: now.addingTimeInterval(-3_600)))
        try await memory.writeCommitment(Commitment(text: "already done", createdAt: daysAgo(5), isResolved: true))

        let tracker = CommitmentTracker(memory: memory, events: FakeUpcomingEvents(), now: { self.now })
        let open = await tracker.openCommitments()

        #expect(open.count == 1)
        #expect(open.first?.text == "old open commitment")
    }

    @Test func markResolvedRemovesFromOpen() async throws {
        let memory = try makeMemory()
        let commitment = Commitment(text: "follow up with Jordan", createdAt: daysAgo(2))
        try await memory.writeCommitment(commitment)

        let tracker = CommitmentTracker(memory: memory, events: FakeUpcomingEvents(), now: { self.now })
        #expect(await tracker.openCommitments().count == 1)

        await tracker.markResolved(commitment.id)
        #expect(await tracker.openCommitments().isEmpty)
    }
}
