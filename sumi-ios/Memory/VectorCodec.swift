//
//  VectorCodec.swift
//  sumi-ios
//
//  Float vector ↔ Data for vec_blobs storage.
//

import Foundation

enum VectorCodec {
    static func encode(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    static func decode(_ data: Data, dimension: Int) -> [Float]? {
        guard data.count == dimension * MemoryLayout<Float>.size else { return nil }
        return data.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }
}
