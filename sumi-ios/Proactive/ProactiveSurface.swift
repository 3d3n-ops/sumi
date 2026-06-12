//
//  ProactiveSurface.swift
//  sumi-ios
//
//  The concrete thing a trigger produces: a single notification-ready surface.
//

import Foundation

/// A ready-to-fire proactive surface.
///
/// `message` is spoken-quality (no markdown). `relevanceScore` gates whether the
/// surface fires (threshold 0.80) and ranks competing surfaces. `expiresAt`
/// prevents stale surfaces from firing late. `triggerID` ties it back to its
/// producing trigger for suppression bookkeeping.
struct ProactiveSurface: Sendable, Equatable {
    /// Spoken-quality notification body. No markdown, bullets, or headers.
    var message: String
    /// Title for the primary action button.
    var primaryActionTitle: String
    /// The action performed when the user taps the primary button.
    var primaryAction: SumiAction
    /// Title for the dismiss button.
    var dismissTitle: String
    /// 0...1 relevance. Must meet the 0.80 threshold to fire.
    var relevanceScore: Float
    /// When this surface should no longer be shown.
    var expiresAt: Date
    /// Identifier of the trigger that produced this surface.
    var triggerID: String

    init(
        message: String,
        primaryActionTitle: String,
        primaryAction: SumiAction,
        dismissTitle: String = "Dismiss",
        relevanceScore: Float,
        expiresAt: Date,
        triggerID: String
    ) {
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.dismissTitle = dismissTitle
        self.relevanceScore = relevanceScore
        self.expiresAt = expiresAt
        self.triggerID = triggerID
    }

    /// Whether the surface is still valid at `date`.
    func isFresh(at date: Date = .now) -> Bool {
        expiresAt > date
    }
}
