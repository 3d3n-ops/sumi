//
//  MemoryWriteback.swift
//  sumi-ios
//
//  Every Siri interaction is itself a memory. This records the turn as an
//  episodic entry so Sumi can recall what was asked and answered. Called at the
//  end of every intent's perform().
//

import Foundation
import OSLog

enum MemoryWriteback {
    private static let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "MemoryWriteback")

    /// Records an interaction as an `.episodic` memory. Never throws — a failed
    /// writeback must not break the user-facing intent response.
    static func record(intent: String, query: String, response: String, memory: MemoryStore) async {
        let content = "Via \(intent), I was asked \"\(query)\" and answered \"\(response)\"."
        do {
            _ = try await memory.write(content, tier: .episodic)
        } catch {
            logger.error("Memory writeback failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
