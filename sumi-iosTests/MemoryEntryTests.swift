//
//  MemoryEntryTests.swift
//  sumi-iosTests
//
//  Memory layer — model creation and persistence.
//

import Testing
import SwiftData
import Foundation
@testable import sumi_ios

struct MemoryEntryTests {

    @Test func createsWithDefaults() {
        let entry = MemoryEntry(tier: .identity, content: "User prefers tea over coffee")

        #expect(entry.tier == .identity)
        #expect(entry.content == "User prefers tea over coffee")
        #expect(entry.importance == 1.0)
        #expect(entry.entities.isEmpty)
        #expect(entry.relatedIDs.isEmpty)
        #expect(entry.embeddingKey.isEmpty)
    }

    @Test func tierDescriptionsAreSpokenProse() {
        #expect(MemoryTier.identity.description == "persistent facts about the user")
        #expect(MemoryTier.context.description == "active 14-day window")
        #expect(MemoryTier.episodic.description == "recent 48-hour interactions")
        #expect(MemoryTier.allCases.count == 3)
    }

    @MainActor
    @Test func persistsAndFetches() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)
        let context = container.mainContext

        let entry = MemoryEntry(
            tier: .context,
            content: "Shipping Sumi memory layer",
            entities: ["Sumi"],
            embeddingKey: "vec-1"
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MemoryEntry>())
        #expect(fetched.count == 1)

        let stored = try #require(fetched.first)
        #expect(stored.id == entry.id)
        #expect(stored.content == "Shipping Sumi memory layer")
        #expect(stored.tier == .context)
        #expect(stored.entities == ["Sumi"])
        #expect(stored.embeddingKey == "vec-1")
    }

    @MainActor
    @Test func storesAllTiers() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)
        let context = container.mainContext

        for tier in MemoryTier.allCases {
            context.insert(MemoryEntry(tier: tier, content: "memory for \(tier.rawValue)"))
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MemoryEntry>())
        #expect(Set(fetched.map(\.tier)) == Set(MemoryTier.allCases))
    }
}
