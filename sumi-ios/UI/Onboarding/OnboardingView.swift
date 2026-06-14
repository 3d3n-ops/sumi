//
//  OnboardingView.swift
//  sumi-ios
//
//  The onboarding container: pages between the six steps with a spring slide,
//  shares the progress dots, and reports completion. Shown on first launch only.
//

import SwiftUI

/// Shared layout for the left-aligned steps (title, optional subtitle, scrolling
/// content, progress dots, primary CTA). Welcome and the centered steps don't use
/// it — they have bespoke hero layouts.
struct OnboardingScaffold<Content: View>: View {
    let title: String
    var subtitle: String?
    let stepIndex: Int
    let stepCount: Int
    let buttonTitle: String
    let onContinue: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

            ScrollView {
                content().padding(.top, 24)
            }
            .scrollBounceBehavior(.basedOnSize)

            PageDots(count: stepCount, index: stepIndex)
                .padding(.vertical, 20)

            SumiPrimaryButton(buttonTitle, action: onContinue)
        }
        .padding(.horizontal, SumiTheme.screenMargin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Drives the six-step flow and reports `onFinish` when the user starts using Sumi.
struct OnboardingView: View {
    var onFinish: () -> Void = {}

    @State private var step = 0
    private let stepCount = 6

    var body: some View {
        ZStack {
            currentStep
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0:
            WelcomeView(onGetStarted: advance, stepIndex: 0, stepCount: stepCount)
        case 1:
            PermissionsView(onContinue: advance, stepIndex: 1, stepCount: stepCount)
        case 2:
            VoiceTuneView(onContinue: advance, stepIndex: 2, stepCount: stepCount)
        case 3:
            PersonalContextView(onContinue: advance, stepIndex: 3, stepCount: stepCount)
        case 4:
            PrivacyView(onContinue: advance, stepIndex: 4, stepCount: stepCount)
        default:
            FirstMomentView(onStart: onFinish, stepIndex: 5, stepCount: stepCount)
        }
    }

    private func advance() {
        step = min(step + 1, stepCount - 1)
    }
}

#Preview {
    OnboardingView()
}
