//
//  OnDeviceModel.swift
//  sumi-ios
//
//  Abstraction over Apple's on-device Foundation Models (iOS 26). The real API
//  surface is uncertain and is unavailable on CI simulators, so — mirroring the
//  `TextEmbedder` precedent — everything is hidden behind a small protocol with
//  a stub used in tests and a best-effort real implementation guarded by
//  availability + `canImport(FoundationModels)`.
//

import Foundation
import OSLog

/// A minimal on-device language model interface. The router uses this for the
/// fast / free path (simple recall, short responses).
protocol OnDeviceModel: Sendable {
    /// Whether the on-device model is usable on this device/runtime.
    var isAvailable: Bool { get async }

    /// Produces a short, spoken-quality completion for `prompt`, or `nil` when
    /// the model cannot answer (caller should then fall back to cloud).
    func respond(to prompt: String) async -> String?
}

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Best-effort real implementation backed by Apple's Foundation Models.
///
/// TODO: verify FoundationModels API on device. The exact type/method names for
/// the iOS 26 on-device model session are not verifiable on CI (the framework is
/// absent from the simulators used by GitHub Actions). This wrapper is written so
/// the build stays green regardless: when the framework is present and available,
/// it attempts a real session; otherwise it returns `nil` and the router falls
/// back to the cloud path.
struct FoundationModelsSession: OnDeviceModel {
    private let logger = Logger(subsystem: "Eden-Etuk.sumi-ios", category: "FoundationModelsSession")

    var isAvailable: Bool {
        get async {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                // TODO: verify FoundationModels API on device — replace with the
                // real availability probe (e.g. SystemLanguageModel.default state).
                return true
            }
            return false
            #else
            return false
            #endif
        }
    }

    func respond(to prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // TODO: verify FoundationModels API on device. Intended shape:
            //   let session = LanguageModelSession()
            //   let response = try await session.respond(to: prompt)
            //   return response.content
            // Kept as a guarded best-effort so an API mismatch cannot break CI.
            return await bestEffortRespond(to: prompt)
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func bestEffortRespond(to prompt: String) async -> String? {
        // Intentionally conservative: until the on-device API is verified on a
        // real iOS 26 device, return nil so the router routes to the cloud path
        // rather than risk an unverified call. Flip this to the real session call
        // once the API is confirmed.
        logger.debug("FoundationModels on-device path not yet verified; deferring to cloud.")
        return nil
    }
    #endif
}

/// Deterministic stub used in tests and as a safe default where the on-device
/// model is unavailable. Echoes a canned spoken-style answer.
struct StubOnDeviceModel: OnDeviceModel {
    /// When `false`, simulates an unavailable model (returns nil from `respond`).
    let available: Bool
    /// Fixed reply to return; defaults to a short spoken-style acknowledgement.
    let cannedReply: String?

    init(available: Bool = true, cannedReply: String? = "Got it.") {
        self.available = available
        self.cannedReply = cannedReply
    }

    var isAvailable: Bool { get async { available } }

    func respond(to prompt: String) async -> String? {
        guard available else { return nil }
        return cannedReply
    }
}
