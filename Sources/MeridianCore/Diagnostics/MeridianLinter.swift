import Foundation
import MeridianRuntime

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
            if let hint = crossRunInARowHint(for: statement) {
                diagnostics.append(Diagnostic.warning(
                    hint.code,
                    message: hint.title,
                    range: line.range(file: file, of: hint.marker),
                    help: hint.message
                ))
            }
            if let hint = superlativeEventAnchorHint(for: statement) {
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

    private func crossRunInARowHint(for statement: String) -> (code: DiagnosticCode, title: String, marker: String, message: String)? {
        let lower = statement.lowercased()
        let scopeMarker = lexicon.grammar.traceAcrossAllRunsMarker.trimmingCharacters(in: .whitespaces)
        let streakMarker = lexicon.grammar.traceInARowSuffix.trimmingCharacters(in: .whitespaces)
        guard lower.contains(scopeMarker), lower.contains(streakMarker) else { return nil }
        return (
            .lintCrossRunInARow,
            "cross-run `in a row` may surprise",
            scopeMarker,
            "`in a row` uses deterministic trace ordering; across all runs that order can include interleaved runs. If you meant a single run's streak, keep the current-run scope. If you meant aggregate recency, use `times within the last <duration>`."
        )
    }

    /// Composition Gallery line 4 (`since the last deploy of the most recent
    /// troubled service, …`): a superlative naming the anchor's subject is
    /// legal (it parses) but nests a collection-ranking computation inside an
    /// event pattern's anchor position, which is harder to read/debug from a
    /// trace than resolving the superlative to a named value first. Flag it
    /// as a two-step candidate rather than silently accepting it as idiomatic.
    private func superlativeEventAnchorHint(for statement: String) -> (code: DiagnosticCode, title: String, marker: String, message: String)? {
        let lower = statement.lowercased()
        let anchorMarker = lexicon.grammar.traceSinceLastAnchorFirstMarker.trimmingCharacters(in: .whitespaces)
        guard let anchorRange = lower.range(of: anchorMarker) else { return nil }
        let anchorSpan = lower[anchorRange.upperBound...]
        let anchorText = String(anchorSpan.prefix(while: { $0 != "," }))
        guard let gradable = lexicon.superlativeGradables.keys
            .sorted(by: { $0.count > $1.count })
            .first(where: { anchorText.contains($0) }) else { return nil }
        return (
            .lintSuperlativeEventAnchor,
            "superlative event-anchor wording",
            gradable,
            "The anchor names its subject with a superlative (`\(gradable) …`), ranking a collection inline inside the event pattern's anchor. Consider splitting into two steps: bind the superlative result first (`let the target be the \(gradable) …`), then anchor `since the last` on the bound name."
        )
    }

    private func camelize(_ raw: String) -> String { IdentifierNaming.lowerCamel(raw) }
}
