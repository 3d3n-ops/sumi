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

    private init() {}
}
