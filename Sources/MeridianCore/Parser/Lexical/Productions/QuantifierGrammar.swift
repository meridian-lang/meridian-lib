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

        let (descText, whereText, verbClause, bodyText) = splitDescriptionAndBody(rest)
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
        let desc = DescriptionAST(noun: noun, adjectives: adjectives, wherePredicate: wherePred,
                                  verbClauses: verbClause.map { [$0] } ?? [])
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

    /// Split a quantifier remainder into (descriptionText, whereText,
    /// verbClause, bodyText). `whose …` introduces a where-predicate; a `that
    /// <verb> …` relative clause or trailing `<participle> by <operand>`
    /// passive clause (3B, shared with `DescriptionGrammar`) restricts the
    /// description via a declared relation instead — this is how relation-
    /// backed conditions are expressed over a quantified collection (`no
    /// pages that mention the entity`, `any tasks assigned to the user`); a
    /// copular/possessive verb (`have`/`has`/`are`/`is`/`contain`/`include`)
    /// introduces a per-element body (kept verbatim from the verb onward).
    /// A `that`/`by` marker that does not resolve to a declared verb form is
    /// NOT an error here — it falls through so plain body/bare text
    /// containing those words still parses as before.
    private func splitDescriptionAndBody(_ s: String) -> (desc: String, whereText: String?, verbClause: VerbClauseAST?, body: String?) {
        if let wr = whoseMarkerRange(in: s) {
            let desc = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            let condFull = String(s[wr.upperBound...]).trimmingCharacters(in: .whitespaces)
            let (cond, bodyText) = splitWhoseTrailingBody(condFull)
            return (desc, cond, nil, bodyText)
        }
        if let sym = description.symbols {
            if let tr = lexicon.grammar.relativeClauseMarkers.lazy
                .compactMap({ QuoteAwareScanner.rangeOfMarker($0, in: s, caseInsensitive: true) }).first {
                // A verb clause can be followed by a per-element body on the
                // SAME quantifier (`services that the user owns are flaky`) —
                // split the body off *before* handing the clause text to
                // `parseThatClause`, or the copular verb ("are") and its
                // predicate get swallowed into the relative clause's operand.
                let (clauseText, bodyText) = earliestBodyVerbSplit(String(s[tr.upperBound...]))
                if let vc = description.parseThatClause(clauseText, symbols: sym) {
                    let desc = String(s[s.startIndex..<tr.lowerBound]).trimmingCharacters(in: .whitespaces)
                    return (desc, nil, vc, bodyText)
                }
            }
            // Same body-swallowing hazard for the passive `<participle> by
            // <operand>` suffix (`services owned by the user are flaky`).
            let (clauseHead, bodyText) = earliestBodyVerbSplit(s)
            var descPart = clauseHead
            if let vc = description.parsePassiveClauseSuffix(&descPart, symbols: sym) {
                return (descPart, nil, vc, bodyText)
            }
        }
        let (desc, body) = earliestBodyVerbSplit(s)
        return (desc, nil, nil, body)
    }

    /// A `whose <field> <op> <value>` clause can be followed by a SEPARATE
    /// per-element quantifier body using the same copular vocabulary the
    /// `whose` comparison itself is written with (`at least 1 critical alert
    /// whose service name is its name is fresh`: the whose-clause's own
    /// comparison is "service name is its name"; "is fresh" is a trailing
    /// body). A boolean connector means the whole thing is a compound
    /// where-predicate (`whose status is draft and priority is high`), not a
    /// body suffix, so that case is left alone.
    private func splitWhoseTrailingBody(_ cond: String) -> (cond: String, body: String?) {
        let connectors = [lexicon.grammar.booleanConnectors.andMarker, lexicon.grammar.booleanConnectors.orMarker]
        guard !connectors.contains(where: { QuoteAwareScanner.rangeOfMarker($0, in: cond, caseInsensitive: true) != nil })
        else { return (cond, nil) }
        // Preferred: the RHS of the whose-clause's own comparison is a
        // quoted string literal (`status is "pending"`) — the boundary right
        // after the closing quote is where a trailing body starts,
        // independent of which comparator word (`is`/`equals`) the
        // whose-clause itself happens to use (a verbalizer round trip may
        // choose a different one than the source did).
        if let split = splitAfterQuotedValue(cond) { return split }
        // Next preferred: the RHS is a short keyed reference (`its name`,
        // `the service's name`) — same rationale, non-literal RHS shape.
        if let split = splitAfterKeyedReference(cond) { return split }
        // Fallback: two or more occurrences of the SAME copular vocabulary
        // signals a trailing body reusing the whose-clause's own comparator
        // word (`whose status is active is fresh`) — a single occurrence is
        // always just the whose-clause's own comparison and must stay
        // untouched.
        var ranges: [Range<String.Index>] = []
        for v in lexicon.grammar.quantifierBodyVerbs {
            ranges.append(contentsOf: occurrenceRanges(of: v, in: cond))
        }
        guard ranges.count >= 2, let last = ranges.max(by: { $0.lowerBound < $1.lowerBound }) else {
            return (cond, nil)
        }
        let head = String(cond[cond.startIndex..<last.lowerBound]).trimmingCharacters(in: .whitespaces)
        let body = String(cond[last.lowerBound...]).trimmingCharacters(in: .whitespaces)
        return (head, body)
    }

    /// Find the split point right after a quoted string value (`"pending"`)
    /// when it is immediately followed by a `quantifierBodyVerbs` marker.
    private func splitAfterQuotedValue(_ cond: String) -> (cond: String, body: String?)? {
        guard let openQuote = cond.firstIndex(of: "\"") else { return nil }
        let afterOpen = cond.index(after: openQuote)
        guard afterOpen < cond.endIndex, let closeQuote = cond[afterOpen...].firstIndex(of: "\"") else { return nil }
        let valueEnd = cond.index(after: closeQuote)
        guard valueEnd < cond.endIndex else { return nil }
        let tail = String(cond[valueEnd...])
        guard lexicon.grammar.quantifierBodyVerbs.contains(where: { tail.lowercased().hasPrefix($0.lowercased()) })
        else { return nil }
        let head = String(cond[cond.startIndex..<valueEnd]).trimmingCharacters(in: .whitespaces)
        let body = tail.trimmingCharacters(in: .whitespaces)
        return (head, body)
    }

    /// Find the split point right after a short keyed reference (a
    /// possessive pronoun + one word, or an `<ident>'s ` possessive + one
    /// word) when it is immediately followed by a `quantifierBodyVerbs`
    /// marker — that marker starts a trailing per-element body.
    private func splitAfterKeyedReference(_ cond: String) -> (cond: String, body: String?)? {
        var anchorEnds: [String.Index] = []
        for pronoun in lexicon.possessivePronouns {
            anchorEnds.append(contentsOf: occurrenceRanges(of: pronoun, in: cond).map(\.upperBound))
        }
        anchorEnds.append(contentsOf: occurrenceRanges(of: "'s ", in: cond).map(\.upperBound))
        for anchorEnd in anchorEnds.sorted() {
            guard anchorEnd < cond.endIndex else { continue }
            let afterAnchor = String(cond[anchorEnd...])
            guard let firstWord = afterAnchor.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first
            else { continue }
            let propertyEnd = cond.index(anchorEnd, offsetBy: firstWord.count)
            guard propertyEnd < cond.endIndex else { continue }
            let tail = String(cond[propertyEnd...])
            guard lexicon.grammar.quantifierBodyVerbs.contains(where: { tail.lowercased().hasPrefix($0.lowercased()) })
            else { continue }
            let head = String(cond[cond.startIndex..<propertyEnd]).trimmingCharacters(in: .whitespaces)
            let body = tail.trimmingCharacters(in: .whitespaces)
            return (head, body)
        }
        return nil
    }

    /// All non-overlapping occurrences of `marker` in `s`, quote-aware.
    private func occurrenceRanges(of marker: String, in s: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchFrom = s.startIndex
        while searchFrom < s.endIndex {
            let remainder = String(s[searchFrom...])
            guard let r = QuoteAwareScanner.rangeOfMarker(marker, in: remainder, caseInsensitive: true) else { break }
            let offset = remainder.distance(from: remainder.startIndex, to: r.lowerBound)
            let lower = s.index(searchFrom, offsetBy: offset)
            let upper = s.index(lower, offsetBy: marker.count)
            ranges.append(lower..<upper)
            searchFrom = upper
        }
        return ranges
    }

    /// Split `s` at the earliest top-level `quantifierBodyVerbs` marker
    /// (copular/possessive verb introducing a per-element body), returning
    /// the text before it and the body (verb onward), or `(s, nil)` when no
    /// marker is present.
    private func earliestBodyVerbSplit(_ s: String) -> (head: String, body: String?) {
        var earliest: Range<String.Index>?
        for v in lexicon.grammar.quantifierBodyVerbs {
            if let r = QuoteAwareScanner.rangeOfMarker(v, in: s, caseInsensitive: true) {
                if earliest == nil || r.lowerBound < earliest!.lowerBound { earliest = r }
            }
        }
        guard let r = earliest else { return (s.trimmingCharacters(in: .whitespaces), nil) }
        let head = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        let body = String(s[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
        return (head, body)
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
