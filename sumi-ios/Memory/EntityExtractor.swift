//
//  EntityExtractor.swift
//  sumi-ios
//
//  Named-entity and keyword extraction for memory writes.
//

import Foundation
import NaturalLanguage

/// Extracts people, places, organizations, and topical keywords from text.
struct EntityExtractor {
    func extract(from text: String) async -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        func append(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { return }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            results.append(trimmed)
        }

        let nameTagger = NLTagger(tagSchemes: [.nameType])
        nameTagger.string = text
        let nameOptions: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        nameTagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: nameOptions
        ) { tag, range in
            guard let tag else { return true }
            switch tag {
            case .personalName, .placeName, .organizationName:
                append(String(text[range]))
            default:
                break
            }
            return true
        }

        let lexicalTagger = NLTagger(tagSchemes: [.lexicalClass])
        lexicalTagger.string = text
        lexicalTagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            guard tag == .noun else { return true }
            let token = String(text[range])
            guard !Self.stopWords.contains(token.lowercased()) else { return true }
            if token.first?.isUppercase == true || token.count >= 5 {
                append(token)
            }
            return true
        }

        appendProjectPhrases(from: text, append: append)

        return results
    }

    private func appendProjectPhrases(from text: String, append: (String) -> Void) {
        let pattern = #"\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let swiftRange = Range(match.range, in: text) else { return }
            append(String(text[swiftRange]))
        }
    }

    private static let stopWords: Set<String> = [
        "about", "after", "also", "been", "being", "could", "from", "have",
        "into", "just", "like", "more", "some", "than", "that", "their",
        "them", "then", "there", "these", "they", "this", "those", "very",
        "what", "when", "where", "which", "while", "with", "would", "your",
    ]
}
