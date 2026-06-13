//
//  SumiEnvironment.swift
//  sumi-ios
//
//  Process-wide Sumi services, shared by the app, App Intents, and BGTasks.
//
//  Built once per process against the App Group container so every entry point
//  — the app foreground, a Siri-invoked intent, or a background task — reads and
//  writes the same memory store and routes LLM calls the same way.
//

import Foundation
import OSLog
import SwiftData

/// Lazily-constructed shared services. All stored properties are `Sendable`
/// (`ModelContainer` is `Sendable`; `MemoryStore`/`LLMRouter` are actors), so the
/// environment can be reached from any isolation context without hopping actors.
final class SumiEnvironment: Sendable {
    static let shared = SumiEnvironment()

    /// SwiftData container, located in the App Group so the intent process and
    /// the app share one database.
    let modelContainer: ModelContainer
    /// The memory layer (write / search / decay).
    let memory: MemoryStore
    /// The single entry point for every LLM call.
    let router: LLMRouter

    private static let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "SumiEnvironment")

    private init() {
        let container = Self.makeModelContainer()
        let vectorStore = Self.makeVectorStore()
        let router = LLMRouter()
        self.modelContainer = container
        self.router = router
        self.memory = MemoryStore(
            modelContainer: container,
            vectorStore: vectorStore,
            commitmentExtractor: CommitmentExtractor(llm: router)
        )
    }

    // MARK: - Construction

    /// Builds the SwiftData container in the App Group container when available,
    /// falling back to the app's default location. Never returns optional — a
    /// missing store would make every intent useless.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([MemoryEntry.self])

        if let groupURL = AppGroup.containerURL?.appendingPathComponent("Sumi.store") {
            let config = ModelConfiguration(schema: schema, url: groupURL)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
            logger.error("App Group ModelContainer failed; falling back to default location.")
        }

        if let container = try? ModelContainer(for: schema) {
            return container
        }

        // Last resort: in-memory so the app still launches (data won't persist).
        logger.fault("Persistent ModelContainer unavailable; using in-memory store.")
        let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: inMemory)
    }

    /// Builds the vector store against the App Group container, then app support,
    /// then a unique temp file — the last of which effectively never fails.
    private static func makeVectorStore() -> VectorStore {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let bases = [AppGroup.containerURL, appSupport].compactMap { $0 }
        for base in bases {
            let url = base.appendingPathComponent("Sumi/vectors.sqlite3")
            if let store = try? VectorStore(databaseURL: url) {
                return store
            }
        }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-vectors-\(UUID().uuidString).sqlite3")
        // swiftlint:disable:next force_try
        return try! VectorStore(databaseURL: temp)
    }
}
