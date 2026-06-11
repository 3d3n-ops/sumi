//
//  VectorStoreTests.swift
//  sumi-iosTests
//
//  Vector insert/search and BLOB fallback coverage.
//

import Foundation
import Testing
@testable import sumi_ios

struct VectorStoreTests {
    private let dimension = EmbeddingService.dimension

    @Test func insertTenAndSearchReturnsTopThree() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vector-store-\(UUID().uuidString).sqlite3")
        let store = try VectorStore(databaseURL: databaseURL, forceFallback: true)

        let query = unitVector(at: 0)
        let rankedKeys = (0..<10).map { index in
            "memory-\(index)"
        }

        for (index, key) in rankedKeys.enumerated() {
            let closeness = Float(10 - index) / 10
            let vector = blendedVector(primary: 0, secondary: 1, primaryWeight: closeness)
            try await store.insert(key: key, vector: vector)
        }

        let result = try await store.search(query: query, topK: 3)
        let topKeys = result.matches.map(\.key)

        #expect(topKeys.count == 3)
        #expect(topKeys[0] == "memory-0")
        #expect(topKeys[1] == "memory-1")
        #expect(topKeys[2] == "memory-2")
        #expect(result.matches[0].score >= result.matches[1].score)
        #expect(result.matches[1].score >= result.matches[2].score)
    }

    @Test func fallbackPathUsedWhenVecUnavailable() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vector-store-fallback-\(UUID().uuidString).sqlite3")
        let store = try VectorStore(databaseURL: databaseURL, forceFallback: true)

        #expect(await store.isVecAvailable == false)

        let alpha = unitVector(at: 0)
        let beta = unitVector(at: 1)
        try await store.insert(key: "alpha", vector: alpha)
        try await store.insert(key: "beta", vector: beta)

        let result = try await store.search(query: alpha, topK: 2)
        #expect(result.matches.first?.key == "alpha")
        #expect(result.matches.first?.score ?? 0 > 0.99)
    }

    @Test func searchReportsOrphanKeys() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vector-store-orphans-\(UUID().uuidString).sqlite3")
        let store = try VectorStore(databaseURL: databaseURL, forceFallback: true)

        let vector = unitVector(at: 0)
        try await store.insert(key: "present", vector: vector)
        try await store.insert(key: "missing", vector: blendedVector(primary: 0, secondary: 2, primaryWeight: 0.8))

        let result = try await store.search(
            query: vector,
            topK: 2,
            validKeys: ["present"]
        )

        #expect(result.orphanKeys.contains("missing"))
        #expect(!result.orphanKeys.contains("present"))
    }

    @Test func deleteRemovesBlobEntry() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vector-store-delete-\(UUID().uuidString).sqlite3")
        let store = try VectorStore(databaseURL: databaseURL, forceFallback: true)

        let vector = unitVector(at: 3)
        try await store.insert(key: "to-delete", vector: vector)
        try await store.delete(key: "to-delete")

        let result = try await store.search(query: vector, topK: 5)
        #expect(result.matches.isEmpty)
    }

    private func unitVector(at index: Int) -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        vector[index] = 1
        return vector
    }

    private func blendedVector(primary: Int, secondary: Int, primaryWeight: Float) -> [Float] {
        let secondaryWeight = 1 - primaryWeight
        var vector = [Float](repeating: 0, count: dimension)
        vector[primary] = primaryWeight
        vector[secondary] = secondaryWeight
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}
