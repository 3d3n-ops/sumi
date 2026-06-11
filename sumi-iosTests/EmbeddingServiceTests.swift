//
//  EmbeddingServiceTests.swift
//  sumi-iosTests
//
//  On-device embedding shape and cache behavior.
//

import Foundation
import Testing
@testable import sumi_ios

struct EmbeddingServiceTests {

    @Test func embedReturns512Dimensions() async {
        let service = EmbeddingService()
        let vector = await service.embed("Sumi remembers interactions about calendar meetings")

        if await service.isAvailable {
            #expect(vector?.count == EmbeddingService.dimension)
        } else {
            // No on-device model on this runner — contract is a graceful nil.
            #expect(vector == nil)
        }
    }

    @Test func embedCachesRepeatedStrings() async {
        let service = EmbeddingService()
        let text = "Cache probe \(UUID().uuidString)"

        let first = await service.embed(text)
        let second = await service.embed(text)

        #expect(first == second)
        if await service.isAvailable {
            #expect(first != nil)
        }
    }

    @Test func emptyStringReturnsNil() async {
        let service = EmbeddingService()
        #expect(await service.embed("   ") == nil)
    }
}
