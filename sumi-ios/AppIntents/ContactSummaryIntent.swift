//
//  ContactSummaryIntent.swift
//  sumi-ios
//
//  "Ask Sumi about my history with Alex" — combines contact data, memory, and
//  upcoming events into a spoken relationship summary.
//

import AppIntents
import Contacts
import EventKit
import Foundation

struct ContactSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "History with a person"
    static let description = IntentDescription("Ask Sumi about your history and upcoming plans with someone.")
    static let openAppWhenRun = false

    @Parameter(title: "Person")
    var personName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let env = SumiEnvironment.shared

        let memories = (try? await env.memory.search(personName, topK: 5)) ?? []
        let memorySnippets = await MainActor.run { memories.map(\.content) }

        var context = memorySnippets
        if let contactNote = await Self.contactNote(for: personName) {
            context.append(contactNote)
        }
        if let eventNote = Self.upcomingEventsNote(for: personName) {
            context.append(eventNote)
        }

        let spoken: String
        if context.isEmpty {
            spoken = "I don't have anything about \(personName) yet."
        } else {
            let raw = await env.router.respond(
                query: "Summarize who \(personName) is to me, our recent history, and anything coming up.",
                contextStrings: context
            )
            spoken = IntentResponseBuilder.spoken(raw)
        }

        await MemoryWriteback.record(intent: "contact summary", query: personName, response: spoken, memory: env.memory)
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }

    // MARK: - Best-effort context (both degrade silently without permission)

    private static func contactNote(for name: String) async -> String? {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else { return nil }

        let predicate = CNContact.predicateForContacts(matchingName: name)
        let keys = [
            CNContactGivenNameKey, CNContactFamilyNameKey,
            CNContactOrganizationNameKey, CNContactJobTitleKey,
        ] as [CNKeyDescriptor]
        guard let contacts = try? store.unifiedContacts(matching: predicate, keysToFetch: keys),
              let contact = contacts.first else { return nil }

        var parts = ["\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)]
        if !contact.organizationName.isEmpty { parts.append("works at \(contact.organizationName)") }
        if !contact.jobTitle.isEmpty { parts.append("as a \(contact.jobTitle)") }
        return parts.joined(separator: " ")
    }

    private static func upcomingEventsNote(for name: String) -> String? {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }

        let now = Date()
        guard let end = Calendar.current.date(byAdding: .day, value: 14, to: now) else { return nil }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let lower = name.lowercased()
        let matching = store.events(matching: predicate).filter { event in
            (event.title?.lowercased().contains(lower) ?? false)
                || (event.attendees?.contains { ($0.name?.lowercased().contains(lower)) ?? false } ?? false)
        }
        guard !matching.isEmpty else { return nil }
        let titles = matching.prefix(3).compactMap(\.title).joined(separator: ", ")
        return "Upcoming events involving them: \(titles)."
    }
}
