//
//  SumiError.swift
//  sumi-ios
//
//  Shared error type for the agent / networking layer.
//

import Foundation

/// Errors surfaced by the agent and networking layers. These are intended to be
/// handled gracefully — never to crash the app.
enum SumiError: Error, Equatable {
    /// The Cloudflare Worker URL was not found in the Keychain.
    case noWorkerURL
    /// The Worker URL stored in the Keychain could not be parsed.
    case invalidWorkerURL
    /// The Worker returned a non-2xx HTTP status.
    case workerHTTPStatus(Int)
    /// The Worker response could not be decoded into the expected shape.
    case malformedResponse
    /// The on-device model is unavailable on this device/runtime.
    case onDeviceModelUnavailable
}
