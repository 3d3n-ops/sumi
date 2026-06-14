//
//  PermissionsService.swift
//  sumi-ios
//
//  Thin async wrappers around the system permission prompts onboarding requests.
//  Each returns whether access was granted; none crash or assume.
//

import Foundation
import AVFoundation
import UserNotifications
import EventKit
import Contacts

@MainActor
enum PermissionsService {
    /// Requests microphone access (for talking to Sumi).
    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Requests notification authorization (for proactive nudges).
    static func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Requests full calendar (events) access.
    static func requestCalendar() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    /// Requests full reminders access.
    static func requestReminders() async -> Bool {
        (try? await EKEventStore().requestFullAccessToReminders()) ?? false
    }

    /// Requests contacts access.
    static func requestContacts() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    // MARK: - Current status

    static var calendarGranted: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var remindersGranted: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    static var contactsGranted: Bool { CNContactStore.authorizationStatus(for: .contacts) == .authorized }
}
