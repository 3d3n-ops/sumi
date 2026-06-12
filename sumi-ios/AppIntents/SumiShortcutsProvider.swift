//
//  SumiShortcutsProvider.swift
//  sumi-ios
//
//  Registers every Sumi intent with Siri via natural, varied phrases. All
//  phrases route through Siri ("Hey Siri, ask Sumi ...") — Sumi has no in-app UI
//  to invoke them.
//

import AppIntents

struct SumiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MorningBriefingIntent(),
            phrases: [
                "Ask \(.applicationName) what's my day",
                "Ask \(.applicationName) for my briefing",
                "Ask \(.applicationName) what's on today",
            ],
            shortTitle: "Morning Briefing",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: SearchMemoryIntent(),
            phrases: [
                "Ask \(.applicationName) to recall something",
                "Ask \(.applicationName) what I told it",
            ],
            shortTitle: "Recall",
            systemImageName: "brain"
        )
        AppShortcut(
            intent: ContextualReminderIntent(),
            phrases: [
                "Ask \(.applicationName) to remind me",
            ],
            shortTitle: "Remind Me",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: ContactSummaryIntent(),
            phrases: [
                "Ask \(.applicationName) about my history with someone",
                "Ask \(.applicationName) about a person",
            ],
            shortTitle: "Person History",
            systemImageName: "person.crop.circle"
        )
    }
}
