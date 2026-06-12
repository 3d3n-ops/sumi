//
//  BudgetExceededError.swift
//  sumi-ios
//
//  Thrown when a BGTask exceeds its internal time budget.
//

import Foundation

/// Raised when background work runs past the hard internal budget (20s in
/// Sprint 2; the OS-level limit is 25s). Used by the timeout race so the work
/// task is cancelled and the BGTask completes deterministically.
struct BudgetExceededError: Error, Equatable {}
