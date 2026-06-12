//
//  SuppressedTriggersTests.swift
//  sumi-iosTests
//
//  Suppression bookkeeping over an isolated, ephemeral UserDefaults suite.
//

import Foundation
import Testing
@testable import sumi_ios

struct SuppressedTriggersTests {

    /// Fresh, isolated suite per test so runs don't bleed into each other.
    private func makeDefaults() -> UserDefaults {
        let suite = "test.suppress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func notSuppressedByDefault() {
        let store = SuppressedTriggers(defaults: makeDefaults())
        #expect(store.isSuppressed("morning.brief") == false)
    }

    @Test func oneDismissalDoesNotSuppress() {
        let store = SuppressedTriggers(defaults: makeDefaults())
        store.recordDismissal("morning.brief")
        #expect(store.isSuppressed("morning.brief") == false)
    }

    @Test func twoDismissalsWithinWindowSuppresses() {
        let store = SuppressedTriggers(defaults: makeDefaults())
        store.recordDismissal("morning.brief")
        store.recordDismissal("morning.brief")
        #expect(store.isSuppressed("morning.brief"))
    }

    @Test func dismissalsOutsideWindowDoNotSuppress() {
        let store = SuppressedTriggers(defaults: makeDefaults())
        let old = Date().addingTimeInterval(-8 * 24 * 60 * 60)
        store.recordDismissal("morning.brief", at: old)
        store.recordDismissal("morning.brief", at: old)
        // Both are older than the 7-day window relative to now.
        #expect(store.isSuppressed("morning.brief", at: .now) == false)
    }

    @Test func suppressionIsPerTrigger() {
        let store = SuppressedTriggers(defaults: makeDefaults())
        store.recordDismissal("a")
        store.recordDismissal("a")
        #expect(store.isSuppressed("a"))
        #expect(store.isSuppressed("b") == false)
    }
}
