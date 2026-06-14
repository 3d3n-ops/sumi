//
//  LivingLightOrb.swift
//  sumi-ios
//
//  Sumi's brand mark: a soft, iridescent orb of "living light" that breathes at
//  rest and stirs when it's listening. Built on an animated MeshGradient so it
//  feels alive without a video or image asset. Honors Reduce Motion.
//

import SwiftUI

/// The animated "living light" orb. Drop it anywhere; size scales the whole mark
/// including its glow.
struct LivingLightOrb: View {
    /// Diameter of the core orb in points.
    var size: CGFloat = 180
    /// When true (e.g. actively listening), the orb breathes faster and wider.
    var isActive: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            orb(phase: phase)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func orb(phase: TimeInterval) -> some View {
        ZStack {
            // Iridescent body — a gently drifting mesh.
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.meshPoints(phase: phase, energy: isActive ? 1.6 : 1.0),
                colors: SumiTheme.iridescent
            )

            // Bright living-light core.
            RadialGradient(
                colors: [.white, .white.opacity(0.0)],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.46
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        // Soft inner rim so the orb reads as a lit sphere, not a flat disc.
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                .blur(radius: 0.5)
        )
        .shadow(color: SumiTheme.glow.opacity(0.55), radius: size * 0.16, y: size * 0.04)
        .scaleEffect(Self.breathing(phase: phase, isActive: isActive))
    }

    // MARK: - Motion

    /// Drifting control points for the 3×3 mesh. Corners stay pinned; edges and
    /// the center wobble on slightly out-of-phase sine curves so the iridescence
    /// rolls instead of pulsing uniformly.
    static func meshPoints(phase: Double, energy: Float) -> [SIMD2<Float>] {
        func wobble(_ base: SIMD2<Float>, _ ax: Double, _ ay: Double, _ amp: Float) -> SIMD2<Float> {
            SIMD2(
                base.x + Float(sin(phase * ax)) * amp * energy,
                base.y + Float(cos(phase * ay)) * amp * energy
            )
        }
        return [
            SIMD2(0, 0), wobble(SIMD2(0.5, 0), 0.70, 0.90, 0.06), SIMD2(1, 0),
            wobble(SIMD2(0, 0.5), 1.10, 0.60, 0.06), wobble(SIMD2(0.5, 0.5), 0.90, 1.30, 0.10), wobble(SIMD2(1, 0.5), 0.80, 1.00, 0.06),
            SIMD2(0, 1), wobble(SIMD2(0.5, 1), 1.20, 0.70, 0.06), SIMD2(1, 1),
        ]
    }

    /// Gentle "breathing" scale — subtle at rest, larger and quicker when active.
    static func breathing(phase: Double, isActive: Bool) -> CGFloat {
        let amplitude: CGFloat = isActive ? 0.05 : 0.02
        let rate: Double = isActive ? 2.2 : 1.0
        return 1 + CGFloat(sin(phase * rate)) * amplitude
    }
}

/// A faint, oversized wash of the orb's colors — used as an ambient backdrop
/// behind hero content (Welcome, voice). Cheap and decorative.
struct LivingLightWash: View {
    var size: CGFloat = 360
    var body: some View {
        LivingLightOrb(size: size)
            .opacity(0.22)
            .blur(radius: 44)
            .accessibilityHidden(true)
    }
}

#Preview("Orb") {
    VStack(spacing: 40) {
        LivingLightOrb(size: 200)
        LivingLightOrb(size: 120, isActive: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}
