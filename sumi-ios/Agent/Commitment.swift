//
//  Commitment.swift
//  sumi-ios
//
//  A thing the user said they would do, mined from their own words. Commitments
//  are extracted by `CommitmentExtractor` and persisted by `MemoryStore` as
//  `.context`-tier memories so the proactive layer can follow up on them.
//

import Foundation

/// A single tracked commitment.
///
/// This is a value type: the durable record lives as a tagged `MemoryEntry`.
/// `Commitment` is the in-memory shape produced by extraction and reconstructed
/// from storage when the proactive layer needs to reason about open promises.
struct Commitment: Sendable, Codable, Identifiable, Equatable {
    /// Stable identifier, shared with the backing `MemoryEntry`.
    var id: UUID
    /// Imperative summary of the promise, e.g. "send Sarah the deck".
    var text: String
    /// The source text the commitment was extracted from (context for follow-up).
    var extractedFrom: String
    /// When the commitment was made/first seen.
    var createdAt: Date
    /// The person the commitment involves, if one was named.
    var targetPerson: String?
    /// A due date if the user hinted at one.
    var dueHint: Date?
    /// Whether the commitment has been satisfied.
    var isResolved: Bool

    init(
        id: UUID = UUID(),
        text: String,
        extractedFrom: String = "",
        createdAt: Date = .now,
        targetPerson: String? = nil,
        dueHint: Date? = nil,
        isResolved: Bool = false
    ) {
        self.id = id
        self.text = text
        self.extractedFrom = extractedFrom
        self.createdAt = createdAt
        self.targetPerson = targetPerson
        self.dueHint = dueHint
        self.isResolved = isResolved
    }
}
