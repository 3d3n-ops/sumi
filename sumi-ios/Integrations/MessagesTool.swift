//
//  MessagesTool.swift
//  sumi-ios
//
//  Opens a pre-filled message compose sheet, or deep-links to a conversation.
//  Per the hard rule, messages are NEVER sent silently — the user confirms in
//  the system sheet.
//

import Foundation
import UIKit
import MessageUI

/// Drafts messages via the system compose sheet (user confirms send).
///
/// Not a `SumiTool` — it subclasses `NSObject` for the compose delegate (which
/// already defines `description`), so it stays a standalone main-actor helper.
@MainActor
final class MessagesTool: NSObject {
    /// Retains `self` while the compose sheet is on screen.
    private var presentationRetainer: MessagesTool?

    /// Whether this device can send texts.
    var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    /// Presents a pre-filled message compose sheet. No-op if the device can't text.
    func draft(to recipient: String, body: String) {
        guard MFMessageComposeViewController.canSendText() else { return }
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = [recipient]
        composer.body = body
        presentationRetainer = self
        ComposePresentation.present(composer)
    }

    /// Opens the Messages app to a conversation with `recipient` via the `sms:` scheme.
    func openConversation(with recipient: String) {
        let allowed = recipient.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? recipient
        guard let url = URL(string: "sms:\(allowed)") else { return }
        UIApplication.shared.open(url)
    }
}

extension MessagesTool: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
        presentationRetainer = nil
    }
}
