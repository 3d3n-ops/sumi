//
//  TimeBudget.swift
//  sumi-ios
//
//  Hard internal timeout for background work, implemented as a TaskGroup race.
//

import Foundation

/// Runs `work` against a hard deadline. If `work` finishes first its result is
/// returned; if the deadline wins, the work task is cancelled and
/// `BudgetExceededError` is thrown.
///
/// This is the core of the BGTask budget guard. It is pure (no BGTaskScheduler
/// dependency) so it can be unit-tested directly.
///
/// - Parameters:
///   - seconds: budget in seconds (Sprint 2 uses 20s; OS limit is 25s).
///   - work: the cancellable async work to run.
func withTimeBudget<T: Sendable>(
    seconds: Double,
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Task A — the actual work.
        group.addTask { try await work() }
        // Task B — the deadline. Sleeps, then throws if it isn't cancelled first.
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw BudgetExceededError()
        }

        do {
            // First task to finish wins; cancel the loser.
            let result = try await group.next()!
            group.cancelAll()
            return result
        } catch {
            group.cancelAll()
            throw error
        }
    }
}
