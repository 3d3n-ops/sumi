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

        let resolved = try? #require(vector)
        #expect(resolved?.count == EmbeddingService.dimension)
    }

    @Test func embedCachesRepeatedStrings() async {
        let service = EmbeddingService()
        let text = "Cache probe \(UUID().uuidString)"

        let first = await service.embed(text)
        let second = await service.embed(text)

        #expect(first != nil)
        #expect(first == second)
    }

    @Test func emptyStringReturnsNil() async {
        let service = EmbeddingService()
        #expect(await service.embed("   ") == nil)
    }
}
