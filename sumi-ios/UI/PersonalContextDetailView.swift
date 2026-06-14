//
//  PersonalContextDetailView.swift
//  sumi-ios
//
//  "What sumi knows about you" — manage which sources Sumi may draw on. Mirrors
//  the onboarding personal-context step, editable anytime. (Memory review of
//  individual remembered facts is a later addition.)
//

import SwiftUI

struct PersonalContextDetailView: View {
    @AppStorage(SumiPrefKey.sourceCalendar) private var calendar = true
    @AppStorage(SumiPrefKey.sourceMail) private var mail = true
    @AppStorage(SumiPrefKey.sourceContacts) private var contacts = false
    @AppStorage(SumiPrefKey.sourceHealth) private var health = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Sumi only ever reads the sources you allow. Change these anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                SourceToggle(tile: IconTile(systemName: "calendar", color: SumiTheme.tileBlue),
                             title: "Calendar & reminders", subtitle: "Your schedule and to-dos", isOn: $calendar)
                SourceToggle(tile: IconTile(systemName: "envelope.fill", color: SumiTheme.tileBlue),
                             title: "Mail & messages", subtitle: "Trips, orders, plans", isOn: $mail)
                SourceToggle(tile: IconTile(systemName: "person.fill", color: SumiTheme.tileGray),
                             title: "Contacts & relationships", subtitle: "Who's who in your life", isOn: $contacts)
                SourceToggle(tile: IconTile(systemName: "heart.fill", color: SumiTheme.tilePink),
                             title: "Health & routines", subtitle: "Sleep, workouts, habits", isOn: $health)
            }
            .padding(SumiTheme.screenMargin)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Personal context")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourceToggle: View {
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
            Toggle("", isOn: $isOn).labelsHidden().tint(SumiTheme.tileGreen)
        }
        .sumiCard()
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    NavigationStack { PersonalContextDetailView() }
}
