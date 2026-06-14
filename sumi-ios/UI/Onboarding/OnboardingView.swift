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
                    .font(.largeTitle.weight(.bold))
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

/// Shared layout for the centered hero steps (Welcome, Privacy, First moment):
/// content scrolls when it can't fit (small screens / large Dynamic Type) while
/// the progress dots and CTA stay pinned to the bottom.
struct OnboardingHeroScaffold<Content: View>: View {
    let stepIndex: Int
    let stepCount: Int
    let buttonTitle: String
    var footnote: String? = nil
    let onContinue: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) { content() }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SumiTheme.screenMargin)
                .padding(.top, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                PageDots(count: stepCount, index: stepIndex)
                SumiPrimaryButton(buttonTitle, action: onContinue)
                if let footnote {
                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, SumiTheme.screenMargin)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
        }
    }
}

/// Drives the six-step flow and reports `onFinish` when the user starts using Sumi.
///
/// Steps live in a paged `TabView` so the user can swipe both ways natively; each
/// step's primary button also advances the selection, and a back chevron appears
/// after the first step.
struct OnboardingView: View {
    var onFinish: () -> Void = {}

    @State private var step = 0
    private let stepCount = 6

    var body: some View {
        TabView(selection: $step) {
            WelcomeView(onGetStarted: advance, stepIndex: 0, stepCount: stepCount).tag(0)
            PermissionsView(onContinue: advance, stepIndex: 1, stepCount: stepCount).tag(1)
            VoiceTuneView(onContinue: advance, stepIndex: 2, stepCount: stepCount).tag(2)
            PersonalContextView(onContinue: advance, stepIndex: 3, stepCount: stepCount).tag(3)
            PrivacyView(onContinue: advance, stepIndex: 4, stepCount: stepCount).tag(4)
            FirstMomentView(onStart: onFinish, stepIndex: 5, stepCount: stepCount).tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
    }

    private var topBar: some View {
        HStack {
            if step > 0 {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .transition(.opacity)
                .accessibilityLabel("Back")
            }
            Spacer()
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
    }

    private func advance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = min(step + 1, stepCount - 1)
        }
    }

    private func goBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step = max(step - 1, 0)
        }
    }
}

#Preview {
    OnboardingView()
}
