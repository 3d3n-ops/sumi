//
//  BackgroundTasks.swift
//  sumi-ios
//
//  BGTask registration, scheduling, and handlers for the proactive engine and
//  the nightly maintenance pass.
//
//  NOTE: BGTaskScheduler cannot be exercised in CI (no background runtime on the
//  simulator). This file is written to compile cleanly; the pure timeout logic it
//  relies on lives in TimeBudget.swift and is unit-tested separately.
//

import Foundation
import BackgroundTasks
import OSLog

/// Background task identifiers. Must match `BGTaskSchedulerPermittedIdentifiers`
/// in Info.plist.
enum BackgroundTaskID {
    /// BGAppRefreshTask — evaluates proactive triggers.
    static let proactive = "com.sumi.proactive"
    /// BGProcessingTask — nightly memory maintenance / decay.
    static let maintenance = "com.sumi.maintenance"
}

/// Owns BGTask registration, scheduling, and handler execution.
///
/// `proactiveWork` is injectable so the engine can be wired in later (Sprint 2.3b)
/// and so the file stays decoupled from the BGTaskScheduler singleton in tests.
@MainActor
final class BackgroundTaskCoordinator {
    static let shared = BackgroundTaskCoordinator()

    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "BackgroundTasks")

    /// Hard internal budget for the proactive task (OS allows 25s).
    private let proactiveBudget: Double = 20

    /// The work executed by the proactive task. Defaults to a logging placeholder;
    /// `configure(engine:)` replaces it with the real `ProactiveEngine.evaluate()`.
    var proactiveWork: @Sendable () async -> Void

    private init() {
        let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "BackgroundTasks")
        self.proactiveWork = {
            logger.info("task fired")
        }
    }

    /// Wires the real proactive engine into the BGTask handler. Call once the
    /// app has built its `MemoryStore` (e.g. on first foreground).
    func configure(engine: ProactiveEngine) {
        proactiveWork = {
            await engine.evaluate()
        }
    }

    /// Registers both BGTask handlers. Call once, early in launch.
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.proactive,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleProactive(task)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.maintenance,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleMaintenance(task)
        }
    }

    // MARK: - Scheduling

    /// Schedules the next proactive refresh. Called on launch and after each run.
    func scheduleProactiveRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskID.proactive)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        submit(request)
    }

    /// Schedules the nightly maintenance pass (no power/network requirements).
    func scheduleMaintenance() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskID.maintenance)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        submit(request)
    }

    private func submit(_ request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to submit \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Handlers

    private func handleProactive(_ task: BGAppRefreshTask) {
        // Always reschedule first so a crash mid-task doesn't stop future runs.
        scheduleProactiveRefresh()

        let budget = proactiveBudget
        let work = proactiveWork

        let runner = Task { @MainActor in
            do {
                try await withTimeBudget(seconds: budget) {
                    await work()
                }
                task.setTaskCompleted(success: true)
            } catch {
                // BudgetExceededError or cancellation — complete as unsuccessful.
                self.logger.error("Proactive task ended early: \(error.localizedDescription, privacy: .public)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            runner.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func handleMaintenance(_ task: BGProcessingTask) {
        scheduleMaintenance()

        let runner = Task { @MainActor in
            self.logger.info("maintenance fired")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            runner.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
