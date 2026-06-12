//
//  IntentResponseBuilder.swift
//  sumi-ios
//
//  Every intent response is spoken by Siri, so it must be plain prose: no
//  markdown, no bullets, no headers, and short. This runs on every response
//  before it is returned.
//

import Foundation

enum IntentResponseBuilder {
    /// Maximum spoken sentences. Siri responses should be brief.
    static let maxSentences = 3

    /// Robotic lead-ins that read badly when spoken aloud.
    private static let roboticPrefixes = [
        "here is your summary:", "here's your summary:",
        "here is a summary:", "here's a summary:",
        "here is what i found:", "here's what i found:",
        "sure, here you go:", "sure!", "okay,", "ok,",
    ]

    /// Strips markdown, removes robotic lead-ins, and clamps to `maxSentences`.
    static func spoken(_ text: String) -> String {
        var result = stripMarkdown(text)
        result = removeRoboticPrefix(result)
        result = clampSentences(result, to: maxSentences)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Steps

    static func stripMarkdown(_ text: String) -> String {
        var s = text

        // Markdown links [label](url) -> label
        s = s.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        // Leading header / blockquote / list markers at the start of each line.
        s = s.replacingOccurrences(
            of: #"(?m)^\s*(#{1,6}\s+|>\s+|[-*+]\s+|\d+\.\s+)"#,
            with: "",
            options: .regularExpression
        )
        // Emphasis / code markers anywhere.
        for token in ["**", "__", "*", "_", "`", "~~", "#"] {
            s = s.replacingOccurrences(of: token, with: "")
        }
        // Collapse whitespace (including the newlines lists/headers left behind).
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removeRoboticPrefix(_ text: String) -> String {
        var s = text
        var changed = true
        while changed {
            changed = false
            let lower = s.lowercased()
            for prefix in roboticPrefixes where lower.hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                changed = true
                break
            }
        }
        return s
    }

    static func clampSentences(_ text: String, to limit: Int) -> String {
        guard limit > 0 else { return text }
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
                if sentences.count == limit { break }
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if sentences.count < limit, !tail.isEmpty { sentences.append(tail) }
        return sentences.joined(separator: " ")
    }
}
