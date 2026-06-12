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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            MemoryEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    configureProactive()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Builds the proactive engine and wires it into the BGTask handler, and
    /// pre-computes the morning brief cache for this foreground session.
    @MainActor
    private func configureProactive() {
        guard let vectorStore = try? VectorStore() else { return }
        let memory = MemoryStore(
            modelContainer: sharedModelContainer,
            vectorStore: vectorStore
        )
        let router = LLMRouter()
        let brief = MorningBriefTrigger(router: router)
        let engine = ProactiveEngine(memory: memory, triggers: [brief])
        BackgroundTaskCoordinator.shared.configure(engine: engine)

        // Pre-compute and cache the brief so a later background run can skip the LLM.
        Task {
            await brief.refreshCache(memory: memory, calendar: EKEventStore())
        }
    }
}
