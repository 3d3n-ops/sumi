//
//  MorningBriefTriggerTests.swift
//  sumi-iosTests
//
//  Brief synthesis, scoring, and cache-hit path — no EventKit permission, no network.
//

import Foundation
import SwiftData
import EventKit
import Contacts
import Testing
@testable import sumi_ios

/// Fake synthesizer that records how many times the LLM path was hit.
final class CountingBriefSynthesizer: BriefSynthesizing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var calls = 0
    let reply: String

    init(reply: String = "You have two meetings today.") { self.reply = reply }

    func synthesizeBrief(prompt: String) async -> String {
        lock.lock(); calls += 1; lock.unlock()
        return reply
    }
}

/// Fake calendar provider returning a fixed event list.
struct FakeCalendarProvider: CalendarEventsProviding {
    var events: [BriefEvent]
    func todaysEvents(at date: Date) async -> [BriefEvent] { events }
}

struct MorningBriefTriggerTests {

    private func makeMemory() throws -> MemoryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-brief-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(modelContainer: container, embeddingService: DeterministicEmbedder(), vectorStore: vectorStore)
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "test.brief.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func morning() -> @Sendable () -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 11; comps.hour = 7; comps.minute = 30
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        return { date }
    }

    @Test func eventsPresentScores095() async throws {
        let synth = CountingBriefSynthesizer()
        let trigger = MorningBriefTrigger(
            router: synth,
            defaults: freshDefaults(),
            calendarProvider: FakeCalendarProvider(events: [
                BriefEvent(title: "Standup", hasAttendees: true, startDate: morning()()),
            ]),
            now: morning()
        )

        let surface = await trigger.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        let s = try #require(surface)
        #expect(s.relevanceScore == 0.95)
        #expect(s.message == synth.reply)
        #expect(synth.calls == 1)
    }

    @Test func emptyDayScores060() async throws {
        let synth = CountingBriefSynthesizer(reply: "Your day looks open.")
        let trigger = MorningBriefTrigger(
            router: synth,
            defaults: freshDefaults(),
            calendarProvider: FakeCalendarProvider(events: []),
            now: morning()
        )

        let surface = await trigger.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        let s = try #require(surface)
        #expect(s.relevanceScore == 0.60)
    }

    @Test func freshCacheSkipsLLM() async throws {
        let defaults = freshDefaults()
        let synth = CountingBriefSynthesizer()
        let memory = try makeMemory()
        let trigger = MorningBriefTrigger(
            router: synth,
            defaults: defaults,
            calendarProvider: FakeCalendarProvider(events: [
                BriefEvent(title: "Standup", hasAttendees: true, startDate: morning()()),
            ]),
            now: morning()
        )

        // Foreground pre-compute populates the cache (1 LLM call).
        await trigger.refreshCache(memory: memory, calendar: EKEventStore())
        #expect(synth.calls == 1)

        // A subsequent evaluate within freshness must serve from cache (no new call).
        let surface = await trigger.evaluate(memory: memory, calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface != nil)
        #expect(synth.calls == 1)
        #expect(surface?.message == synth.reply)
    }

    @Test func staleCacheRecomputes() async throws {
        let defaults = freshDefaults()
        let synth = CountingBriefSynthesizer()

        // Seed a cache computed 3h ago (older than the 2h freshness window).
        let computedAt = morning()().addingTimeInterval(-3 * 60 * 60)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 11; comps.hour = 10
        let expires = Calendar(identifier: .gregorian).date(from: comps)!
        let stale = BriefCache(message: "old brief", computedAt: computedAt, expiresAt: expires)
        defaults.set(try JSONEncoder().encode(stale), forKey: MorningBriefTrigger.cacheKey)

        let trigger = MorningBriefTrigger(
            router: synth,
            defaults: defaults,
            calendarProvider: FakeCalendarProvider(events: [
                BriefEvent(title: "Standup", hasAttendees: false, startDate: morning()()),
            ]),
            now: morning()
        )

        let surface = await trigger.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        #expect(synth.calls == 1) // recomputed, not served from stale cache
        #expect(surface?.message == synth.reply)
    }
}
