//
//  SearchMemoryIntent.swift
//  sumi-ios
//
//  "Ask Sumi what I said about X" — recalls memory context and speaks a synthesis.
//

import AppIntents
import Foundation

struct SearchMemoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Recall from Sumi"
    static let description = IntentDescription("Ask Sumi what you said or what it remembers about something.")
    static let openAppWhenRun = false

    @Parameter(title: "What to look for")
    var query: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let env = SumiEnvironment.shared
        let results = (try? await env.memory.search(query, topK: 5)) ?? []

        let spoken: String
        if results.isEmpty {
            spoken = "I don't have anything on that yet."
        } else {
            let contextStrings = await MainActor.run { results.map(\.content) }
            let raw = await env.router.respond(query: query, contextStrings: contextStrings)
            spoken = IntentResponseBuilder.spoken(raw)
        }

        await MemoryWriteback.record(intent: "memory search", query: query, response: spoken, memory: env.memory)
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }
}
