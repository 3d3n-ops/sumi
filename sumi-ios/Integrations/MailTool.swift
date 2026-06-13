//
//  MailTool.swift
//  sumi-ios
//
//  Opens a pre-filled mail compose sheet. Per the hard rule, mail is NEVER sent
//  silently — the user reviews and sends from the system sheet. There is no public
//  API to read the user's mail, so thread summarization is limited to text the
//  caller already has.
//

import Foundation
import UIKit
import MessageUI

/// Drafts mail via the system compose sheet (user confirms send).
///
/// Not a `SumiTool` — it subclasses `NSObject` for the compose delegate, which
/// already defines `description`, so it stays a standalone main-actor helper.
@MainActor
final class MailTool: NSObject {
    /// Optional summarizer for thread text the caller supplies (e.g. pasted content).
    private let summarizer: (any ThreadSummarizing)?
    /// Retains `self` while a compose sheet is on screen (the delegate must outlive present).
    private var presentationRetainer: MailTool?

    init(summarizer: (any ThreadSummarizing)? = nil) {
        self.summarizer = summarizer
    }

    /// Whether this device can send mail (no account configured ⇒ false).
    var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    /// Presents a pre-filled compose sheet. No-op if the device can't send mail.
    func draftReply(to recipient: String, subject: String, body: String) {
        guard MFMailComposeViewController.canSendMail() else { return }
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        presentationRetainer = self
        ComposePresentation.present(composer)
    }

    /// Summarizes thread text the caller already has (Sumi can't read Mail itself).
    /// Returns a clear note when no summarizer or text is available.
    func recentThreadSummary(from threadText: String) async -> String {
        let trimmed = threadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let summarizer, !trimmed.isEmpty else {
            return "I can't read your mailbox, so I can only summarize text you share with me."
        }
        return await summarizer.summarizeThread(trimmed)
    }
}

extension MailTool: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
        presentationRetainer = nil
    }
}

/// Summarizes thread text. `LLMRouter` is the production conformer.
protocol ThreadSummarizing: Sendable {
    func summarizeThread(_ text: String) async -> String
}

extension LLMRouter: ThreadSummarizing {
    func summarizeThread(_ text: String) async -> String {
        await respond(query: "Summarize this email thread in one or two spoken sentences:\n\(text)", context: [], image: nil)
    }
}
