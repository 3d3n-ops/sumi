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
}
