import Foundation
import MeridianRuntime

@available(*, deprecated, message: "Use Diagnostic from MeridianLinter.lint(source:file:) instead.")
public struct LintDiagnostic: Sendable, Equatable {
    public let line: Int
    public let severity: String
    public let code: DiagnosticCode?
    public let message: String
    public let hint: String?

    public init(line: Int, severity: String, code: DiagnosticCode? = nil, message: String, hint: String? = nil) {
        self.line = line
        self.severity = severity
        self.code = code
        self.message = message
        self.hint = hint
    }

    public init(_ diagnostic: Diagnostic) {
        self.line = diagnostic.primaryRange.startLine
        self.severity = diagnostic.severity.rawValue
        self.code = diagnostic.code
        self.message = diagnostic.message
        self.hint = diagnostic.help
    }
}

public struct MeridianLinter {
    private let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    public func lint(source: String, file: String = "") -> [Diagnostic] {
        let lines = IndentTokenizer().tokenize(source, file: file).filter(\.isContent)
        var diagnostics: [Diagnostic] = []
        var referents: [String] = []
        let resolver = AnaphoraResolver(lexicon: lexicon)

        for line in lines where line.headingLevel == nil {
            let statement = line.statement
            if (try? resolver.resolve(statement, referents: referents, file: file, line: line.number)) == nil,
               containsAnaphora(statement) {
                diagnostics.append(Diagnostic.error(
                    .ambiguousAnaphora,
                    message: "ambiguous reference in `\(statement)`",
                    range: line.statementRange(file: file),
                    help: "Spell out the target noun or bind the value immediately before this line."
                ))
            }
            if let hint = paraphraseHint(for: statement) {
                diagnostics.append(Diagnostic.warning(
                    hint.code,
                    message: hint.title,
                    range: line.range(file: file, of: hint.marker),
                    help: hint.message
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

    @available(*, deprecated, message: "Use lint(source:file:) returning [Diagnostic].")
    public func lintLegacy(source: String, file: String = "") -> [LintDiagnostic] {
        lint(source: source, file: file).map(LintDiagnostic.init)
    }

    private func containsAnaphora(_ text: String) -> Bool {
        lexicon.anaphoraMarkers.contains { WholeWordRegex.contains($0, in: text) }
    }

    private func paraphraseHint(for statement: String) -> (code: DiagnosticCode, title: String, marker: String, message: String)? {
        let lower = statement.lowercased()
        if let marker = lexicon.grammar.lintMarkers.politenessPrefixes.first(where: { lower.hasPrefix($0) }) {
            return (.lintPoliteCommand, "polite command wording", marker.trimmingCharacters(in: .whitespaces), "Drop `please`; Meridian treats commands as workflow steps.")
        }
        if let marker = lexicon.grammar.lintMarkers.uncertaintyMarkers.first(where: { lower.contains($0) || lower.hasPrefix($0) }) {
            return (.lintUncertainty, "uncertainty wording", marker.trimmingCharacters(in: .whitespaces), "Use `with discretion` for planner judgment, or spell a deterministic condition with `only when` / `unless`.")
        }
        return nil
    }

    private func camelize(_ raw: String) -> String { IdentifierNaming.lowerCamel(raw) }
}
