import Foundation

public struct LintDiagnostic: Sendable, Equatable {
    public let line: Int
    public let severity: String
    public let message: String
    public let hint: String?

    public init(line: Int, severity: String, message: String, hint: String? = nil) {
        self.line = line
        self.severity = severity
        self.message = message
        self.hint = hint
    }
}

public struct MeridianLinter {
    private let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    public func lint(source: String, file: String = "") -> [LintDiagnostic] {
        let lines = IndentTokenizer().tokenize(source, file: file).filter(\.isContent)
        var diagnostics: [LintDiagnostic] = []
        var referents: [String] = []
        let resolver = AnaphoraResolver(lexicon: lexicon)

        for line in lines where line.headingLevel == nil {
            let statement = line.statement
            if (try? resolver.resolve(statement, referents: referents, file: file, line: line.number)) == nil,
               containsAnaphora(statement) {
                diagnostics.append(LintDiagnostic(
                    line: line.number,
                    severity: "error",
                    message: "Ambiguous reference in `\(statement)`",
                    hint: "Spell out the target noun or bind the value immediately before this line."
                ))
            }
            if let hint = paraphraseHint(for: statement) {
                diagnostics.append(LintDiagnostic(
                    line: line.number,
                    severity: "info",
                    message: "Supported paraphrase available",
                    hint: hint
                ))
            }
            let bindPrefix = lexicon.grammar.statement.bindPrefix
            if statement.lowercased().hasPrefix(bindPrefix) {
                let rest = String(statement.dropFirst(bindPrefix.count))
                if let eq = rest.range(of: " = ") {
                    referents.append(camelize(String(rest[..<eq.lowerBound])))
                    if referents.count > 4 { referents = Array(referents.suffix(4)) }
                }
            }
        }
        return diagnostics
    }

    private func containsAnaphora(_ text: String) -> Bool {
        lexicon.anaphoraMarkers.contains { WholeWordRegex.contains($0, in: text) }
    }

    private func paraphraseHint(for statement: String) -> String? {
        let lower = statement.lowercased()
        if lexicon.grammar.lintMarkers.politenessPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return "Drop `please`; Meridian treats commands as workflow steps."
        }
        if lexicon.grammar.lintMarkers.uncertaintyMarkers.contains(where: { lower.contains($0) || lower.hasPrefix($0) }) {
            return "Use `with discretion` for planner judgment, or spell a deterministic condition with `only when` / `unless`."
        }
        return nil
    }

    private func camelize(_ raw: String) -> String { IdentifierNaming.lowerCamel(raw) }
}
