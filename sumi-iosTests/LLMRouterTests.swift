//
//  LLMRouterTests.swift
//  sumi-iosTests
//
//  Pure routing-decision tests — no network, no on-device model.
//

import Foundation
import Testing
@testable import sumi_ios

struct LLMRouterTests {

    private func makeRouter() -> LLMRouter {
        LLMRouter(
            onDevice: StubOnDeviceModel(),
            worker: CloudflareWorkerClient(
                transport: FakeWorkerTransport(),
                urlProvider: FakeWorkerURLProvider(url: "https://example.invalid")
            )
        )
    }

    @Test func imageAlwaysRoutesToVision() {
        let router = makeRouter()
        // Even with low complexity, an image forces the vision path.
        #expect(router.route(query: "what's this", hasImage: true, complexity: 0.1) == .cloudVision)
        #expect(router.route(query: "explain in detail", hasImage: true, complexity: 0.9) == .cloudVision)
    }

    @Test func lowComplexityRoutesOnDevice() {
        let router = makeRouter()
        #expect(router.route(query: "remind me", hasImage: false, complexity: 0.0) == .onDevice)
        #expect(router.route(query: "what's my name", hasImage: false, complexity: 0.39) == .onDevice)
    }

    @Test func highComplexityRoutesSonnet() {
        let router = makeRouter()
        #expect(router.route(query: "draft a plan", hasImage: false, complexity: 0.4) == .cloudSonnet)
        #expect(router.route(query: "deep analysis", hasImage: false, complexity: 0.95) == .cloudSonnet)
    }

    @Test func complexityHeuristicIsBounded() {
        let value = LLMRouter.estimateComplexity(
            query: String(repeating: "word ", count: 200),
            contextCount: 99
        )
        #expect(value <= 1.0)
        #expect(value >= 0.0)
    }

    @Test func assembledMessagesIncludeMemoryContext() {
        let messages = LLMRouter.assembleMessages(
            query: "what did Sarah say",
            context: ["Sarah prefers mornings"]
        )
        #expect(messages.contains { $0["content"]?.contains("Sarah prefers mornings") == true })
        #expect(messages.last?["role"] == "user")
    }
}

/// In-memory transport that returns a canned `{ "text": ... }` body — never touches the network.
struct FakeWorkerTransport: WorkerTransport {
    var reply: String = "ok"
    var status: Int = 200

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let body = try JSONSerialization.data(withJSONObject: ["text": reply])
        return (body, status)
    }
}

/// Supplies a fixed Worker URL without touching the Keychain.
struct FakeWorkerURLProvider: WorkerURLProviding {
    var url: String?
    func workerURL() -> String? { url }
}
