//
//  Keychain.swift
//  sumi-ios
//
//  Minimal wrapper over the Security framework. Used to read/write the
//  Cloudflare Worker URL — per the hard rules, secrets and endpoints live in
//  the Keychain only, never in code or UserDefaults.
//

import Foundation
import Security

/// Thin, dependency-free Keychain accessor for generic-password items.
///
/// Stores small `String` values keyed by account name. All values are scoped to
/// this app's default access group. Reads return `nil` when the key is absent so
/// callers can degrade gracefully (e.g. throw `SumiError.noWorkerURL`).
enum Keychain {
    /// Account key for the Cloudflare Worker base URL.
    static let workerURLKey = "sumi.worker.url"

    /// Reads a string value for `key`, or `nil` if it is not present.
    static func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// Stores (or replaces) a string value for `key`. Returns `true` on success.
    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        // Replace any existing item so callers don't have to branch on insert/update.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Removes the value for `key`. No-op if it is absent.
    @discardableResult
    static func remove(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
