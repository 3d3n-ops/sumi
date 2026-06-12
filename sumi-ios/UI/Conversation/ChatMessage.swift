//
//  ChatMessage.swift
//  sumi-ios
//
//  One turn in the in-app conversation surface.
//

import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        case user
        case sumi
    }

    let id = UUID()
    let role: Role
    var text: String
    let timestamp: Date

    init(role: Role, text: String, timestamp: Date = .now) {
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
