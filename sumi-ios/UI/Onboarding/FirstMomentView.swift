//
//  FirstMomentView.swift
//  sumi-ios
//
//  Onboarding step 06 — a guided "try it" before the app opens. Tap the orb and
//  it listens; pick a starter to seed the first ask. Then into Sumi.
//

import SwiftUI

struct FirstMomentView: View {
    var onStart: () -> Void = {}
    var stepIndex: Int = 5
    var stepCount: Int = 6

    @State private var listening = false
    @State private var orbTaps = 0

    private let starters = [
        ("calendar", "What's on my calendar today?"),
        ("airplane", "Track my flight to SFO"),
    ]

    var body: some View {
        OnboardingHeroScaffold(
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "Start using sumi",
            onContinue: onStart
        ) {
            VStack(spacing: 0) {
                Text("Give it a try")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 8)
                Text("Tap the orb and say something — or pick a starter.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                Button {
                    orbTaps += 1
                    listening.toggle()
                } label: {
                    LivingLightOrb(size: 196, isActive: listening)
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
                .sensoryFeedback(.impact(weight: .medium), trigger: orbTaps)

                Text(listening ? "Listening…" : "Tap to speak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .animation(.easeInOut, value: listening)

                VStack(spacing: 10) {
                    ForEach(starters, id: \.1) { starter in
                        StarterChip(symbol: starter.0, text: starter.1) {
                            listening = true
                            orbTaps += 1
                        }
                    }
                }
                .padding(.top, 28)
            }
        }
    }
}

/// A suggested-prompt chip with a leading glyph.
private struct StarterChip: View {
    let symbol: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text("“\(text)”")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
            }
            .sumiCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FirstMomentView()
}
