//
//  CommitmentExtractor.swift
//  sumi-ios
//
//  Mines commitments ("I'll send Sarah the deck") out of free text. Extraction
//  goes through the LLMRouter per the hard rule that all LLM calls are routed —
//  it prefers the on-device model and falls back to the cloud reasoning path.
//

import Foundation

/// LLM dependency for commitment extraction. `LLMRouter` is the production
/// conformer; tests inject a fake so extraction needs no network or on-device model.
protocol CommitmentExtracting: Sendable {
    /// Returns the raw model output (expected: a JSON array), or `nil` on failure.
    func extractCommitmentsJSON(from text: String) async -> String?
}

extension LLMRouter: CommitmentExtracting {
    func extractCommitmentsJSON(from text: String) async -> String? {
        await complete(system: CommitmentExtractor.systemPrompt, user: text)
    }
}

/// Extracts structured `Commitment` values from natural-language text.
actor CommitmentExtractor {
    private let llm: any CommitmentExtracting

    init(llm: any CommitmentExtracting) {
        self.llm = llm
    }

    /// JSON-only extraction prompt. Deliberately strict about output shape so the
    /// response parses regardless of which backend (on-device vs cloud) answers.
    static let systemPrompt = """
    Extract concrete commitments the user made — promises or intentions to do \
    something, e.g. "I'll send Sarah the deck", "I need to call the dentist", \
    "remind me to renew the lease". Ignore questions, opinions, and things already \
    done. Respond with ONLY a JSON array and no other text. Each element is an \
    object: {"text": "<short imperative summary>", "targetPerson": "<name or null>", \
    "dueHint": "<ISO-8601 datetime or null>"}. If there are no commitments, respond \
    with exactly [].
    """

    /// Extracts commitments from `text`. Returns an empty array when there are
    /// none or when the model output can't be parsed — never throws.
    func extract(from text: String) async -> [Commitment] {
        guard let raw = await llm.extractCommitmentsJSON(from: text),
              let json = Self.extractJSONArray(from: raw),
              let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([CommitmentDTO].self, from: data) else {
            return []
        }

        let now = Date.now
        let iso = ISO8601DateFormatter()
        return dtos.compactMap { dto -> Commitment? in
            let trimmed = dto.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Commitment(
                text: trimmed,
                extractedFrom: text,
                createdAt: now,
                targetPerson: dto.targetPerson?.nonEmptyTrimmed,
                dueHint: dto.dueHint.flatMap { iso.date(from: $0) },
                isResolved: false
            )
        }
    }

    /// Pulls the first JSON array out of a response that may wrap it in prose or
    /// code fences (`[ ... ]`). Returns `nil` if no array-shaped span is present.
    static func extractJSONArray(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "["),
              let end = raw.lastIndex(of: "]"),
              start < end else {
            return nil
        }
        return String(raw[start...end])
    }
}

/// Wire shape of one extracted commitment, decoded from the model's JSON.
private struct CommitmentDTO: Decodable {
    let text: String
    let targetPerson: String?
    let dueHint: String?
}

private extension String {
    /// Trimmed value, or `nil` if empty after trimming.
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
