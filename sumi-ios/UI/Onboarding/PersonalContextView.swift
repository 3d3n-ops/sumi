//
//  PersonalContextView.swift
//  sumi-ios
//
//  Onboarding step 04 — the user chooses which sources Sumi may draw on. Sumi
//  only ever reads what's allowed here. Selections persist and gate later access.
//

import SwiftUI
import UIKit

struct PersonalContextView: View {
    var onContinue: () -> Void = {}
    var stepIndex: Int = 3
    var stepCount: Int = 6

    @AppStorage(SumiPrefKey.sourceCalendar) private var calendar = false
    @AppStorage(SumiPrefKey.sourceMail) private var mail = true
    @AppStorage(SumiPrefKey.sourceContacts) private var contacts = false
    @AppStorage(SumiPrefKey.sourceHealth) private var health = false

    @State private var deniedSource: String?

    var body: some View {
        OnboardingScaffold(
            title: "What should\nsumi know?",
            subtitle: "Pick the sources it can draw on. It only ever reads what you allow.",
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "Continue",
            onContinue: onContinue
        ) {
            VStack(spacing: 12) {
                SourceCard(
                    tile: IconTile(systemName: "calendar", color: SumiTheme.tileBlue),
                    title: "Calendar & reminders",
                    subtitle: "Your schedule and to-dos",
                    isOn: $calendar
                )
                .onChange(of: calendar) { _, on in
                    guard on else { return }
                    Task {
                        // The card covers both; require both to call it granted.
                        let cal = await PermissionsService.requestCalendar()
                        let rem = await PermissionsService.requestReminders()
                        calendar = cal && rem
                        if !(cal && rem) { deniedSource = "Calendar & reminders" }
                    }
                }

                SourceCard(
                    tile: IconTile(systemName: "envelope.fill", color: SumiTheme.tileBlue),
                    title: "Mail & messages",
                    subtitle: "Trips, orders, plans",
                    isOn: $mail
                )

                SourceCard(
                    tile: IconTile(systemName: "person.fill", color: SumiTheme.tileGray),
                    title: "Contacts & relationships",
                    subtitle: "Who's who in your life",
                    isOn: $contacts
                )
                .onChange(of: contacts) { _, on in
                    guard on else { return }
                    Task {
                        let granted = await PermissionsService.requestContacts()
                        contacts = granted
                        if !granted { deniedSource = "Contacts" }
                    }
                }

                SourceCard(
                    tile: IconTile(systemName: "heart.fill", color: SumiTheme.tilePink),
                    title: "Health & routines",
                    subtitle: "Sleep, workouts, habits",
                    isOn: $health
                )
            }
        }
        .alert("\(deniedSource ?? "That") access is off", isPresented: deniedBinding) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn it on in Settings whenever you're ready — sumi only reads what you allow.")
        }
    }

    private var deniedBinding: Binding<Bool> {
        Binding(get: { deniedSource != nil }, set: { if !$0 { deniedSource = nil } })
    }
}

/// A selectable source row with a trailing check that fills when chosen.
private struct SourceCard: View {
    let tile: IconTile
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                tile
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? AnyShapeStyle(SumiTheme.tileGreen) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .sumiCard()
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    PersonalContextView()
}
