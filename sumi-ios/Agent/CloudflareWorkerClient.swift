//
//  CloudflareWorkerClient.swift
//  sumi-ios
//
//  All cloud LLM calls are proxied through a Cloudflare Worker. The Worker base
//  URL is read from the Keychain (never embedded, never in UserDefaults). The API
//  key lives only inside the Worker — this client never sees it.
//

import Foundation

/// Abstraction over the actual HTTP transport so tests inject a fake and never
/// hit the network — mirroring the `TextEmbedder` precedent in the Memory layer.
protocol WorkerTransport: Sendable {
    /// Performs the request and returns the response body data and HTTP status.
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

/// Production transport backed by `URLSession` with a 30s timeout.
struct URLSessionWorkerTransport: WorkerTransport {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}

/// Reads the Worker URL from the Keychain; returns `nil` when absent so callers
/// can throw `SumiError.noWorkerURL` instead of crashing.
protocol WorkerURLProviding: Sendable {
    func workerURL() -> String?
    /// Shared bearer secret sent as `Authorization`. Defaults to `nil` (no auth).
    func workerSecret() -> String?
}

extension WorkerURLProviding {
    func workerSecret() -> String? { nil }
}

/// Default provider backed by the Keychain.
struct KeychainWorkerURLProvider: WorkerURLProviding {
    func workerURL() -> String? {
        Keychain.string(for: Keychain.workerURLKey)
    }

    func workerSecret() -> String? {
        Keychain.string(for: Keychain.workerSecretKey)
    }
}

/// Actor that proxies completion and vision requests through the Cloudflare Worker.
///
/// The Worker is expected to expose `/completions` and `/vision` endpoints that
/// accept JSON and return `{ "text": "..." }`. Errors are thrown as `SumiError`
/// so the rest of the app can degrade gracefully.
actor CloudflareWorkerClient {
    private let transport: any WorkerTransport
    private let urlProvider: any WorkerURLProviding

    init(
        transport: any WorkerTransport = URLSessionWorkerTransport(),
        urlProvider: any WorkerURLProviding = KeychainWorkerURLProvider()
    ) {
        self.transport = transport
        self.urlProvider = urlProvider
    }

    /// Sends a chat-style completion request. `messages` are `[["role": ..., "content": ...]]`.
    func completions(messages: [[String: String]], model: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
        ]
        return try await post(path: "completions", body: body)
    }

    /// Sends a single-image vision request with a text prompt.
    func vision(imageBase64: String, prompt: String) async throws -> String {
        let body: [String: Any] = [
            "image": imageBase64,
            "prompt": prompt,
        ]
        return try await post(path: "vision", body: body)
    }

    // MARK: - Internal

    private func post(path: String, body: [String: Any]) async throws -> String {
        guard let base = urlProvider.workerURL() else {
            throw SumiError.noWorkerURL
        }
        guard let baseURL = URL(string: base) else {
            throw SumiError.invalidWorkerURL
        }

        let endpoint = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret = urlProvider.workerSecret() {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status) else {
            throw SumiError.workerHTTPStatus(status)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String else {
            throw SumiError.malformedResponse
        }
        return text
    }
}
