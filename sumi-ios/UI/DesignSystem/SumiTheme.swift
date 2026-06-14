//
//  SumiTheme.swift
//  sumi-ios
//
//  Design tokens for Sumi's UI: the iridescent brand palette, metrics, and the
//  semantic colors the screens reuse. Everything leans on system semantic colors
//  so light/dark and Dynamic Type come for free — Apple's house style.
//

import SwiftUI

/// Central design tokens. No view logic here — just the brand vocabulary.
enum SumiTheme {

    // MARK: - Brand: the "living light"

    /// Nine soft, pastel stops for the orb's 3×3 `MeshGradient` (row-major).
    /// A bright core with iridescent pink / peach / lavender / periwinkle / mint
    /// around it — the "living light" mark.
    static let iridescent: [Color] = [
        Color(red: 1.00, green: 0.74, blue: 0.86),   // top-left  · pink
        Color(red: 1.00, green: 0.85, blue: 0.74),   // top       · peach
        Color(red: 0.83, green: 0.80, blue: 1.00),   // top-right · lavender
        Color(red: 0.74, green: 0.90, blue: 1.00),   // left      · sky
        Color.white,                                  // center    · core glow
        Color(red: 0.76, green: 1.00, blue: 0.88),   // right     · mint
        Color(red: 0.86, green: 0.80, blue: 1.00),   // bot-left  · violet
        Color(red: 0.78, green: 0.88, blue: 1.00),   // bottom    · periwinkle
        Color(red: 1.00, green: 0.80, blue: 0.90),   // bot-right · rose
    ]

    /// Soft glow color cast beneath the orb and active controls.
    static let glow = Color(red: 0.72, green: 0.80, blue: 1.00)

    // MARK: - Metrics

    /// Continuous-corner radius for elevated cards.
    static let cardRadius: CGFloat = 22
    /// Continuous-corner radius for the small colored icon tiles.
    static let tileRadius: CGFloat = 13
    /// Standard inset for card content.
    static let cardPadding: CGFloat = 16
    /// Standard horizontal screen margin.
    static let screenMargin: CGFloat = 24

    // MARK: - Icon-tile palette (iOS Settings vocabulary)

    static let tileRed = Color(red: 1.00, green: 0.27, blue: 0.27)
    static let tileBlue = Color(red: 0.20, green: 0.52, blue: 1.00)
    static let tileOrange = Color(red: 1.00, green: 0.58, blue: 0.18)
    static let tileGreen = Color(red: 0.24, green: 0.78, blue: 0.45)
    static let tilePink = Color(red: 1.00, green: 0.36, blue: 0.52)
    static let tileGray = Color(red: 0.56, green: 0.58, blue: 0.62)
}

extension ShapeStyle where Self == Color {
    /// The brand glow, usable anywhere a `ShapeStyle` is expected.
    static var sumiGlow: Color { SumiTheme.glow }
}
