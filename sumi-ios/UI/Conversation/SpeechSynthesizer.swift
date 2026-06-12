//
//  SpeechSynthesizer.swift
//  sumi-ios
//
//  Speaks Sumi's replies aloud when the user is in voice mode.
//

import Foundation
import AVFoundation

@MainActor
final class SpeechSynthesizer {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
