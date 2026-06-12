//
//  NotificationComposer.swift
//  sumi-ios
//
//  Turns a ProactiveSurface into a single user notification.
//

import Foundation
import UserNotifications
import OSLog

/// Posts a single local notification for a surface, with primary + dismiss actions.
///
/// The `UNUserNotificationCenter` dependency is hidden behind a protocol so tests
/// can verify composition without the real notification system.
protocol NotificationScheduling: Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func setCategories(_ categories: Set<UNNotificationCategory>) async
}

/// Production scheduler backed by the system notification center.
struct SystemNotificationScheduler: NotificationScheduling {
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) async {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

/// Composes and fires proactive notifications.
struct NotificationComposer: Sendable {
    /// Category identifier shared by all proactive notifications.
    static let categoryIdentifier = "sumi.proactive"
    /// Action identifiers.
    static let primaryActionID = "sumi.proactive.primary"
    static let dismissActionID = "sumi.proactive.dismiss"

    private let scheduler: any NotificationScheduling
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "NotificationComposer")

    init(scheduler: any NotificationScheduling = SystemNotificationScheduler()) {
        self.scheduler = scheduler
    }

    /// Builds the notification content for `surface` (no markdown — spoken body).
    func content(for surface: ProactiveSurface) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = surface.message
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["triggerID": surface.triggerID]
        content.sound = .default
        return content
    }

    /// Builds the action category for `surface`.
    func category(for surface: ProactiveSurface) -> UNNotificationCategory {
        let primary = UNNotificationAction(
            identifier: Self.primaryActionID,
            title: surface.primaryActionTitle,
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: Self.dismissActionID,
            title: surface.dismissTitle,
            options: [.destructive]
        )
        return UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [primary, dismiss],
            intentIdentifiers: [],
            options: []
        )
    }

    /// Fires a single notification for `surface`.
    func fire(surface: ProactiveSurface) async {
        await scheduler.setCategories([category(for: surface)])

        let request = UNNotificationRequest(
            identifier: "sumi.proactive.\(surface.triggerID).\(UUID().uuidString)",
            content: content(for: surface),
            trigger: nil // deliver immediately
        )

        do {
            try await scheduler.add(request)
        } catch {
            logger.error("Failed to post proactive notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}
