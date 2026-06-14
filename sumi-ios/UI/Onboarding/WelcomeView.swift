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
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // Hero: the orb over a faint ambient wash.
            ZStack {
                LivingLightWash(size: 340)
                LivingLightOrb(size: 188)
            }
            .frame(maxHeight: 320)

            Spacer(minLength: 16)

            Text("hello, I'm sumi")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            Text("Your assistant, attuned to you —\nand quietly one step ahead.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 8)

            Spacer()

            PageDots(count: stepCount, index: stepIndex)
                .padding(.bottom, 22)

            SumiPrimaryButton("Get started", action: onGetStarted)

            Text("On-device by default · Private")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
        }
        .padding(.horizontal, SumiTheme.screenMargin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    WelcomeView()
}
