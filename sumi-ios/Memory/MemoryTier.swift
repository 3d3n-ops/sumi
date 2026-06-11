//
//  MemoryTier.swift
//  sumi-ios
//
//  Memory layer — tier classification for stored memories.
//

import Foundation

/// The three retention tiers a `MemoryEntry` can belong to.
///
/// Stored as its `String` raw value in SwiftData. The `description`
/// is plain prose so it can be surfaced in spoken App Intent responses
/// without any markdown.
enum MemoryTier: String, Codable, CaseIterable {
    case identity
    case context
    case episodic

    var description: String {
        switch self {
        case .identity: "persistent facts about the user"
        case .context: "active 14-day window"
        case .episodic: "recent 48-hour interactions"
        }
    }
}
