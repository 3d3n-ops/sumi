//
//  ContactsTool.swift
//  sumi-ios
//
//  Read-only contact lookup, combined with memory for relationship context.
//  Never prompts for permission; returns empty/nil when access isn't granted.
//

import Foundation
import Contacts

/// Contact lookup and memory-enriched relationship context.
actor ContactsTool: SumiTool {
    let toolID = "contacts"
    let description = "Looks up a person in the user's contacts and combines that with what Sumi remembers about them."

    private let store: CNContactStore

    /// Keys fetched for any contact read.
    private static let keys: [CNKeyDescriptor] = [
        CNContactGivenNameKey, CNContactFamilyNameKey,
        CNContactEmailAddressesKey, CNContactPhoneNumbersKey,
    ] as [CNKeyDescriptor]

    init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    private var isAuthorized: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    /// First contact matching `name`, or `nil`.
    func lookup(name: String) async -> CNContact? {
        guard isAuthorized, !name.isEmpty else { return nil }
        let predicate = CNContact.predicateForContacts(matchingName: name)
        return (try? store.unifiedContacts(matching: predicate, keysToFetch: Self.keys))?.first
    }

    /// Up to `limit` contacts. Contacts has no public "recents" API, so this
    /// returns the first `limit` unified contacts encountered.
    func recentContacts(limit: Int) async -> [CNContact] {
        guard isAuthorized, limit > 0 else { return [] }
        var out: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: Self.keys)
        try? store.enumerateContacts(with: request) { contact, stop in
            out.append(contact)
            if out.count >= limit { stop.pointee = true }
        }
        return out
    }

    /// A spoken-quality blurb combining the contact's name with remembered context.
    func contactContext(contact: CNContact, memory: MemoryStore) async -> String {
        let name = CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return await Self.composeContext(name: name, memory: memory)
    }

    /// Pure composition: search memory for `name` and phrase what's known.
    static func composeContext(name: String, memory: MemoryStore) async -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "I don't have a name for that contact." }

        let results = (try? await memory.search(trimmed, topK: 3)) ?? []
        let snippets = await MainActor.run { results.map(\.content) }
        guard !snippets.isEmpty else { return "I don't have any notes about \(trimmed) yet." }
        return "Here's what I remember about \(trimmed): " + snippets.joined(separator: " ")
    }
}
