//
//  SuppressedTriggers.swift
//  sumi-ios
//
//  Tracks dismissals per trigger so a twice-dismissed trigger goes quiet for a week.
//

import Foundation

/// Per-trigger dismissal bookkeeping backed by UserDefaults.
///
/// Rule (from CLAUDE.md): a trigger dismissed twice within 7 days is suppressed
/// for 7 days. The backing `UserDefaults` suite is injectable so tests run
/// against an isolated, ephemeral store.
struct SuppressedTriggers {
    /// Number of dismissals within the window that triggers suppression.
    static let suppressionThreshold = 2
    /// Sliding window length for counting dismissals.
    static let window: TimeInterval = 7 * 24 * 60 * 60

    private let defaults: UserDefaults
    private let keyPrefix = "sumi.suppress."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Records a dismissal of `triggerID` at `date` (default now).
    func recordDismissal(_ triggerID: String, at date: Date = .now) {
        var timestamps = dismissalTimestamps(triggerID)
        timestamps.append(date.timeIntervalSince1970)
        // Keep only the in-window timestamps so the store doesn't grow unbounded.
        let cutoff = date.addingTimeInterval(-Self.window).timeIntervalSince1970
        timestamps = timestamps.filter { $0 >= cutoff }
        defaults.set(timestamps, forKey: key(triggerID))
    }

    /// Whether `triggerID` is currently suppressed (>= threshold dismissals in window).
    func isSuppressed(_ triggerID: String, at date: Date = .now) -> Bool {
        let cutoff = date.addingTimeInterval(-Self.window).timeIntervalSince1970
        let recent = dismissalTimestamps(triggerID).filter { $0 >= cutoff }
        return recent.count >= Self.suppressionThreshold
    }

    /// Clears all dismissal history for `triggerID`.
    func reset(_ triggerID: String) {
        defaults.removeObject(forKey: key(triggerID))
    }

    // MARK: - Internal

    private func key(_ triggerID: String) -> String { keyPrefix + triggerID }

    private func dismissalTimestamps(_ triggerID: String) -> [TimeInterval] {
        defaults.array(forKey: key(triggerID)) as? [TimeInterval] ?? []
    }
}
