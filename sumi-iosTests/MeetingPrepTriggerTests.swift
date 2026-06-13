//
//  MeetingPrepTriggerTests.swift
//  sumi-iosTests
//
//  Meeting-prep surface: fires ~30 min before a meeting with attendees, stays
//  quiet otherwise. Reuses FakeCalendarProvider; no EventKit permission.
//

import Foundation
import SwiftData
import EventKit
import Contacts
import Testing
@testable import sumi_ios

struct MeetingPrepTriggerTests {

    private let now: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15; comps.hour = 10
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private func makeMemory() throws -> MemoryStore {
        let container = try ModelContainer(
            for: MemoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sumi-meeting-\(UUID().uuidString).sqlite3")
        let vectorStore = try VectorStore(databaseURL: dbURL, forceFallback: true)
        return MemoryStore(modelContainer: container, embeddingService: DeterministicEmbedder(), vectorStore: vectorStore)
    }

    private func minutesFromNow(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }

    private func trigger(_ events: [BriefEvent]) -> MeetingPrepTrigger {
        MeetingPrepTrigger(calendarProvider: FakeCalendarProvider(events: events), now: { self.now })
    }

    @Test func firesForImminentMeetingWithAttendees() async throws {
        let t = trigger([
            BriefEvent(title: "Roadmap sync", hasAttendees: true, startDate: minutesFromNow(20), attendeeCount: 3),
        ])
        let surface = try #require(await t.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore()))
        #expect(surface.triggerID == "meeting.prep")
        #expect(surface.message == "3 people in your call in 20 min — want a quick brief?")
        #expect(surface.relevanceScore == 0.85)
    }

    @Test func picksSoonestMeeting() async throws {
        let t = trigger([
            BriefEvent(title: "Later", hasAttendees: true, startDate: minutesFromNow(28), attendeeCount: 5),
            BriefEvent(title: "Sooner", hasAttendees: true, startDate: minutesFromNow(10), attendeeCount: 2),
        ])
        let surface = try #require(await t.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore()))
        #expect(surface.message == "2 people in your call in 10 min — want a quick brief?")
    }

    @Test func quietWhenMeetingTooFarOut() async throws {
        let t = trigger([
            BriefEvent(title: "Afternoon", hasAttendees: true, startDate: minutesFromNow(120), attendeeCount: 4),
        ])
        let surface = await t.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }

    @Test func quietWhenNoAttendees() async throws {
        let t = trigger([
            BriefEvent(title: "Focus block", hasAttendees: false, startDate: minutesFromNow(15), attendeeCount: 0),
        ])
        let surface = await t.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }

    @Test func quietWhenMeetingAlreadyStarted() async throws {
        let t = trigger([
            BriefEvent(title: "Started", hasAttendees: true, startDate: minutesFromNow(-5), attendeeCount: 3),
        ])
        let surface = await t.evaluate(memory: try makeMemory(), calendar: EKEventStore(), contacts: CNContactStore())
        #expect(surface == nil)
    }
}
