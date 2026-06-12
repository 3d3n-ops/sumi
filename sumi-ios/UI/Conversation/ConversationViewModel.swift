//
//  ConversationViewModel.swift
//  sumi-ios
//
//  Drives the in-app chat surface: holds the transcript, sends a turn through
//  the LLMRouter (enriched with memory + recent context), and writes each turn
//  back to memory. Main-actor isolated — it owns UI state.
//

import Foundation
import Observation

@MainActor
@Observable
final class ConversationViewModel {
    /// The visible transcript.
    var messages: [ChatMessage] = []
    /// Bound to the text field.
    var input: String = ""
    /// True while awaiting a reply (drives the typing indicator + disables send).
    private(set) var isResponding = false

    private let memory: MemoryStore
    private let router: LLMRouter

    init(
        memory: MemoryStore = SumiEnvironment.shared.memory,
        router: LLMRouter = SumiEnvironment.shared.router
    ) {
        self.memory = memory
        self.router = router
    }

    /// Sends the current `input` (no-op if empty or already responding).
    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }
        input = ""
        submit(text)
    }

    /// Sends arbitrary text (used by the voice path too).
    func submit(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }
        messages.append(ChatMessage(role: .user, text: text))
        isResponding = true
        Task { await respond(to: text) }
    }

    private func respond(to text: String) async {
        // Memory context for this turn (we're on the main actor, so reading
        // MemoryEntry.content is safe).
        let memories = (try? await memory.search(text, topK: 5)) ?? []
        let memoryContext = memories.map(\.content)

        // Recent transcript for conversational continuity.
        let recent = messages.suffix(6).map { msg in
            "\(msg.role == .user ? "User" : "Sumi"): \(msg.text)"
        }

        let reply = await router.converse(query: text, context: memoryContext + recent)
        messages.append(ChatMessage(role: .sumi, text: reply))
        isResponding = false

        await MemoryWriteback.record(intent: "conversation", query: text, response: reply, memory: memory)
    }
}
