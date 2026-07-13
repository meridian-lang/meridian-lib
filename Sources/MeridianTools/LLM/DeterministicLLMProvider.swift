import Foundation
import MeridianRuntime

/// Test-safe, deterministic LLM stand-in. Never performs network I/O.
public struct DeterministicLLMProvider: LLMProvider {
    public init() {}

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let user = request.messages.last(where: { $0.role == .user })?.content ?? ""
        let system = request.messages.last(where: { $0.role == .system })?.content ?? ""

        if system.localizedCaseInsensitiveContains("true or false") {
            let lower = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let answer = lower.contains("yes") || lower.contains("true") ? "true" : "false"
            return LLMResponse(text: answer, model: "deterministic")
        }

        if let rewritten = Self.extractRepairDirective(from: user) {
            return LLMResponse(text: rewritten, model: "deterministic")
        }

        if let proposal = Self.extractProposalDirective(from: user) {
            return LLMResponse(text: proposal, model: "deterministic")
        }

        switch request.responseFormat {
        case .jsonObject, .jsonSchema:
            return LLMResponse(text: "{}", model: "deterministic")
        case .text:
            return LLMResponse(text: user.isEmpty ? "ok" : user, model: "deterministic")
        }
    }

    private static func extractRepairDirective(from prompt: String) -> String? {
        guard prompt.contains("MERIDIAN_REPAIR_LINE") else { return nil }
        guard let range = prompt.range(of: "MERIDIAN_REPAIR_LINE:\n") else { return nil }
        let tail = String(prompt[range.upperBound...])
        let line = tail.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty else { return nil }
        if line.localizedCaseInsensitiveContains("ponder") {
            return """
            use judgment to act on the request:
              \(line)
            """
        }
        return line
    }

    private static func extractProposalDirective(from prompt: String) -> String? {
        guard prompt.contains("MERIDIAN_PROPOSE_LINE") else { return nil }
        guard let canonicalRange = prompt.range(of: "canonical:\n") else { return nil }
        let afterCanonical = String(prompt[canonicalRange.upperBound...])
        let canonical = afterCanonical.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return canonical.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
