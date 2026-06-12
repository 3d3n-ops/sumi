//
//  TimeBudgetTests.swift
//  sumi-iosTests
//
//  The BGTask timeout race — work-wins and budget-wins paths.
//

import Foundation
import Testing
@testable import sumi_ios

struct TimeBudgetTests {

    @Test func workCompletesBeforeBudget() async throws {
        // Fast work against a generous budget returns its value.
        let result = try await withTimeBudget(seconds: 5) {
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return 42
        }
        #expect(result == 42)
    }

    @Test func budgetExceededThrows() async {
        // Slow work against a tiny budget throws BudgetExceededError.
        await #expect(throws: BudgetExceededError.self) {
            _ = try await withTimeBudget(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                return 0
            }
        }
    }
}
