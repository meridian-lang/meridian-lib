import Foundation
import MeridianCore
import MeridianRuntime
import MeridianTools

public enum SkillMigratorLLMRepair {
    public struct Options: Sendable {
        public var dryRun: Bool
        public var model: String?

        public init(dryRun: Bool = false, model: String? = nil) {
            self.dryRun = dryRun
            self.model = model
        }
    }

    public static func makeClosure(options: Options) -> (@Sendable (SkillMigrator.RepairRequest) async throws -> String)? {
        { request in
            let provider: any LLMProvider
            if let model = options.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                guard let config = LLMEnvironment.configuration() else {
                    throw LLMProviderError.notConfigured
                }
                provider = HTTPLLMProvider(config: LLMEnvironment.Configuration(
                    apiURL: config.apiURL, apiKey: config.apiKey, model: model))
            } else {
                provider = try LLMProviderRegistry.resolve(requireConfigured: true)
            }

            let flaggedLine = extractFlaggedLine(from: request.candidate, diagnostic: request.diagnostic)
            let prompt = repairPrompt(candidate: request.candidate,
                                      diagnostic: request.diagnostic,
                                      flaggedLine: flaggedLine,
                                      attempt: request.attempt)
            let response = try await provider.complete(LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: """
                    You rewrite one Meridian (.meri) source line so strict compilation succeeds.
                    Return ONLY the replacement text for MERIDIAN_REPAIR_LINE — no markdown fences,
                    no commentary. Allowed fixes: rephrase into lowerable Meridian syntax, or wrap
                    genuine judgment prose in `use judgment to <goal>:` with the original body indented.
                    """),
                    LLMMessage(role: .user, content: prompt),
                ],
                temperature: 0,
                responseFormat: .text
            ))
            let rewrite = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rewrite.isEmpty else {
                throw LLMProviderError.decode("repair response was empty")
            }

            if options.dryRun {
                print("repair proposal (attempt \(request.attempt)):")
                print("  diagnostic: \(request.diagnostic)")
                if let flaggedLine, !flaggedLine.isEmpty {
                    print("  authored: \(flaggedLine)")
                }
                print("  proposed: \(rewrite)")
                return request.candidate
            }

            guard let flaggedLine, !flaggedLine.isEmpty else {
                return request.candidate
            }
            return request.candidate.replacingOccurrences(of: flaggedLine, with: rewrite)
        }
    }

    static func repairPrompt(candidate: String, diagnostic: String, flaggedLine: String?, attempt: Int) -> String {
        let parts = [
            "MERIDIAN_REPAIR_LINE:",
            flaggedLine ?? "",
            "",
            "diagnostic:",
            diagnostic,
            "",
            "attempt: \(attempt)",
            "",
            "full candidate follows for context only — change ONLY MERIDIAN_REPAIR_LINE above:",
            candidate,
        ]
        return parts.joined(separator: "\n")
    }

    static func extractFlaggedLine(from candidate: String, diagnostic: String) -> String? {
        if let lineNumber = lineNumber(from: diagnostic) {
            let lines = candidate.components(separatedBy: "\n")
            let index = lineNumber - 1
            if lines.indices.contains(index) {
                let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { return line }
            }
        }
        return candidate.components(separatedBy: "\n").first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.hasPrefix("#")
                && !$0.hasPrefix(">")
                && !$0.hasPrefix("---")
                && !$0.hasPrefix("((")
        }?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func lineNumber(from diagnostic: String) -> Int? {
        let pattern = #"line\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: diagnostic, range: NSRange(diagnostic.startIndex..., in: diagnostic)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: diagnostic),
              let value = Int(diagnostic[range])
        else { return nil }
        return value
    }
}
