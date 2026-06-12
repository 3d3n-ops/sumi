//
//  SumiAction.swift
//  sumi-ios
//
//  The action a proactive surface offers as its primary tap target.
//

import Foundation

/// A user-facing action attached to a proactive surface's primary button.
///
/// Conforms to `Equatable`/`Sendable` so surfaces can be compared in tests and
/// passed across actor boundaries.
enum SumiAction: Equatable, Sendable {
    /// Open the system Reminders app.
    case openReminders
    /// Start composing a message to a recipient (phone/email/handle).
    case composeMessage(to: String)
    /// Open the system Calendar app.
    case openCalendar
    /// Add a note with the given content.
    case addNote(content: String)
    /// Dismiss the surface with no further action.
    case dismiss
}
