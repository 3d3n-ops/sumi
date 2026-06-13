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
    private let embeddingService: any TextEmbedder
    private let vectorStore: VectorStore
    private let entityExtractor: EntityExtractor
    private let commitmentExtractor: CommitmentExtractor?
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "MemoryStore")

    /// Reserved entity tag marking a `MemoryEntry` that represents a commitment.
    static let commitmentTag = "__commitment__"
    /// Reserved tag added when a commitment is satisfied.
    static let resolvedTag = "__commitment_resolved__"
    /// Prefix for the reserved tag carrying a commitment's target person.
    static let targetPrefix = "__commitment_target__:"

    init(
        modelContainer: ModelContainer,
        embeddingService: any TextEmbedder = EmbeddingService(),
        vectorStore: VectorStore,
        entityExtractor: EntityExtractor = EntityExtractor(),
        commitmentExtractor: CommitmentExtractor? = nil
    ) {
        self.modelContainer = modelContainer
        self.embeddingService = embeddingService
        self.vectorStore = vectorStore
        self.entityExtractor = entityExtractor
        self.commitmentExtractor = commitmentExtractor
    }

    /// Writes a memory: entity extraction → embedding → vector insert → SwiftData save.
    /// After a successful write, mines the content for commitments in the background.
    func write(_ content: String, tier: MemoryTier) async throws -> MemoryEntry {
        let entities = await entityExtractor.extract(from: content)
        let entry = try await persist(content: content, tier: tier, id: UUID(), timestamp: .now, entities: entities)
        scheduleCommitmentExtraction(from: content, tier: tier)
        return entry
    }

    /// Persists a commitment as a tagged `.context` memory so the proactive layer
    /// can find and follow up on it later. Does not re-run commitment extraction,
    /// so it is safe to call from the extraction path without recursing.
    @discardableResult
    func writeCommitment(_ commitment: Commitment) async throws -> MemoryEntry {
        var entities = await entityExtractor.extract(from: commitment.text)
        entities.append(Self.commitmentTag)
        if let person = commitment.targetPerson, !person.isEmpty {
            entities.append(Self.targetPrefix + person)
        }
        if commitment.isResolved {
            entities.append(Self.resolvedTag)
        }
        return try await persist(
            content: commitment.text,
            tier: .context,
            id: commitment.id,
            timestamp: commitment.createdAt,
            entities: entities
        )
    }

    /// All unresolved commitments, reconstructed from their backing memories.
    func openCommitments() async throws -> [Commitment] {
        try await MainActor.run {
            let all = try modelContainer.mainContext.fetch(FetchDescriptor<MemoryEntry>())
            return all.compactMap { Self.commitment(from: $0) }.filter { !$0.isResolved }
        }
    }

    /// Marks a commitment resolved by tagging its backing memory. No-op if absent
    /// or already resolved.
    func resolveCommitment(_ id: UUID) async throws {
        try await MainActor.run {
            guard let entry = try fetchEntry(idString: id.uuidString),
                  entry.entities.contains(Self.commitmentTag),
                  !entry.entities.contains(Self.resolvedTag) else {
                return
            }
            entry.entities.append(Self.resolvedTag)
            try modelContainer.mainContext.save()
        }
    }

    /// Reconstructs a `Commitment` from a tagged entry, or `nil` if untagged.
    @MainActor
    private static func commitment(from entry: MemoryEntry) -> Commitment? {
        guard entry.entities.contains(commitmentTag) else { return nil }
        let target = entry.entities
            .first { $0.hasPrefix(targetPrefix) }
            .map { String($0.dropFirst(targetPrefix.count)) }
        return Commitment(
            id: entry.id,
            text: entry.content,
            createdAt: entry.timestamp,
            targetPerson: target,
            isResolved: entry.entities.contains(resolvedTag)
        )
    }

    /// Shared write core: embedding → vector insert → SwiftData save.
    private func persist(
        content: String,
        tier: MemoryTier,
        id: UUID,
        timestamp: Date,
        entities: [String]
    ) async throws -> MemoryEntry {
        guard let vector = await embeddingService.embed(content) else {
            throw MemoryStoreError.embeddingFailed
        }
        let key = id.uuidString
        try await vectorStore.insert(key: key, vector: vector)

        return try await MainActor.run {
            let entry = MemoryEntry(
                id: id,
                timestamp: timestamp,
                tier: tier,
                content: content,
                entities: entities,
                embeddingKey: key
            )
            try saveEntry(entry)
            return entry
        }
    }

    /// Mines `content` for commitments off the write path so `write` returns
    /// immediately (the BGTask budget can't absorb a synchronous LLM call). Gated
    /// to user-interaction (`.episodic`) memories of meaningful length to avoid an
    /// LLM call on every trivial write. Only the on-device model is free today; on
    /// the cloud path this costs a call, so keep the gate conservative.
    private func scheduleCommitmentExtraction(from content: String, tier: MemoryTier) {
        guard let commitmentExtractor, tier == .episodic, content.count >= 12 else { return }
        Task {
            let commitments = await commitmentExtractor.extract(from: content)
            for commitment in commitments {
                _ = try? await self.writeCommitment(commitment)
            }
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
