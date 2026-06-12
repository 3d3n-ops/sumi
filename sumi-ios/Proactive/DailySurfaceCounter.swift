//
//  DailySurfaceCounter.swift
//  sumi-ios
//
//  Tracks how many proactive surfaces have fired today (resets at midnight).
//

import Foundation

/// UserDefaults-backed counter that resets when the calendar day changes.
///
/// The backing store and `Calendar` are injectable so tests are deterministic
/// regardless of wall-clock time.
struct DailySurfaceCounter {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let countKey = "sumi.surface.count"
    private let dayKey = "sumi.surface.day"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Number of surfaces fired on the day containing `date`.
    func count(on date: Date = .now) -> Int {
        let today = dayStamp(date)
        guard defaults.integer(forKey: dayKey) == today else { return 0 }
        return defaults.integer(forKey: countKey)
    }

    /// Records one fired surface for the day containing `date`.
    func increment(on date: Date = .now) {
        let today = dayStamp(date)
        let current = count(on: date)
        defaults.set(today, forKey: dayKey)
        defaults.set(current + 1, forKey: countKey)
    }

    private func dayStamp(_ date: Date) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
    }
}
