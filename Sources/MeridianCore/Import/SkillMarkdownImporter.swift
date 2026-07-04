import Foundation

public struct SkillMarkdownImporter {
    private let trace: ParserTrace

    public init(trace: ParserTrace = .shared) {
        self.trace = trace
    }

    public func preview(_ markdown: String, name: String = "imported skill") -> String {
        trace.log(.skill, "preview \"\(name)\": \(markdown.components(separatedBy: "\n").count) source line(s)")
        var output: [String] = [
            "---",
            "name: \(name)",
            "description: Imported from SKILL.md preview.",
            "---",
            ""
        ]
        var inFence = false
        var fenceLanguage = ""
        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inFence {
                    inFence = false
                    fenceLanguage = ""
                } else {
                    inFence = true
                    fenceLanguage = String(trimmed.dropFirst(3)).lowercased()
                }
                continue
            }
            if inFence {
                if fenceLanguage == "meridian" || fenceLanguage.isEmpty {
                    output.append(raw)
                }
                continue
            }
            if trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") {
                output.append(trimmed)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                output.append(trimmed)
            } else if !trimmed.isEmpty, !trimmed.hasPrefix("#") {
                output.append("- \(trimmed)")
            }
        }
        return output.joined(separator: "\n")
    }
}
