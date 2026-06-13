//
//  RemindersTool.swift
//  sumi-ios
//
//  Read/write Reminders access. Never prompts for permission; degrades to
//  empty/no-op when access isn't granted.
//

import Foundation
import EventKit

/// Reads open reminders and creates/completes them.
actor RemindersTool: SumiTool {
    let toolID = "reminders"
    let description = "Reads the user's open reminders and creates or completes reminders."

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    private var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Incomplete reminders across all lists.
    func openReminders() async -> [EKReminder] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Creates a reminder on the default list. Returns `nil` if unauthorized or save fails.
    func create(title: String, notes: String?, due: Date?) async -> EKReminder? {
        guard isAuthorized, let list = store.defaultCalendarForNewReminders() else { return nil }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = list
        if let due {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due
            )
        }
        do {
            try store.save(reminder, commit: true)
            return reminder
        } catch {
            return nil
        }
    }

    /// Marks a reminder complete.
    func complete(reminder: EKReminder) async {
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
    }
}
