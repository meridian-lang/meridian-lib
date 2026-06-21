import Foundation

// MARK: - DefinitionParser (2B)
//
// Parses a single checkable-adjective definition line:
//
//   Definition: a page is stale if it has no summary.
//   Definition: a pull request is mergeable if its checks are passing.
//
// The condition is expressed in terms of `it`/`its`, which are rewritten to the
// kind name (the subject) before the expression grammar runs, so the body reads
// as a predicate over the subject variable.

struct DefinitionParser {

    let lexicon: EnglishLexicon
    let symbols: SymbolTable?
    let trace: ParserTrace

    init(lexicon: EnglishLexicon = .default, symbols: SymbolTable? = nil, trace: ParserTrace = .shared) {
        self.lexicon = lexicon
        self.symbols = symbols
        self.trace = trace
    }

    /// True when `text` begins a definition (`Definition:` prefix).
    static func isDefinitionLine(_ text: String, lexicon: EnglishLexicon = .default) -> Bool {
        text.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .hasPrefix(lexicon.grammar.definitionPrefix)
    }

    /// Parse a `Definition:` line into a declaration, or nil when the shape is
    /// not recognised.
    func parse(_ rawLine: String, line: Int) -> DefinitionDeclaration? {
        var t = rawLine.trimmingCharacters(in: .whitespaces)
        guard t.lowercased().hasPrefix(lexicon.grammar.definitionPrefix) else { return nil }
        t = String(t.dropFirst(lexicon.grammar.definitionPrefix.count)).trimmingCharacters(in: .whitespaces)
        if t.hasSuffix(".") { t = String(t.dropLast()) }

        // Strip a leading article on the subject.
        t = lexicon.stripLeadingArticle(t)

        // Split on " if " (the condition introducer).
        guard let ifRange = t.range(of: lexicon.grammar.definitionIfMarker, options: .caseInsensitive) else { return nil }
        let head = String(t[t.startIndex..<ifRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let condition = String(t[ifRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Head: "<kind> is <adjective>".
        guard let isRange = head.range(of: lexicon.grammar.merconfig.isMarker, options: .caseInsensitive) else { return nil }
        // The ` is ` match requires a space on both sides and `head` is already
        // trimmed, so there is always ≥1 non-space char on each side — `kind` and
        // `adjectiveRaw` are therefore never empty here (no redundant guard).
        let kind = String(head[head.startIndex..<isRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let adjectiveRaw = String(head[isRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        let adjective = adjectiveRaw.lowercased().replacingOccurrences(of: "-", with: " ")
        let subjectVar = kind.lowercased()

        // Rewrite `it`/`its` to the subject before parsing.
        let bodyText = rewriteSubjectPronouns(condition, subject: subjectVar)
        let body = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon).parse(bodyText)

        return DefinitionDeclaration(
            adjective: adjective, kind: subjectVar, subjectVar: subjectVar,
            body: body, sourceLine: line
        )
    }

    /// Replace whole-word `its`→`<subject>'s` and `it`→`<subject>`.
    private func rewriteSubjectPronouns(_ s: String, subject: String) -> String {
        var out = WholeWordRegex.replace(s, of: lexicon.grammar.definitionPossessivePronoun, with: subject + "'s")
        out = WholeWordRegex.replace(out, of: lexicon.grammar.definitionSubjectPronoun, with: subject)
        return out
    }
}
