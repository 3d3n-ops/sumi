//
//  VectorStore.swift
//  sumi-ios
//
//  sqlite-vec cosine search with BLOB fallback — off main actor.
//

import Foundation
import OSLog
import SQLite

/// Disk-backed vector index keyed by `MemoryEntry.id.uuidString`.
actor VectorStore {
    struct SearchResult: Sendable {
        let matches: [(key: String, score: Float)]
        /// Keys from `matches` that were not present in the caller's `validKeys` set.
        let orphanKeys: [String]
    }

    private(set) var isVecAvailable = false

    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "VectorStore")
    private let db: Connection
    private let dimension: Int
    private let vecTableName = "vec_memories"
    private let blobTableName = "vec_blobs"
    private let forceFallback: Bool

    /// - Parameters:
    ///   - databaseURL: Overrides the default App Group database path (tests).
    ///   - dimension: Embedding width; must match `EmbeddingService.dimension`.
    ///   - forceFallback: When `true`, skips sqlite-vec and uses the BLOB fallback path.
    init(
        databaseURL: URL? = nil,
        dimension: Int = EmbeddingService.dimension,
        forceFallback: Bool = false
    ) throws {
        self.dimension = dimension
        self.forceFallback = forceFallback

        let url = databaseURL ?? Self.defaultDatabaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        db = try Connection(url.path)
        try db.execute("PRAGMA journal_mode=WAL")

        try Self.ensureBlobTable(on: db, tableName: blobTableName)

        if forceFallback {
            isVecAvailable = false
            logger.warning("VectorStore forced into BLOB fallback mode (isVecAvailable = false)")
        } else {
            isVecAvailable = try Self.probeVecAvailability(on: db, dimension: dimension, logger: logger)
            if isVecAvailable {
                try Self.ensureVecTable(on: db, tableName: vecTableName, dimension: dimension)
            } else {
                logger.error(
                    """
                    sqlite-vec unavailable — vector search will use in-memory cosine \
                    similarity over vec_blobs. Load the vec0 extension to enable native search.
                    """
                )
            }
        }
    }

    func insert(key: String, vector: [Float]) async throws {
        guard vector.count == dimension else {
            throw VectorStoreError.invalidDimension(expected: dimension, actual: vector.count)
        }

        try insertBlob(key: key, vector: vector)

        if isVecAvailable {
            try insertVec(key: key, vector: vector)
        } else {
            do {
                try Self.ensureVecTable(on: db, tableName: vecTableName, dimension: dimension)
                try insertVec(key: key, vector: vector)
            } catch {
                logger.debug("vec0 insert skipped for key \(key, privacy: .public): \(error.localizedDescription)")
            }
        }
    }

    func search(
        query: [Float],
        topK: Int,
        validKeys: Set<String>? = nil
    ) async throws -> SearchResult {
        guard query.count == dimension else {
            throw VectorStoreError.invalidDimension(expected: dimension, actual: query.count)
        }
        guard topK > 0 else { return SearchResult(matches: [], orphanKeys: []) }

        let matches: [(key: String, score: Float)]
        if isVecAvailable {
            matches = try searchWithVec(query: query, topK: topK)
        } else {
            matches = try searchWithFallback(query: query, topK: topK)
        }

        let orphanKeys: [String]
        if let validKeys {
            orphanKeys = matches.map(\.key).filter { !validKeys.contains($0) }
        } else {
            orphanKeys = []
        }

        return SearchResult(matches: matches, orphanKeys: orphanKeys)
    }

    /// Keys present in the vector store but absent from `validKeys` (e.g. deleted `MemoryEntry` rows).
    func orphanKeys(notIn validKeys: Set<String>) async throws -> [String] {
        let keys = try allKeys()
        return keys.filter { !validKeys.contains($0) }
    }

    func contains(key: String) async throws -> Bool {
        let blob = Table(blobTableName)
        let keyExpr = Expression<String>("key")
        return try db.scalar(blob.filter(keyExpr == key).count) > 0
    }

    func delete(key: String) async throws {
        let blob = Table(blobTableName)
        try db.run(blob.filter(Expression<String>("key") == key).delete())

        if isVecAvailable {
            try db.run("DELETE FROM \(vecTableName) WHERE key = ?", key)
        }
    }

    func allKeys() throws -> [String] {
        let blob = Table(blobTableName)
        let keyExpr = Expression<String>("key")
        return try db.prepare(blob.select(keyExpr)).map { row in
            try row.get(keyExpr)
        }
    }

    func contains(key: String) throws -> Bool {
        let blob = Table(blobTableName)
        let keyExpr = Expression<String>("key")
        return try db.scalar(blob.filter(keyExpr == key).count) > 0
    }

    // MARK: - Database setup

    private static func defaultDatabaseURL() -> URL {
        if let container = AppGroup.containerURL {
            return container.appendingPathComponent("vectors.sqlite3")
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-vectors.sqlite3")
    }

    private static func ensureBlobTable(on db: Connection, tableName: String) throws {
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                key TEXT PRIMARY KEY NOT NULL,
                vector BLOB NOT NULL
            )
            """
        )
    }

    private static func ensureVecTable(on db: Connection, tableName: String, dimension: Int) throws {
        try db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS \(tableName) USING vec0(
                key TEXT PRIMARY KEY,
                embedding float[\(dimension)]
            )
            """
        )
    }

    private static func probeVecAvailability(
        on db: Connection,
        dimension: Int,
        logger: Logger
    ) throws -> Bool {
        let canary = "vec_canary_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        do {
            try db.execute(
                """
                CREATE VIRTUAL TABLE \(canary) USING vec0(
                    embedding float[\(dimension)]
                )
                """
            )
            try db.execute("DROP TABLE \(canary)")
            return true
        } catch {
            logger.error("sqlite-vec canary vec0 table creation failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Writes

    private func insertBlob(key: String, vector: [Float]) throws {
        let blob = Table(blobTableName)
        let keyExpr = Expression<String>("key")
        let vectorExpr = Expression<Data>("vector")
        let payload = VectorCodec.encode(vector)

        if try db.scalar(blob.filter(keyExpr == key).count) > 0 {
            try db.run(blob.filter(keyExpr == key).update(vectorExpr <- payload))
        } else {
            try db.run(blob.insert(keyExpr <- key, vectorExpr <- payload))
        }
    }

    private func insertVec(key: String, vector: [Float]) throws {
        let json = "[" + vector.map { String($0) }.joined(separator: ", ") + "]"
        try db.run(
            "INSERT OR REPLACE INTO \(vecTableName)(key, embedding) VALUES (?, ?)",
            key,
            json
        )
    }

    // MARK: - Search

    private func searchWithVec(query: [Float], topK: Int) throws -> [(key: String, score: Float)] {
        let json = "[" + query.map { String($0) }.joined(separator: ", ") + "]"
        var results: [(key: String, score: Float)] = []
        for row in try db.prepare(
            """
            SELECT key, distance
            FROM \(vecTableName)
            WHERE embedding MATCH ?
            ORDER BY distance
            LIMIT ?
            """,
            json,
            topK
        ) {
            let key = row[0] as? String ?? ""
            let distance = (row[1] as? Double).map(Float.init) ?? (row[1] as? Float) ?? 0
            let score = max(0, 1 - distance)
            results.append((key: key, score: score))
        }
        return results
    }

    private func searchWithFallback(query: [Float], topK: Int) throws -> [(key: String, score: Float)] {
        let blob = Table(blobTableName)
        let keyExpr = Expression<String>("key")
        let vectorExpr = Expression<Data>("vector")

        var scored: [(key: String, score: Float)] = []
        for row in try db.prepare(blob.select(keyExpr, vectorExpr)) {
            let key = try row.get(keyExpr)
            let data = try row.get(vectorExpr)
            guard let stored = VectorCodec.decode(data, dimension: dimension) else { continue }
            let score = Self.cosineSimilarity(query, stored)
            scored.append((key: key, score: score))
        }

        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(topK))
    }

    private static func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dot: Float = 0
        var normLHS: Float = 0
        var normRHS: Float = 0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            normLHS += lhs[index] * lhs[index]
            normRHS += rhs[index] * rhs[index]
        }

        let denominator = sqrt(normLHS) * sqrt(normRHS)
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }
}

enum VectorStoreError: Error, Equatable {
    case invalidDimension(expected: Int, actual: Int)
}
