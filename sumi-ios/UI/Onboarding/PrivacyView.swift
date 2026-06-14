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
        VStack(spacing: 0) {
            Spacer(minLength: 16)

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
            .frame(height: 240)

            Text("Yours, and only yours")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Text("sumi runs on your device. Your life stays on your device.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 18) {
                Promise(title: "Processed on device.", detail: "Requests are handled locally by default.")
                Promise(title: "Never sold, never trained on.", detail: "Your data isn't the product.")
                Promise(title: "You're in control.", detail: "Review or erase what sumi remembers, anytime.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 28)

            Spacer()

            PageDots(count: stepCount, index: stepIndex)
                .padding(.bottom, 20)
            SumiPrimaryButton("I understand", action: onContinue)
        }
        .padding(.horizontal, SumiTheme.screenMargin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
