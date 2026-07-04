import Foundation

/// `quantifier` (`GrammarTable`, `.pegex` shell): `all`/`any`/`no`/`at least
/// N`/`at most N`/`exactly N` over a description, e.g. `no stale pages whose
/// status is draft`. The fixed determiner/partitive/`whose`-vs-body structure
/// is a marker-shape grammar; the noun/adjective head resolution is delegated
/// to `DescriptionGrammar.splitAdjectivesAndNoun`, the same symbol-table
/// closure `description`/`aggregate`/`superlative` share.
struct QuantifierGrammar {
    let lexicon: EnglishLexicon
    let description: DescriptionGrammar
    /// Recurses the full grammar for the `whose` predicate and per-element body.
    let recurse: (String) -> ExpressionAST

    func parse(_ s: String) -> ExpressionAST? {
        guard let (kind, rest0) = matchDeterminer(s) else { return nil }
        var rest = rest0.trimmingCharacters(in: .whitespaces)
        for p in lexicon.grammar.quantifierPartitiveMarkers where rest.lowercased().hasPrefix(p) {
            rest = String(rest.dropFirst(p.count)); break
        }
        rest = lexicon.stripLeadingArticle(rest)
        guard !rest.isEmpty else {
            return .malformed("quantifier \"\(s)\" is missing a description (e.g. `all pages`).")
        }

        let (descText, whereText, bodyText) = splitDescriptionAndBody(rest)
        guard !descText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .malformed("quantifier \"\(s)\" has no collection noun.")
        }
        if let whereText, whereText.isEmpty {
            return .malformed("quantifier \"\(s)\" has a `whose` clause with no condition.")
        }
        let (adjectives, noun) = description.splitAdjectivesAndNoun(descText)
        let wherePred = whereText.map { recurse($0) }
        var body: ExpressionAST?
        if let b = bodyText {
            let elementVar = lexicon.singularize(noun.lowercased())
            body = recurse(elementVar + " " + normalizeQuantBody(b))
        }
        let desc = DescriptionAST(noun: noun, adjectives: adjectives, wherePredicate: wherePred)
        return .quantified(QuantifierAST(kind: kind, description: desc, body: body))
    }

    /// Match a leading quantifier determiner; return the kind and the remainder.
    private func matchDeterminer(_ s: String) -> (QuantifierKindAST, String)? {
        let lower = s.lowercased()
        func after(_ prefix: String) -> String { String(s.dropFirst(prefix.count)) }
        let determiners = lexicon.grammar.quantifierDeterminers
        for marker in determiners.all where lower.hasPrefix(marker) { return (.all, after(marker)) }
        for marker in determiners.any where lower.hasPrefix(marker) { return (.any, after(marker)) }
        for marker in determiners.none where lower.hasPrefix(marker) { return (.none, after(marker)) }
        for (kw, make): (String, (Int) -> QuantifierKindAST) in
            [
                (determiners.atLeastPrefix, { .atLeast($0) }),
                (determiners.atMostPrefix, { .atMost($0) }),
                (determiners.exactlyPrefix, { .exactly($0) }),
            ] {
            if lower.hasPrefix(kw) {
                let tail = after(kw).trimmingCharacters(in: .whitespaces)
                let parts = tail.split(separator: " ", maxSplits: 1).map(String.init)
                if let first = parts.first, let n = Int(first) {
                    return (make(n), parts.count > 1 ? parts[1] : "")
                }
            }
        }
        return nil
    }

    /// Split a quantifier remainder into (descriptionText, whereText, bodyText).
    /// `whose …` introduces a where-predicate; a copular/possessive verb
    /// (`have`/`has`/`are`/`is`/`contain`/`include`) introduces a per-element
    /// body (kept verbatim from the verb onward).
    private func splitDescriptionAndBody(_ s: String) -> (desc: String, whereText: String?, body: String?) {
        if let wr = whoseMarkerRange(in: s) {
            let desc = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            let cond = String(s[wr.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (desc, cond, nil)
        }
        var earliest: Range<String.Index>?
        for v in lexicon.grammar.quantifierBodyVerbs {
            if let r = QuoteAwareScanner.rangeOfMarker(v, in: s, caseInsensitive: true) {
                if earliest == nil || r.lowerBound < earliest!.lowerBound { earliest = r }
            }
        }
        if let r = earliest {
            let desc = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let body = String(s[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
            return (desc, nil, body)
        }
        return (s.trimmingCharacters(in: .whitespaces), nil, nil)
    }

    /// Normalise a plural quantifier body verb to its singular element form so
    /// a synthesised `<element> <body>` re-parses cleanly.
    private func normalizeQuantBody(_ b: String) -> String {
        let parts = b.split(separator: " ", maxSplits: 1).map(String.init)
        guard let verb = parts.first else { return b }
        let rest = parts.count > 1 ? " " + parts[1] : ""
        if let singular = lexicon.grammar.quantifierBodyNormalization[verb.lowercased()] {
            return singular + rest
        }
        return b
    }

    private func whoseMarkerRange(in s: String) -> Range<String.Index>? {
        let marker = lexicon.grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces)
        var search = s.startIndex
        while search < s.endIndex {
            let slice = String(s[search...])
            guard let range = QuoteAwareScanner.rangeOfMarker(marker, in: slice, caseInsensitive: true) else {
                break
            }
            let lowerOffset = slice.distance(from: slice.startIndex, to: range.lowerBound)
            let lower = s.index(search, offsetBy: lowerOffset)
            let upper = s.index(lower, offsetBy: marker.count)
            let leftOK = lower == s.startIndex || !isWordCharacter(s[s.index(before: lower)])
            let rightOK = upper == s.endIndex || !isWordCharacter(s[upper])
            if leftOK, rightOK {
                return lower..<upper
            }
            search = upper
        }
        return nil
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
