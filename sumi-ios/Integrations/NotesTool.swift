//
//  NotesTool.swift
//  sumi-ios
//
//  Hands note content to the system so the user can save it to Notes. iOS exposes
//  no public API to create or read Notes directly, so "create" presents a share
//  sheet (the user picks Notes / confirms) and "search" is unavailable.
//

import Foundation
import UIKit

/// Best-effort Notes integration via the system share sheet.
///
/// Not a `SumiTool` — it subclasses `NSObject`, which already defines
/// `description`, so it stays a standalone main-actor helper.
@MainActor
final class NotesTool: NSObject {
    /// Presents a share sheet pre-filled with the note so the user can save it to
    /// Notes (or anywhere). No-op if no presenter is available.
    func create(title: String, body: String) {
        let text = title.isEmpty ? body : "\(title)\n\n\(body)"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // On iPad, anchor the popover to avoid a crash on presentation.
        if let presenter = ComposePresentation.topViewController() {
            activity.popoverPresentationController?.sourceView = presenter.view
            activity.popoverPresentationController?.sourceRect = CGRect(
                x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
            )
            activity.popoverPresentationController?.permittedArrowDirections = []
        }
        ComposePresentation.present(activity)
    }

    /// Searching Notes is not possible — iOS exposes no public read API. Always
    /// returns an empty list; kept for interface completeness.
    func search(keyword: String) async -> [String] {
        []
    }
}
