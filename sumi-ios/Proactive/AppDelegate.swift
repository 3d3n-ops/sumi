//
//  AppDelegate.swift
//  sumi-ios
//
//  Registers and schedules BGTasks at launch. Adapted into the SwiftUI App via
//  UIApplicationDelegateAdaptor.
//

import UIKit

/// App delegate whose sole job (for now) is BGTask registration + scheduling.
///
/// Registration must happen before `application(_:didFinishLaunchingWithOptions:)`
/// returns, so it runs here rather than in a SwiftUI lifecycle hook.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskCoordinator.shared.register()
        BackgroundTaskCoordinator.shared.scheduleProactiveRefresh()
        BackgroundTaskCoordinator.shared.scheduleMaintenance()
        return true
    }
}
