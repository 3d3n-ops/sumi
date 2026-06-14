//
//  WelcomeView.swift
//  sumi-ios
//
//  Onboarding step 01 — the first impression: the living-light mark, a warm
//  introduction, and the on-device promise. "The new mark: a living light."
//

import SwiftUI

struct WelcomeView: View {
    /// Advances onboarding.
    var onGetStarted: () -> Void = {}
    /// 0-based index and total, for the shared progress dots.
    var stepIndex: Int = 0
    var stepCount: Int = 6

    var body: some View {
        OnboardingHeroScaffold(
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "Get started",
            footnote: "Private by design · AI by sumi's secure cloud",
            onContinue: onGetStarted
        ) {
            VStack(spacing: 0) {
                // Hero: the orb over a faint ambient wash.
                ZStack {
                    LivingLightWash(size: 340)
                    LivingLightOrb(size: 188)
                }
                .frame(height: 300)
                .padding(.top, 12)

                Text("hello, I'm sumi")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                Text("Your assistant, attuned to you —\nand quietly one step ahead.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
        }
    }
}

#Preview {
    WelcomeView()
}
