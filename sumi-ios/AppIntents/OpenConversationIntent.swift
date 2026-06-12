//
//  OpenConversationIntent.swift
//  sumi-ios
//
//  One-press launch into Sumi's conversation, already listening. Assignable to
//  the Action Button, Control Center, the Lock Screen, or invoked via Siri —
//  the closest thing to "talk to Sumi directly" iOS allows (there is no custom
//  wake word for third-party apps).
//

import AppIntents

struct OpenConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Talk to Sumi"
    static let description = IntentDescription("Open Sumi and start talking.")

    /// Foreground the app so the user can speak/type immediately.
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppState.shared.pendingVoiceSession = true
        }
        return .result()
    }
}
