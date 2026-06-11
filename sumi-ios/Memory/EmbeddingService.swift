//
//  EmbeddingService.swift
//  sumi-ios
//
//  NaturalLanguage sentence embeddings — off main actor.
//

import Foundation
import NaturalLanguage
import OSLog

/// Produces 512-dimensional sentence embeddings using on-device `NLEmbedding`.
actor EmbeddingService {
    static let dimension = 512

    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "EmbeddingService")
    private let embedding: NLEmbedding?
    private var cache: [String: [Float]] = [:]
    private var accessOrder: [String] = []
    private let maxCacheSize = 500

    init() {
        embedding = NLEmbedding.sentenceEmbedding(for: .english)
        if embedding == nil {
            logger.error("English sentence embedding unavailable — embed() will return nil")
        }
    }

    /// Returns a 512-dimensional embedding for `text`, or `nil` when the model cannot encode it.
    func embed(_ text: String) async -> [Float]? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let cached = cache[normalized] {
            touchCache(normalized)
            return cached
        }

        guard let embedding else { return nil }

        guard let vector = embedding.vector(for: normalized) else {
            return nil
        }

        guard vector.count == Self.dimension else {
            logger.error("Unexpected embedding dimension \(vector.count), expected \(Self.dimension)")
            return nil
        }

        let floats = vector.map(Float.init)
        storeInCache(normalized, vector: floats)
        return floats
    }

    private func touchCache(_ key: String) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }

    private func storeInCache(_ key: String, vector: [Float]) {
        if cache[key] != nil {
            touchCache(key)
            cache[key] = vector
            return
        }

        if cache.count >= maxCacheSize, let evicted = accessOrder.first {
            accessOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }

        cache[key] = vector
        accessOrder.append(key)
    }
}
