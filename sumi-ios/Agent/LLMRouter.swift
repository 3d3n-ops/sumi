//
//  LLMRouter.swift
//  sumi-ios
//
//  Single entry point for every LLM call. Decides on-device vs cloud, assembles
//  the prompt with memory context, and produces spoken-quality output only.
//

import Foundation

/// Where a given request should be served.
enum RouteType: Equatable {
    /// Apple on-device model (fast, free) — simple recall / short responses.
    case onDevice
    /// Claude Sonnet via the Worker — complex reasoning / drafting.
    case cloudSonnet
    /// Claude vision via the Worker — anything involving an image.
    case cloudVision
}

/// Routes requests between the on-device model and the cloud (Worker) backends.
///
/// Per the hard rules, every LLM call in the app goes through this actor. Output
/// is always spoken-quality: conversational, short, no markdown or bullets.
actor LLMRouter {
    /// Model id for the cloud reasoning path (matches CLAUDE.md).
    static let sonnetModel = "claude-sonnet-4-6"

    private let onDevice: any OnDeviceModel
    private let worker: CloudflareWorkerClient

    init(
        onDevice: any OnDeviceModel = FoundationModelsSession(),
        worker: CloudflareWorkerClient = CloudflareWorkerClient()
    ) {
        self.onDevice = onDevice
        self.worker = worker
    }

    /// Pure routing decision. `complexity` is a 0...1 estimate of reasoning effort.
    nonisolated func route(query: String, hasImage: Bool, complexity: Double) -> RouteType {
        if hasImage { return .cloudVision }
        if complexity < 0.4 { return .onDevice }
        return .cloudSonnet
    }

    /// Assembles a prompt from `query` + memory `context`, routes it, and returns
    /// spoken-quality text. Never throws — degrades to a short spoken fallback so
    /// callers (notifications, intents) never crash.
    ///
    /// `context` is read on the main actor (MemoryEntry is a SwiftData model and
    /// not Sendable) before any cross-actor work happens.
    func respond(query: String, context: [MemoryEntry], image: Data? = nil) async -> String {
        // MemoryEntry is a non-Sendable SwiftData model: read its content on the
        // main actor and hand the actor only the resulting strings.
        let contextLines = await MainActor.run {
            context.prefix(5).map { $0.content }
        }
        return await respond(query: query, contextStrings: contextLines, image: image)
    }

    /// Variant taking already-extracted, `Sendable` context strings. App Intents
    /// resolve `MemoryEntry.content` on the main actor first, then call this to
    /// stay within strict concurrency.
    func respond(query: String, contextStrings: [String], image: Data? = nil) async -> String {
        let complexity = Self.estimateComplexity(query: query, contextCount: contextStrings.count)
        let routeType = route(query: query, hasImage: image != nil, complexity: complexity)

        switch routeType {
        case .onDevice:
            return await onDeviceResponse(query: query, context: contextStrings)
        case .cloudSonnet:
            return await sonnetResponse(query: query, context: contextStrings)
        case .cloudVision:
            return await visionResponse(query: query, context: contextStrings, image: image)
        }
    }

    // MARK: - Backends

    private func onDeviceResponse(query: String, context: [String]) async -> String {
        let prompt = Self.assemblePrompt(query: query, context: context)
        if await onDevice.isAvailable, let reply = await onDevice.respond(to: prompt) {
            return reply
        }
        // On-device unavailable / declined — fall back to the cloud reasoning path.
        return await sonnetResponse(query: query, context: context)
    }

    private func sonnetResponse(query: String, context: [String]) async -> String {
        let messages = Self.assembleMessages(query: query, context: context)
        do {
            return try await worker.completions(messages: messages, model: Self.sonnetModel)
        } catch {
            return Self.fallback
        }
    }

    private func visionResponse(query: String, context: [String], image: Data?) async -> String {
        guard let image else {
            return await sonnetResponse(query: query, context: context)
        }
        let prompt = Self.assemblePrompt(query: query, context: context)
        do {
            return try await worker.vision(imageBase64: image.base64EncodedString(), prompt: prompt)
        } catch {
            return Self.fallback
        }
    }

    // MARK: - Prompt assembly

    /// Spoken-quality system guidance for Siri intents (terse, no markdown).
    static let systemGuidance =
        "You are Sumi, a personal assistant. Reply in one or two short spoken sentences. " +
        "No markdown, no bullets, no headers. Be conversational and concise."

    /// Conversational guidance for the in-app chat surface — fuller than the
    /// spoken style, but still plain text (the chat renders plain strings).
    static let conversationalGuidance =
        "You are Sumi, a warm, concise personal assistant having a chat with the user. " +
        "Answer helpfully in a few short sentences. Use the user's remembered context when relevant. " +
        "Reply in plain conversational text — no markdown headers, tables, or bullet lists."

    static let fallback = "I couldn't reach my assistant just now. I'll try again shortly."

    /// In-app chat reply. Richer than `respond` (which is tuned for spoken Siri
    /// output): prefers the cloud reasoning path, falls back to on-device, and
    /// never throws so the chat UI degrades gracefully.
    func converse(query: String, context: [String]) async -> String {
        let messages = Self.assembleMessages(query: query, context: context, guidance: Self.conversationalGuidance)
        do {
            return try await worker.completions(messages: messages, model: Self.sonnetModel)
        } catch {
            // Worker failed — try on-device before giving up.
            let prompt = Self.assemblePrompt(query: query, context: context, guidance: Self.conversationalGuidance)
            if await onDevice.isAvailable, let reply = await onDevice.respond(to: prompt) {
                return reply
            }
            return Self.fallback(for: error)
        }
    }

    /// Diagnostic fallback for the chat surface: names the concrete failure so it
    /// can be seen on-device (TestFlight) without attaching a debugger.
    static func fallback(for error: Error) -> String {
        let reason: String
        switch error as? SumiError {
        case .noWorkerURL: reason = "no Worker URL is configured"
        case .invalidWorkerURL: reason = "the Worker URL is invalid"
        case .workerHTTPStatus(let code): reason = "the server returned \(code)"
        case .malformedResponse: reason = "the response couldn't be read"
        case .onDeviceModelUnavailable, .none: reason = (error as NSError).localizedDescription
        }
        return "I couldn't reach my assistant just now (\(reason)). I'll try again shortly."
    }

    /// Raw completion for internal, structured use (e.g. JSON extraction). Unlike
    /// `respond`/`converse`, this imposes no spoken-quality guidance — the caller
    /// supplies the full system + user prompt. Prefers the on-device model (free),
    /// falls back to the cloud reasoning path, and returns `nil` if both fail.
    func complete(system: String, user: String) async -> String? {
        if await onDevice.isAvailable, let reply = await onDevice.respond(to: system + "\n\n" + user) {
            return reply
        }
        let messages = [
            ["role": "system", "content": system],
            ["role": "user", "content": user],
        ]
        return try? await worker.completions(messages: messages, model: Self.sonnetModel)
    }

    static func assemblePrompt(query: String, context: [String], guidance: String = systemGuidance) -> String {
        var parts: [String] = [guidance]
        if !context.isEmpty {
            parts.append("Here's what I remember: " + context.joined(separator: " "))
        }
        parts.append("Request: " + query)
        return parts.joined(separator: "\n")
    }

    static func assembleMessages(query: String, context: [String], guidance: String = systemGuidance) -> [[String: String]] {
        var messages: [[String: String]] = [
            ["role": "system", "content": guidance],
        ]
        if !context.isEmpty {
            messages.append([
                "role": "system",
                "content": "Relevant memory: " + context.joined(separator: " "),
            ])
        }
        messages.append(["role": "user", "content": query])
        return messages
    }

    /// Rough complexity heuristic for routing when a caller doesn't supply one.
    static func estimateComplexity(query: String, contextCount: Int) -> Double {
        let wordCount = query.split { $0 == " " }.count
        let lengthFactor = min(Double(wordCount) / 40.0, 1.0)
        let contextFactor = min(Double(contextCount) / 5.0, 1.0)
        return min(0.6 * lengthFactor + 0.4 * contextFactor, 1.0)
    }
}
