//
//  ComposePresentation.swift
//  sumi-ios
//
//  Shared helper for presenting system compose sheets (mail, messages, share).
//  Outbound actions ALWAYS go through a compose sheet the user confirms — Sumi
//  never sends mail or messages silently.
//

import UIKit

/// Locates the top-most view controller to present from.
@MainActor
enum ComposePresentation {
    /// The front-most presented view controller of the active key window, if any.
    static func topViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Presents `viewController` from the top-most controller. No-op if none found.
    static func present(_ viewController: UIViewController) {
        topViewController()?.present(viewController, animated: true)
    }
}
