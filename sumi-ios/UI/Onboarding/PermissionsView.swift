//
//  PermissionsView.swift
//  sumi-ios
//
//  Onboarding step 02 — honest, granular, reversible. Each toggle requests the
//  real system permission when turned on; on-screen awareness is an app feature.
//

import SwiftUI
import UIKit

struct PermissionsView: View {
    var onContinue: () -> Void = {}
    var stepIndex: Int = 1
    var stepCount: Int = 6

    @AppStorage(SumiPrefKey.micEnabled) private var micEnabled = false
    @AppStorage(SumiPrefKey.onscreenAwareness) private var onscreenAwareness = true
    @AppStorage(SumiPrefKey.notificationsEnabled) private var notificationsEnabled = false

    @State private var deniedFeature: String?

    var body: some View {
        OnboardingScaffold(
            title: "A few things\nto get started",
            subtitle: "Grant what you're comfortable with. Change it anytime in Settings.",
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "Continue",
            onContinue: onContinue
        ) {
            VStack(spacing: 12) {
                PermissionCard(
                    tile: IconTile(systemName: "mic.fill", color: SumiTheme.tileRed),
                    title: "Microphone",
                    subtitle: "So you can just talk to sumi.",
                    isOn: $micEnabled
                )
                .onChange(of: micEnabled) { _, on in
                    guard on else { return }
                    Task { await request("Microphone", PermissionsService.requestMicrophone, into: $micEnabled) }
                }

                PermissionCard(
                    tile: IconTile(systemName: "eye.fill", color: SumiTheme.tileBlue),
                    title: "On-screen awareness",
                    subtitle: "Understands what you're looking at.",
                    isOn: $onscreenAwareness
                )

                PermissionCard(
                    tile: IconTile(systemName: "bell.fill", color: SumiTheme.tileOrange),
                    title: "Notifications",
                    subtitle: "Gentle nudges, only when useful.",
                    isOn: $notificationsEnabled
                )
                .onChange(of: notificationsEnabled) { _, on in
                    guard on else { return }
                    Task { await request("Notifications", PermissionsService.requestNotifications, into: $notificationsEnabled) }
                }
            }
        }
        .alert("\(deniedFeature ?? "Permission") access is off", isPresented: deniedBinding) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn it on in Settings whenever you're ready.")
        }
    }

    /// Runs a permission request; reflects the real result in the toggle and, if
    /// denied, surfaces the "open Settings" alert (iOS won't re-prompt once denied).
    @MainActor
    private func request(_ name: String, _ ask: @MainActor () async -> Bool, into binding: Binding<Bool>) async {
        let granted = await ask()
        binding.wrappedValue = granted
        if !granted { deniedFeature = name }
    }

    private var deniedBinding: Binding<Bool> {
        Binding(get: { deniedFeature != nil }, set: { if !$0 { deniedFeature = nil } })
    }
}

/// One permission row: colored tile, copy, and a green switch.
private struct PermissionCard: View {
    let tile: IconTile
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            tile
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SumiTheme.tileGreen)
        }
        .sumiCard()
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    PermissionsView()
}
