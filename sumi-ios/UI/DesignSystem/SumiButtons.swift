//
//  SumiButtons.swift
//  sumi-ios
//
//  Primary (solid) and secondary (soft) button styles, plus a convenience button
//  that fires a light haptic on tap. Press states use a spring scale — the small
//  tactile detail that makes a control feel Apple-made.
//

import SwiftUI

/// Full-width solid pill — the high-contrast primary CTA (Get started, Continue,
/// Send, I understand). Black on white in light mode, white on black in dark.
struct SumiPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.primary, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Soft, low-emphasis pill (e.g. the "Edit" companion to a primary "Send").
struct SumiSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color(.secondarySystemFill), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Convenience primary button that fires a light selection haptic on tap, so
/// call sites don't have to wire `.sensoryFeedback` themselves.
struct SumiPrimaryButton: View {
    let title: String
    let action: () -> Void

    @State private var taps = 0

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(SumiPrimaryButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

#Preview("Buttons") {
    VStack(spacing: 14) {
        SumiPrimaryButton("Get started") {}
        Button("Edit") {}.buttonStyle(SumiSecondaryButtonStyle())
    }
    .padding(24)
}
