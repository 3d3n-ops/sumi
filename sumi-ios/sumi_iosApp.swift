//
//  sumi_iosApp.swift
//  sumi-ios
//
//  Created by olumami etuk on 6/10/26.
//

import SwiftUI
import SwiftData
import EventKit

@main
struct sumi_iosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Shared services (App Group store, memory, router) — the same instances
    /// Siri intents and background tasks use.
    private let environment = SumiEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    configureProactive()
                }
        }
        .modelContainer(environment.modelContainer)
    }

    /// Wires the proactive engine into the BGTask handler and pre-computes the
    /// morning brief cache for this foreground session.
    @MainActor
    private func configureProactive() {
        let memory = environment.memory
        let brief = MorningBriefTrigger(router: environment.router)
        let engine = ProactiveEngine(memory: memory, triggers: [brief, FollowUpTrigger()])
        BackgroundTaskCoordinator.shared.configure(engine: engine)

        // Pre-compute and cache the brief so a later background run can skip the LLM.
        Task {
            await brief.refreshCache(memory: memory, calendar: EKEventStore())
        }
    }
}
