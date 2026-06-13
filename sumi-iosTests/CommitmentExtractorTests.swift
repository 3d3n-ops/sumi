//
//  CommitmentExtractorTests.swift
//  sumi-iosTests
//
//  Commitment extraction parsing — no network, no on-device model.
//

import Foundation
import Testing
@testable import sumi_ios

/// Fake LLM that returns a canned raw response for the extractor to parse.
struct FakeCommitmentLLM: CommitmentExtracting {
    let response: String?
    func extractCommitmentsJSON(from text: String) async -> String? { response }
}

struct CommitmentExtractorTests {

    @Test func parsesMultipleCommitments() async throws {
        let json = """
        [
          {"text": "send Sarah the deck", "targetPerson": "Sarah", "dueHint": "2026-06-20T17:00:00Z"},
          {"text": "call the dentist", "targetPerson": null, "dueHint": null}
        ]
        """
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: json))
        let commitments = await extractor.extract(from: "I'll send Sarah the deck and I need to call the dentist.")

        #expect(commitments.count == 2)
        #expect(commitments[0].text == "send Sarah the deck")
        #expect(commitments[0].targetPerson == "Sarah")
        #expect(commitments[0].dueHint != nil)
        #expect(commitments[1].targetPerson == nil)
        #expect(commitments[1].dueHint == nil)
        #expect(commitments.allSatisfy { !$0.isResolved })
    }

    @Test func emptyArrayYieldsNoCommitments() async throws {
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: "[]"))
        let commitments = await extractor.extract(from: "What a nice day.")
        #expect(commitments.isEmpty)
    }

    @Test func nilResponseYieldsNoCommitments() async throws {
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: nil))
        let commitments = await extractor.extract(from: "anything")
        #expect(commitments.isEmpty)
    }

    @Test func extractsArrayWrappedInProse() async throws {
        // Models sometimes wrap JSON in chatter or code fences — we should still parse.
        let wrapped = """
        Sure! Here are the commitments:
        ```json
        [{"text": "renew the lease", "targetPerson": null, "dueHint": null}]
        ```
        """
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: wrapped))
        let commitments = await extractor.extract(from: "remind me to renew the lease")
        #expect(commitments.count == 1)
        #expect(commitments[0].text == "renew the lease")
    }

    @Test func malformedJSONYieldsNoCommitments() async throws {
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: "[ this is not json"))
        let commitments = await extractor.extract(from: "whatever")
        #expect(commitments.isEmpty)
    }

    @Test func dropsBlankTextEntries() async throws {
        let json = #"[{"text": "  ", "targetPerson": null, "dueHint": null}]"#
        let extractor = CommitmentExtractor(llm: FakeCommitmentLLM(response: json))
        let commitments = await extractor.extract(from: "noise")
        #expect(commitments.isEmpty)
    }
}
