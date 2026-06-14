//
//  SumiPrefKey.swift
//  sumi-ios
//
//  Shared UserDefaults keys for user-facing preferences set during onboarding and
//  edited later in Settings. These are non-secret app preferences (the rule keeps
//  *secrets* in the Keychain — these aren't secrets), so UserDefaults via
//  @AppStorage is the right home.
//

import Foundation

enum SumiPrefKey {
    /// True once the user has finished onboarding.
    static let onboardingComplete = "sumi.onboarding.complete"

    // Permissions / features
    static let micEnabled = "sumi.perm.mic"
    static let onscreenAwareness = "sumi.feature.onscreen"
    static let notificationsEnabled = "sumi.perm.notifications"
    static let proactiveSuggestions = "sumi.feature.proactive"

    // Voice dial (0...1)
    static let voiceTone = "sumi.voice.tone"
    static let voicePace = "sumi.voice.pace"
    static let voiceWarmth = "sumi.voice.warmth"

    // Personal-context sources Sumi may draw on
    static let sourceCalendar = "sumi.source.calendar"
    static let sourceMail = "sumi.source.mail"
    static let sourceContacts = "sumi.source.contacts"
    static let sourceHealth = "sumi.source.health"

    /// How long to retain conversation history, in days.
    static let keepHistoryDays = "sumi.history.days"
}
