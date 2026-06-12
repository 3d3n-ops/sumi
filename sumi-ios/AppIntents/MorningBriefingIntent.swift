//
//  MorningBriefingIntent.swift
//  sumi-ios
//
//  "Ask Sumi what's my day" — runs the morning brief trigger and speaks it.
//

import AppIntents
import Contacts
import EventKit
import Foundation

struct MorningBriefingIntent: AppIntent {
    static let title: LocalizedStringResource = "Morning Briefing"
    static let description = IntentDescription("Get a quick spoken summary of your day.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let env = SumiEnvironment.shared
        let trigger = MorningBriefTrigger(router: env.router)
        let surface = await trigger.evaluate(
            memory: env.memory,
            calendar: EKEventStore(),
            contacts: CNContactStore()
        )

        let message = surface?.message ?? "Nothing urgent today — your schedule looks clear."
        let spoken = IntentResponseBuilder.spoken(message)

        await MemoryWriteback.record(intent: "morning briefing", query: "what's my day", response: spoken, memory: env.memory)
        return .result(dialog: IntentDialog(stringLiteral: spoken))
    }
}
