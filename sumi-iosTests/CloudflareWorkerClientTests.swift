//
//  CloudflareWorkerClientTests.swift
//  sumi-iosTests
//
//  Worker client behavior with an injected fake transport — never hits the network.
//

import Foundation
import Testing
@testable import sumi_ios

struct CloudflareWorkerClientTests {

    @Test func missingWorkerURLThrowsNoWorkerURL() async {
        let client = CloudflareWorkerClient(
            transport: FakeWorkerTransport(),
            urlProvider: FakeWorkerURLProvider(url: nil)
        )
        await #expect(throws: SumiError.noWorkerURL) {
            _ = try await client.completions(messages: [["role": "user", "content": "hi"]], model: "m")
        }
    }

    @Test func completionsReturnsWorkerText() async throws {
        let client = CloudflareWorkerClient(
            transport: FakeWorkerTransport(reply: "spoken reply"),
            urlProvider: FakeWorkerURLProvider(url: "https://worker.example")
        )
        let text = try await client.completions(
            messages: [["role": "user", "content": "hi"]],
            model: LLMRouter.sonnetModel
        )
        #expect(text == "spoken reply")
    }

    @Test func non2xxThrowsHTTPStatus() async {
        let client = CloudflareWorkerClient(
            transport: FakeWorkerTransport(reply: "nope", status: 500),
            urlProvider: FakeWorkerURLProvider(url: "https://worker.example")
        )
        await #expect(throws: SumiError.workerHTTPStatus(500)) {
            _ = try await client.vision(imageBase64: "AA==", prompt: "what is this")
        }
    }
}
