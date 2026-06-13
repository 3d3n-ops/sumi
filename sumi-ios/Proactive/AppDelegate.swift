//
//  AppDelegate.swift
//  sumi-ios
//
//  Registers and schedules BGTasks at launch. Adapted into the SwiftUI App via
//  UIApplicationDelegateAdaptor.
//

import UIKit
import OSLog

/// App delegate: BGTask registration + scheduling, plus remote-notification
/// registration and the silent-push handler that wakes the proactive engine.
///
/// BGTask registration must happen before `didFinishLaunchingWithOptions`
/// returns, so it runs here rather than in a SwiftUI lifecycle hook.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskCoordinator.shared.register()
        BackgroundTaskCoordinator.shared.scheduleProactiveRefresh()
        BackgroundTaskCoordinator.shared.scheduleMaintenance()

        // Register for silent (background) pushes. This needs no user
        // notification permission — it only grants a device token for APNs.
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - Remote notification registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = PushService.hexToken(from: deviceToken)
        Task { await PushService.register(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Remote notification registration failed: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Silent push → proactive evaluation

    /// A silent (content-available) push from the Worker arrives here. Run a
    /// single proactive evaluation within the background time the system grants.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let env = SumiEnvironment.shared
        let engine = ProactiveEngine(
            memory: env.memory,
            triggers: [MorningBriefTrigger(router: env.router), FollowUpTrigger(), MeetingPrepTrigger()]
        )
        await engine.evaluate()
        return .newData
    }
}
