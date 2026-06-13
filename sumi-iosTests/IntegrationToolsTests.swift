//
//  IntegrationToolsTests.swift
//  sumi-iosTests
//
//  Pure/composable bits of the integration tools — no EventKit/Contacts
//  permission, no network. Device-only I/O paths are exercised on-device.
//

import Foundation
import SwiftData
import Contacts
import Testing
@testable import sumi_ios

struct IntegrationToolsTests {

    private func makeMemory() throws -> MemoryStore {
        let container = try ModelContainer(
            for: MemoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-tools-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(
            modelContainer: container,
            embeddingService: DeterministicEmbedder(),
            vectorStore: vectorStore
        )
    }

    // MARK: - CalendarTool

    @Test func prepWindowIs30MinutesBeforeStart() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15; comps.hour = 14
        let start = Calendar(identifier: .gregorian).date(from: comps)!
        #expect(CalendarTool.prepWindow(before: start) == start.addingTimeInterval(-30 * 60))
    }

    // MARK: - ContactsTool.composeContext

    @Test func contextWithoutMemoryIsHonest() async throws {
        let memory = try makeMemory()
        let context = await ContactsTool.composeContext(name: "Jordan Rivera", memory: memory)
        #expect(context.contains("Jordan Rivera"))
        #expect(context.contains("don't have any notes"))
    }

    @Test func contextIncludesRememberedSnippets() async throws {
        let memory = try makeMemory()
        _ = try await memory.write("Sarah Chen leads the Q3 roadmap and prefers morning syncs", tier: .identity)

        let context = await ContactsTool.composeContext(name: "Sarah Chen", memory: memory)
        #expect(context.contains("Sarah Chen"))
        #expect(context.contains("roadmap"))
    }

    @Test func contactContextFormatsName() async throws {
        let memory = try makeMemory()
        let contact = CNMutableContact()
        contact.givenName = "Alex"
        contact.familyName = "Kim"

        let context = await ContactsTool().contactContext(contact: contact, memory: memory)
        #expect(context.contains("Alex Kim"))
    }

    // MARK: - NotesTool

    @MainActor
    @Test func notesSearchIsUnavailable() async {
        let results = await NotesTool().search(keyword: "anything")
        #expect(results.isEmpty)
    }
}
