//
//  PushService.swift
//  sumi-ios
//
//  Uploads this device's APNs token to the Worker so the cron scheduler can
//  send the silent pushes that wake the proactive engine. Best-effort — any
//  failure is logged, never surfaced.
//

import Foundation
import OSLog

enum PushService {
    private static let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "PushService")

    /// Formats raw APNs token bytes as the lowercase hex string APNs expects.
    static func hexToken(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// POSTs the token to the Worker's `/register` endpoint. No-op when the
    /// Worker URL hasn't been configured yet.
    static func register(token: String) async {
        guard let base = WorkerConfig.resolvedWorkerURL(),
              let baseURL = URL(string: base) else {
            logger.debug("No worker URL configured; skipping token registration.")
            return
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret = Keychain.string(for: Keychain.workerSecretKey) {
            request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.debug("Token registration responded \(status, privacy: .public).")
        } catch {
            logger.error("Token registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
