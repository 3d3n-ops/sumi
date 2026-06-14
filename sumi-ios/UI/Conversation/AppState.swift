//
//  AppState.swift
//  sumi-ios
//
//  Tiny shared UI state. Used so a one-press launch intent (Action Button /
//  Control Center / Lock Screen) can ask the conversation screen to open
//  straight into a listening session.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    /// Set by OpenConversationIntent; the conversation screen consumes it to
    /// auto-start the mic, then resets it.
    var pendingVoiceSession = false

    /// A query to submit as soon as the conversation screen appears — used by the
    /// onboarding "first moment" so a chosen starter carries straight into chat.
    var pendingQuery: String?

    private init() {}
}
