//
//  SumiComponents.swift
//  sumi-ios
//
//  Small reusable building blocks: the colored icon tile (iOS Settings
//  vocabulary), the morphing page-dot progress indicator, and the elevated card
//  background used across onboarding and settings.
//

import SwiftUI

/// A rounded-square colored tile with an SF Symbol — the iOS Settings idiom.
struct IconTile: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}

/// Page progress as morphing dots — the active one stretches into a pill, the
/// way Sumi's onboarding mockups show it.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.primary : Color.secondary.opacity(0.28))
                    .frame(width: i == index ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
        .accessibilityElement()
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}

/// Elevated card background: a continuous-corner surface with a hairline border
/// and a soft shadow. Apply with `.sumiCard()`.
private struct SumiCardBackground: ViewModifier {
    var padding: CGFloat = SumiTheme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: SumiTheme.cardRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SumiTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

extension View {
    /// Wraps the view in Sumi's elevated card surface.
    func sumiCard(padding: CGFloat = SumiTheme.cardPadding) -> some View {
        modifier(SumiCardBackground(padding: padding))
    }
}

#Preview("Components") {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            IconTile(systemName: "mic.fill", color: SumiTheme.tileRed)
            IconTile(systemName: "eye.fill", color: SumiTheme.tileBlue)
            IconTile(systemName: "bell.fill", color: SumiTheme.tileOrange)
        }
        PageDots(count: 6, index: 2)
        VStack(alignment: .leading) {
            Text("Personal context").font(.headline)
            Text("What sumi knows about you").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sumiCard()
    }
    .padding(24)
    .background(Color(.systemGroupedBackground))
}
