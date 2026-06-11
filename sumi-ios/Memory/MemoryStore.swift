//
//  MemoryStore.swift
//  sumi-ios
//
//  Main interface for writing, searching, and decaying memories.
//

import Foundation
import OSLog
import SwiftData

/// Actor-backed memory layer. SwiftData access is marshalled onto the main actor.
actor MemoryStore {
    private let modelContainer: ModelContainer
    private let embeddingService: EmbeddingService
    private let vectorStore: VectorStore
    private let entityExtractor: EntityExtractor
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "MemoryStore")

    init(
        modelContainer: ModelContainer,
        embeddingService: EmbeddingService = EmbeddingService(),
        vectorStore: VectorStore,
        entityExtractor: EntityExtractor = EntityExtractor()
    ) {
        self.modelContainer = modelContainer
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.entityExtractor = entityExtractor
    }

    /// Writes a memory: entity extraction → embedding → vector insert → SwiftData save.
    func write(_ content: String, tier: MemoryTier) async throws -> MemoryEntry {
        let entities = await entityExtractor.extract(from: content)
        guard let vector = await embeddingService.embed(content) else {
            throw MemoryStoreError.embeddingFailed
        }

        let id = UUID()
        let key = id.uuidString
        try await vectorStore.insert(key: key, vector: vector)

        return try await MainActor.run {
            let entry = MemoryEntry(
                id: id,
                tier: tier,
                content: content,
                entities: entities,
                embeddingKey: key
            )
            try saveEntry(entry)
            return entry
        }
    }

    /// Embeds the query, searches vectors, resolves entries, and cleans up orphans.
    func search(_ query: String, topK: Int = 5) async throws -> [MemoryEntry] {
        guard let queryVector = await embeddingService.embed(query) else {
            return []
        }

        let validKeys = try await MainActor.run { try allEmbeddingKeys() }
        let searchResult = try await vectorStore.search(
            query: queryVector,
            topK: topK,
            validKeys: validKeys
        )

        for key in searchResult.orphanKeys {
            try await vectorStore.delete(key: key)
            logger.debug("Removed orphaned vector key: \(key, privacy: .public)")
        }

        let matchKeys = searchResult.matches.map(\.key)
        let contentByKey = try await MainActor.run { try contentForKeys(matchKeys) }

        for key in matchKeys {
            guard let content = contentByKey[key] else { continue }
            if try await vectorStore.contains(key: key) == false {
                try await reembed(content: content, key: key)
            }
        }

        return try await MainActor.run {
            try matchKeys.compactMap { try fetchEntry(idString: $0) }
        }
    }

    /// Reduces importance for decaying tiers and deletes weak memories.
    /// Call only from `BGProcessingTask` (`com.sumi.maintenance`).
    func decayImportance() async throws {
        let keysToDelete = try await MainActor.run { try decayEntries() }
        for key in keysToDelete {
            try await vectorStore.delete(key: key)
        }
    }

    // MARK: - SwiftData (called on main actor)

    @MainActor
    private func saveEntry(_ entry: MemoryEntry) throws {
        let context = modelContainer.mainContext
        context.insert(entry)
        try context.save()
    }

    @MainActor
    private func fetchEntry(idString: String) throws -> MemoryEntry? {
        guard let id = UUID(uuidString: idString) else { return nil }
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private func contentForKeys(_ keys: [String]) throws -> [String: String] {
        var contentByKey: [String: String] = [:]
        for key in keys {
            guard let entry = try fetchEntry(idString: key) else { continue }
            contentByKey[key] = entry.content
        }
        return contentByKey
    }

    @MainActor
    private func allEmbeddingKeys() throws -> Set<String> {
        let all = try modelContainer.mainContext.fetch(FetchDescriptor<MemoryEntry>())
        return Set(all.map(\.embeddingKey).filter { !$0.isEmpty })
    }

    @MainActor
    private func decayEntries() throws -> [String] {
        let context = modelContainer.mainContext
        let all = try context.fetch(FetchDescriptor<MemoryEntry>())
        var keysToDelete: [String] = []

        for entry in all {
            switch entry.tier {
            case .episodic:
                entry.importance -= 0.02
            case .context:
                entry.importance -= 0.005
            case .identity:
                continue
            }

            if entry.importance < 0.05 {
                keysToDelete.append(entry.embeddingKey)
                context.delete(entry)
            }
        }

        try context.save()
        return keysToDelete
    }

    private func reembed(content: String, key: String) async throws {
        guard let vector = await embeddingService.embed(content) else { return }
        try await vectorStore.insert(key: key, vector: vector)
    }
}

enum MemoryStoreError: Error {
    case embeddingFailed
}
