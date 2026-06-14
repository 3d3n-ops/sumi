//
//  PrivacyView.swift
//  sumi-ios
//
//  Onboarding step 05 — the on-device promise, up front. "Yours, and only yours."
//

import SwiftUI

struct PrivacyView: View {
    var onContinue: () -> Void = {}
    var stepIndex: Int = 4
    var stepCount: Int = 6

    var body: some View {
        OnboardingHeroScaffold(
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "I understand",
            onContinue: onContinue
        ) {
            VStack(spacing: 0) {
                // Lock inside the living light.
                ZStack {
                    LivingLightWash(size: 280)
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 132, height: 132)
                        .shadow(color: SumiTheme.glow.opacity(0.4), radius: 24)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1)
                        )
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(height: 220)
                .padding(.top, 8)

                Text("Yours, and only yours")
                    .font(.largeTitle.weight(.bold))
                    .padding(.top, 8)

                Text("sumi runs on your device. Your life stays on your device.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 18) {
                    Promise(title: "Processed on device.", detail: "Requests are handled locally by default.")
                    Promise(title: "Never sold, never trained on.", detail: "Your data isn't the product.")
                    Promise(title: "You're in control.", detail: "Review or erase what sumi remembers, anytime.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.top, 28)
            }
        }
    }
}

/// A green-checked promise with a bold lede and muted detail.
private struct Promise: View {
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(SumiTheme.tileGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PrivacyView()
}
