//
//  VoiceTuneView.swift
//  sumi-ios
//
//  Onboarding step 03 — micro-tune Sumi's voice: tone, pace, warmth. A tappable
//  waveform previews the choice; values persist and are editable later.
//

import SwiftUI

struct VoiceTuneView: View {
    var onContinue: () -> Void = {}
    var stepIndex: Int = 2
    var stepCount: Int = 6

    @AppStorage(SumiPrefKey.voiceTone) private var tone = 0.4
    @AppStorage(SumiPrefKey.voicePace) private var pace = 0.5
    @AppStorage(SumiPrefKey.voiceWarmth) private var warmth = 0.7

    @State private var previewTaps = 0

    var body: some View {
        OnboardingScaffold(
            title: "Find sumi's voice",
            subtitle: "Tune it now — change it anytime.",
            stepIndex: stepIndex,
            stepCount: stepCount,
            buttonTitle: "Continue",
            onContinue: onContinue
        ) {
            VStack(spacing: 28) {
                Button {
                    previewTaps += 1
                } label: {
                    HStack(spacing: 14) {
                        EqualizerBars()
                        Text("Tap to hear").font(.body.weight(.medium))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .sumiCard()
                .sensoryFeedback(.impact(weight: .light), trigger: previewTaps)

                VoiceSlider(label: "Tone", trailing: "Calm", value: $tone)
                VoiceSlider(label: "Pace", trailing: "Natural", value: $pace)
                VoiceSlider(label: "Warmth", trailing: "Warm", value: $warmth)
            }
        }
    }
}

/// A labeled slider with a descriptor on the right (Calm / Natural / Warm).
private struct VoiceSlider: View {
    let label: String
    let trailing: String
    @Binding var value: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label).font(.body.weight(.semibold))
                Spacer()
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
            Slider(value: $value)
                .tint(.primary)
        }
    }
}

/// Decorative colored equalizer bars — the brand's "voice" glyph.
private struct EqualizerBars: View {
    private let heights: [CGFloat] = [10, 20, 14, 26, 16, 22, 12]
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .indigo, .purple,
    ]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule()
                    .fill(colors[i % colors.count])
                    .frame(width: 3, height: heights[i])
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

#Preview {
    VoiceTuneView()
}
