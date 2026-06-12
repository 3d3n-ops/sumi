//
//  SpeechRecognizer.swift
//  sumi-ios
//
//  Live on-device speech-to-text for the conversation surface. Push-to-talk:
//  start() opens the mic and streams partial transcripts into `transcript`;
//  stop() ends the session. Foreground only — there is no system wake word on
//  iOS, so this runs while the conversation screen is open.
//

import Foundation
import Speech
import AVFoundation
import Observation
import OSLog

@MainActor
@Observable
final class SpeechRecognizer {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var isAuthorized = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "SpeechRecognizer")

    /// Requests speech + microphone permission. Safe to call repeatedly.
    func requestAuthorization() async {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        isAuthorized = speechOK && micOK
    }

    /// Begins a recognition session. No-op if already recording.
    func start() throws {
        guard !isRecording else { return }
        task?.cancel()
        task = nil
        transcript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    /// Ends the current session and releases the mic.
    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
