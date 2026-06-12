//
//  WorkerConfig.swift
//  sumi-ios
//
//  Build-time Cloudflare Worker configuration.
//
//  The Worker URL is a public endpoint (NOT a secret), so it is safe to bake in
//  here — this is the production path (no per-device pasting). The shared secret
//  is deliberately NOT baked in: it's set per device via the Connection screen
//  and stored in the Keychain, so it never lands in source/git.
//

import Foundation

enum WorkerConfig {
    /// Your deployed Worker base URL.
    ///
    /// After `wrangler deploy`, paste the printed `*.workers.dev` URL here, e.g.
    ///   static let defaultWorkerURL: String? = "https://sumi-worker.you.workers.dev"
    /// Leave `nil` to require configuration via the Connection screen instead.
    static let defaultWorkerURL: String? = "https://sumi-worker.edens-stuff.workers.dev"

    /// Effective Worker URL: a per-device Keychain override if present, else the
    /// baked-in default above.
    static func resolvedWorkerURL() -> String? {
        Keychain.string(for: Keychain.workerURLKey) ?? defaultWorkerURL
    }
}
