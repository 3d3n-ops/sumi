//
//  ConversationView.swift
//  sumi-ios
//
//  The in-app conversation surface — a ChatGPT-style transcript with a text +
//  voice composer. Voice is push-to-talk (no system wake word exists on iOS);
//  a one-press launch can drop the user straight into a listening session.
//

import SwiftUI
import UIKit

struct ConversationView: View {
    @State private var model = ConversationViewModel()
    @State private var speech = SpeechRecognizer()
    @State private var synthesizer = SpeechSynthesizer()
    @State private var appState = AppState.shared
    @State private var speakReplies = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty { emptyState }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                        if model.isResponding { TypingIndicator().id(Self.typingID) }
                    }
                    .padding()
                }
                .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: model.isResponding) { _, _ in scrollToBottom(proxy) }
            }
            composer
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    speakReplies.toggle()
                    if !speakReplies { synthesizer.stop() }
                } label: {
                    Image(systemName: speakReplies ? "speaker.wave.2.fill" : "speaker.slash")
                }
                .accessibilityLabel(speakReplies ? "Spoken replies on" : "Spoken replies off")
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    LivingLightOrb(size: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("sumi").font(.headline)
                        HStack(spacing: 3) {
                            Circle().fill(SumiTheme.tileGreen).frame(width: 5, height: 5)
                            Text("On-device").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sumi, on-device")
            }
        }
        .onChange(of: speech.transcript) { _, new in model.input = new }
        .onChange(of: model.messages.last?.id) { _, _ in speakLatestIfNeeded() }
        .onChange(of: appState.pendingVoiceSession) { _, pending in
            if pending {
                appState.pendingVoiceSession = false
                startListening()
            }
        }
        .onChange(of: appState.pendingQuery) { _, query in
            if let query { consumePendingQuery(query) }
        }
        .onAppear {
            if appState.pendingVoiceSession {
                appState.pendingVoiceSession = false
                startListening()
            }
            if let query = appState.pendingQuery {
                consumePendingQuery(query)
            }
        }
    }

    private static let typingID = "typing-indicator"

    private var emptyState: some View {
        VStack(spacing: 14) {
            LivingLightOrb(size: 76)
            Text("Talk to sumi").font(.title3.weight(.semibold))
            Text("Tap the mic and talk, or type below.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 64)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button(action: toggleListening) {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(speech.isRecording ? Color.red : Color.accentColor)
            }
            TextField(speech.isRecording ? "Listening…" : "Message Sumi", text: $model.input, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
            Button(action: model.send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
            }
            .disabled(model.input.trimmingCharacters(in: .whitespaces).isEmpty || model.isResponding)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    // MARK: - Voice

    private func toggleListening() {
        if speech.isRecording {
            speech.stop()
            model.send()
        } else {
            startListening()
        }
    }

    /// Submits a query handed off from elsewhere (e.g. an onboarding starter).
    private func consumePendingQuery(_ query: String) {
        appState.pendingQuery = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.submit(trimmed)
    }

    private func startListening() {
        synthesizer.stop()
        inputFocused = false
        Task {
            await speech.requestAuthorization()
            guard speech.isAuthorized else { return }
            try? speech.start()
        }
    }

    private func speakLatestIfNeeded() {
        guard speakReplies, let last = model.messages.last, last.role == .sumi else { return }
        synthesizer.speak(last.text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if model.isResponding {
                proxy.scrollTo(Self.typingID, anchor: .bottom)
            } else if let last = model.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 44) }
            if message.role == .sumi {
                LivingLightOrb(size: 24)
            }
            Text(message.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .foregroundStyle(message.role == .user ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.primary))
            if message.role == .sumi { Spacer(minLength: 44) }
        }
    }

    private var background: Color {
        message.role == .user ? Color.primary : Color(.secondarySystemBackground)
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack {
            Text("Sumi is thinking…")
                .font(.callout).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 40)
        }
    }
}
