//
//  ProactiveEngineTests.swift
//  sumi-iosTests
//
//  Engine gating + selection with injected fakes — no notifications, no network,
//  no real permissions, deterministic clock.
//

import Foundation
import SwiftData
import EventKit
import Contacts
import UserNotifications
import Testing
@testable import sumi_ios

/// Captures fired notification requests instead of posting them.
final class SpyNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [UNNotificationRequest] = []
    var requests: [UNNotificationRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    func add(_ request: UNNotificationRequest) async throws {
        lock.lock(); _requests.append(request); lock.unlock()
    }
    func setCategories(_ categories: Set<UNNotificationCategory>) async {}
}

/// Trigger that returns a fixed surface (or nil) without touching real systems.
struct MockTrigger: ProactiveTrigger {
    let triggerID: String
    let surface: ProactiveSurface?

    func evaluate(memory: MemoryStore, calendar: EKEventStore, contacts: CNContactStore) async -> ProactiveSurface? {
        surface
    }
}

struct ProactiveEngineTests {

    private func makeMemory() throws -> MemoryStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MemoryEntry.self, configurations: config)
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-engine-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(modelContainer: container, embeddingService: DeterministicEmbedder(), vectorStore: vectorStore)
    }

    private func freshDefaults() -> UserDefaults {
        let suite = "test.engine.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private func surface(_ id: String, score: Float) -> ProactiveSurface {
        ProactiveSurface(
            message: "You have a meeting soon.",
            primaryActionTitle: "Open Calendar",
            primaryAction: .openCalendar,
            relevanceScore: score,
            expiresAt: Date().addingTimeInterval(3600),
            triggerID: id
        )
    }

    /// A daytime instant so quiet hours never gate the test.
    private func middayClock() -> @Sendable () -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 11; comps.hour = 10
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        return { date }
    }

    @Test func firesHighestScoringSurface() async throws {
        let spy = SpyNotificationScheduler()
        let engine = ProactiveEngine(
            memory: try makeMemory(),
            triggers: [
                MockTrigger(triggerID: "low", surface: surface("low", score: 0.85)),
                MockTrigger(triggerID: "high", surface: surface("high", score: 0.95)),
            ],
            composer: NotificationComposer(scheduler: spy),
            suppressed: SuppressedTriggers(defaults: freshDefaults()),
            dailyCounter: DailySurfaceCounter(defaults: freshDefaults()),
            now: middayClock()
        )

        await engine.evaluate()

        #expect(spy.requests.count == 1)
        #expect(spy.requests.first?.content.userInfo["triggerID"] as? String == "high")
    }

    @Test func belowThresholdDoesNotFire() async throws {
        let spy = SpyNotificationScheduler()
        let engine = ProactiveEngine(
            memory: try makeMemory(),
            triggers: [MockTrigger(triggerID: "weak", surface: surface("weak", score: 0.5))],
            composer: NotificationComposer(scheduler: spy),
            suppressed: SuppressedTriggers(defaults: freshDefaults()),
            dailyCounter: DailySurfaceCounter(defaults: freshDefaults()),
            now: middayClock()
        )

        await engine.evaluate()
        #expect(spy.requests.isEmpty)
    }

    @Test func quietHoursSuppressesEverything() async throws {
        let spy = SpyNotificationScheduler()
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 11; comps.hour = 23
        let night = Calendar(identifier: .gregorian).date(from: comps)!

        let engine = ProactiveEngine(
            memory: try makeMemory(),
            triggers: [MockTrigger(triggerID: "high", surface: surface("high", score: 0.99))],
            composer: NotificationComposer(scheduler: spy),
            suppressed: SuppressedTriggers(defaults: freshDefaults()),
            dailyCounter: DailySurfaceCounter(defaults: freshDefaults()),
            now: { night }
        )

        await engine.evaluate()
        #expect(spy.requests.isEmpty)
    }

    @Test func suppressedTriggerIsSkipped() async throws {
        let spy = SpyNotificationScheduler()
        let suppressDefaults = freshDefaults()
        let suppressed = SuppressedTriggers(defaults: suppressDefaults)
        suppressed.recordDismissal("high")
        suppressed.recordDismissal("high") // now suppressed

        let engine = ProactiveEngine(
            memory: try makeMemory(),
            triggers: [MockTrigger(triggerID: "high", surface: surface("high", score: 0.99))],
            composer: NotificationComposer(scheduler: spy),
            suppressed: suppressed,
            dailyCounter: DailySurfaceCounter(defaults: freshDefaults()),
            now: middayClock()
        )

        await engine.evaluate()
        #expect(spy.requests.isEmpty)
    }

    @Test func dailyCapBlocksFurtherSurfaces() async throws {
        let spy = SpyNotificationScheduler()
        let countDefaults = freshDefaults()
        let counter = DailySurfaceCounter(defaults: countDefaults)
        let clock = middayClock()
        counter.increment(on: clock())
        counter.increment(on: clock())
        counter.increment(on: clock()) // 3 = cap reached

        let engine = ProactiveEngine(
            memory: try makeMemory(),
            triggers: [MockTrigger(triggerID: "high", surface: surface("high", score: 0.99))],
            composer: NotificationComposer(scheduler: spy),
            suppressed: SuppressedTriggers(defaults: freshDefaults()),
            dailyCounter: counter,
            now: clock
        )

        await engine.evaluate()
        #expect(spy.requests.isEmpty)
    }
}
