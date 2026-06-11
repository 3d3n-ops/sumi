//
//  MemoryStoreTests.swift
//  sumi-iosTests
//
//  Integration tests for MemoryStore write + search.
//

import Foundation
import SwiftData
import Testing
@testable import sumi_ios

/// Deterministic lexical embedder for tests — independent of the on-device
/// `NLEmbedding` model, which is absent on CI simulators. Shared tokens map to
/// shared dimensions, so word overlap drives cosine similarity predictably.
struct DeterministicEmbedder: TextEmbedder {
    func embed(_ text: String) async -> [Float]? {
        let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        guard !tokens.isEmpty else { return nil }

        var vector = [Float](repeating: 0, count: EmbeddingService.dimension)
        for token in tokens {
            var hash: UInt = 5381
            for byte in token.utf8 { hash = (hash &* 33) &+ UInt(byte) }
            vector[Int(hash % UInt(vector.count))] += 1
        }

        let norm = (vector.reduce(0) { $0 + $1 * $1 }).squareRoot()
        guard norm > 0 else { return nil }
        return vector.map { $0 / norm }
    }
}

struct MemoryStoreTests {

    @Test func writeFiveMemoriesSearchReturnsRelevantOne() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)

        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-vectors-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        let store = MemoryStore(
            modelContainer: container,
            embeddingService: DeterministicEmbedder(),
            vectorStore: vectorStore
        )

        let memories: [(String, MemoryTier)] = [
            ("User prefers oat milk in coffee", .identity),
            ("Meeting with Sarah Chen about Q3 roadmap at Apple Park", .context),
            ("Bought groceries: eggs, bread, and butter", .episodic),
            ("Sumi memory layer ships vector search this sprint", .context),
            ("Weather was sunny in Seattle yesterday", .episodic),
        ]

        var targetID: UUID?
        for (content, tier) in memories {
            let entry = try await store.write(content, tier: tier)
            if content.contains("Sarah Chen") {
                targetID = entry.id
            }
        }

        let results = try await store.search("Sarah Chen Q3 roadmap meeting", topK: 3)
        #expect(!results.isEmpty)

        let top = try #require(results.first)
        #expect(top.id == targetID)
        #expect(top.content.contains("Sarah Chen"))
        #expect(!top.entities.isEmpty)
    }

    @Test func decayRemovesLowImportanceEpisodic() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)

        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-vectors-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        let store = MemoryStore(
            modelContainer: container,
            embeddingService: DeterministicEmbedder(),
            vectorStore: vectorStore
        )

        _ = try await store.write("ephemeral note", tier: .episodic)

        for _ in 0..<48 {
            try await store.decayImportance()
        }

        let remaining = try await MainActor.run {
            try container.mainContext.fetch(FetchDescriptor<MemoryEntry>())
        }
        #expect(remaining.isEmpty)
    }
}
