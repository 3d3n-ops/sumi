//
//  FollowUpTriggerTests.swift
//  sumi-iosTests
//
//  Follow-up surface: fires for aged commitments, picks the right action, and
//  stays quiet when nothing is due. No EventKit permission, no network.
//

import Foundation
import SwiftData
import EventKit
import Contacts
import Testing
@testable import sumi_ios

struct FollowUpTriggerTests {

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
            .appendingPathComponent("sumi-followup-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(
            modelContainer: container,
            embeddingService: DeterministicEmbedder(),
            vectorStore: vectorStore
        )
    }

    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    @Test func firesForAgedCommitmentWithPerson() async throws {
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "send Sarah the deck", createdAt: daysAgo(4), targetPerson: "Sarah"))

        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = try #require(await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore()))

        #expect(surface.triggerID == "commitment.followup")
        #expect(surface.message == "send Sarah the deck — still open 4 days later.")
        #expect(surface.primaryActionTitle == "Do it now")
        #expect(surface.primaryAction == .composeMessage(to: "Sarah"))
        #expect(surface.relevanceScore >= ProactiveEngine.relevanceThreshold)
    }

    @Test func usesRemindersWhenNoPerson() async throws {
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "renew the lease", createdAt: daysAgo(5)))

        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = try #require(await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore()))
        #expect(surface.primaryAction == .openReminders)
    }

    @Test func picksMostUrgentCommitment() async throws {
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "less urgent", createdAt: daysAgo(3)))
        try await memory.writeCommitment(Commitment(text: "most urgent", createdAt: daysAgo(6)))

        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = try #require(await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore()))
        #expect(surface.message.hasPrefix("most urgent"))
    }

    @Test func quietWhenOnlyFreshCommitments() async throws {
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "just said this", createdAt: now.addingTimeInterval(-3_600)))

        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }

    @Test func quietWhenNoCommitments() async throws {
        let memory = try makeMemory()
        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }

    @Test func quietBelowThreshold() async throws {
        // ~2 days old, no event → 0.50 + 0.20 = 0.70, under the 0.80 bar.
        let memory = try makeMemory()
        try await memory.writeCommitment(Commitment(text: "borderline", createdAt: daysAgo(2)))

        let trigger = FollowUpTrigger(events: FakeUpcomingEvents(), now: { self.now })
        let surface = await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }
}
