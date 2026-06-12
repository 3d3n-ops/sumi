//
//  ContextualReminderIntent.swift
//  sumi-ios
//
//  "Ask Sumi to remind me about X" — creates a Reminder enriched with the
//  context Sumi already remembers about the topic.
//

import AppIntents
import EventKit
import Foundation

struct ContextualReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Remind me with context"
    static let description = IntentDescription("Create a reminder, enriched with what Sumi remembers about it.")
    static let openAppWhenRun = false

    @Parameter(title: "What to be reminded about")
    var topic: String

    @Parameter(title: "When")
    var when: Date?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let env = SumiEnvironment.shared

        // Enrich the reminder with recent context for this topic.
        let results = (try? await env.memory.search(topic, topK: 3)) ?? []
        let contextSnippet = await MainActor.run {
            results.map(\.content).joined(separator: " ")
        }

        let store = EKEventStore()
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        guard granted else {
            return .result(dialog: IntentDialog(stringLiteral: "I need access to Reminders to do that."))
        }
        guard let list = store.defaultCalendarForNewReminders() else {
            return .result(dialog: IntentDialog(stringLiteral: "You don't have a default Reminders list set up."))
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = topic
        reminder.calendar = list
        if !contextSnippet.isEmpty {
            reminder.notes = contextSnippet
        }
        if let when {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: when
            )
            reminder.addAlarm(EKAlarm(absoluteDate: when))
        }

        let spoken: String
        do {
            try store.save(reminder, commit: true)
            spoken = "Done. I'll remind you about \(topic)\(Self.whenPhrase(when))."
        } catch {
            spoken = "I couldn't save that reminder just now."
        }

        await MemoryWriteback.record(intent: "reminder", query: topic, response: spoken, memory: env.memory)
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }

    private static func whenPhrase(_ when: Date?) -> String {
        guard let when else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return " on \(formatter.string(from: when))"
    }
}
