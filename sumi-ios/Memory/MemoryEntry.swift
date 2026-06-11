//
//  MemoryEntry.swift
//  sumi-ios
//
//  Memory layer — the persisted unit of memory.
//

import Foundation
import SwiftData

/// A single stored memory.
///
/// `MemoryEntry` is the durable record written by `MemoryStore`. Every write
/// runs entity extraction first, so `entities` is expected to be populated by
/// the time an entry is inserted. `importance` starts at `1.0` and is decayed
/// over time by the proactive engine. `embeddingKey` is the foreign key into
/// the vector store that holds this entry's embedding.
///
/// Per project rules, all access happens on the main actor via the shared
/// `ModelContainer`'s `mainContext`.
@Model
final class MemoryEntry {
    /// Stable identifier, also used as the link target in `relatedIDs`.
    @Attribute(.unique) var id: UUID

    /// When the memory was created.
    var timestamp: Date

    /// Retention tier this memory belongs to.
    var tier: MemoryTier

    /// Raw text of the memory.
    var content: String

    /// Relevance weight. Starts at `1.0` and decays over time.
    var importance: Float

    /// Extracted names, places, and projects. Populated before insertion.
    var entities: [String]

    /// `id`s of other `MemoryEntry` records linked to this one.
    var relatedIDs: [UUID]

    /// Foreign key into the vector store holding this entry's embedding.
    var embeddingKey: String

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        tier: MemoryTier,
        content: String,
        importance: Float = 1.0,
        entities: [String] = [],
        relatedIDs: [UUID] = [],
        embeddingKey: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tier = tier
        self.content = content
        self.importance = importance
        self.entities = entities
        self.relatedIDs = relatedIDs
        self.embeddingKey = embeddingKey
    }
}
