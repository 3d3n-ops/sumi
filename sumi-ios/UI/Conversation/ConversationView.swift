//
//  ConversationView.swift
//  sumi-ios
//
//  The in-app chat surface — a ChatGPT-style transcript with a text composer.
//  Voice input is added in Phase 2.
//

import SwiftUI
import UIKit

struct ConversationView: View {
    @State private var model = ConversationViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty {
                            emptyState
                        }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                        if model.isResponding {
                            TypingIndicator().id(Self.typingID)
                        }
                    }
                    .padding()
                }
                .onChange(of: model.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: model.isResponding) { _, _ in scrollToBottom(proxy) }
            }
            composer
        }
    }

    private static let typingID = "typing-indicator"

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 40))
            Text("Talk to Sumi").font(.title3.weight(.semibold))
            Text("Ask anything, or just say what's on your mind.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Sumi", text: $model.input, axis: .vertical)
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
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            if message.role == .sumi { Spacer(minLength: 40) }
        }
    }

    private var background: Color {
        message.role == .user ? .accentColor : Color(.secondarySystemBackground)
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
