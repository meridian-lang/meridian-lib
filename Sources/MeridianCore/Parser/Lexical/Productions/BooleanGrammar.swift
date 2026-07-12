import Foundation

/// `boolean` (`GrammarTable`, `.pegex`): `not`/`and`/`or`/`either … or …`
/// composition, plus the `it is not the case that …` clause negation.
///
/// Precedence (lowest to highest): `or` < `and` < `not` < comparison/clause.
/// `and`/`or` may **not** mix at the same level without an explicit `either …
/// or …` grouping — an ungrouped mix is a hard `.malformed` (Wave 2A's rule;
/// see `Inform7Wave2Tests.mixedIsMalformed`).
///
/// Each connective keyword (`not`, `either`, `and`, `or`, the clause-negation
/// introducer) is located with the quote-aware `QuoteAwareScanner` and checked
/// against explicit word boundaries before being treated as a real connective.
/// This replaces the pre-rewrite implementation's base64
/// `eitherSentinelPrefix` encoding (which turned an `either …` body into an
/// opaque string token so the outer and/or split couldn't see inside it) with
/// direct position tracking: `either`'s body is parsed and combined with its
/// surrounding text by index, never re-serialized into the source string.
///
/// One deliberate, reviewed behavior difference from the pre-rewrite parser:
/// `either`'s body here recurses into this *same* boolean grammar, so a
/// comparison-internal ` or ` inside an `either` body (`either a is more than
/// or equal to 5 or b is 1`) is protected by the same `maskComparisonOr`
/// shielding used everywhere else. The pre-rewrite `parseEitherBody` split an
/// `either` body on every raw ` or ` without that shielding — seeing this
/// sentence's golden capture in `ExpressionParserGoldenTests` alongside its
/// `deliberateDivergences` entry). See `IMPLEMENTATION_LOG.md`.
struct BooleanGrammar {
    let lexicon: EnglishLexicon
    /// The full boolean grammar, re-entered for `either` bodies and the clause
    /// negation introducer's inner clause (both are complete sub-expressions).
    let recurse: (String) -> ExpressionAST
    /// The next-highest-precedence step: quantifier/emptiness/temporal/active-
    /// verb/comparison/atom, in that order (`ExpressionParser.parseClause`).
    let clause: (String) -> ExpressionAST

    private var connectors: FixedBooleanConnectors { lexicon.grammar.booleanConnectors }
    private var andWord: String { connectors.andMarker.trimmingCharacters(in: .whitespaces) }
    private var orWord: String { connectors.orMarker.trimmingCharacters(in: .whitespaces) }
    private var eitherWord: String { connectors.eitherPrefix.trimmingCharacters(in: .whitespaces) }

    func parse(_ raw: String) -> ExpressionAST {
        let s = normalizeOxfordCommas(raw.trimmingCharacters(in: .whitespaces))
        if let inner = stripClauseNegationPrefix(s) {
            return .logical(.not, [recurse(inner)])
        }
        return parseEitherLevel(s, whole: s)
    }

    // MARK: - either

    private func parseEitherLevel(_ s: String, whole: String) -> ExpressionAST {
        guard let eitherRange = firstTopLevelKeywordRange(eitherWord, in: s) else {
            return parseOrLevel(s, whole: whole)
        }
        let prefixFull = String(s[s.startIndex..<eitherRange.lowerBound])
        let body = String(s[eitherRange.upperBound...])
        let eitherNode = parseEitherBody(body)

        let prefixTrimmed = prefixFull.trimmingCharacters(in: .whitespaces)
        guard !prefixTrimmed.isEmpty else { return eitherNode }

        // Same invariant the old masked-string check encoded: `either`'s body
        // contributes neither a genuine `and` nor `or` to the outer level (it's
        // one opaque operand), so mixing is determined by `prefixFull` alone.
        let masked = maskComparisonOr(prefixFull)
        let hasOr = hasTopLevelKeyword(orWord, in: masked)
        let hasAnd = hasTopLevelKeyword(andWord, in: masked)
        if hasOr && hasAnd { return .malformed(mixedBooleanMessage(whole)) }

        let lower = prefixTrimmed.lowercased()
        if hasAnd || lower.hasSuffix(" " + andWord) {
            let rest = stripTrailingConnector(prefixTrimmed, andWord)
            return combineAnd(parseOrLevel(rest, whole: whole), eitherNode)
        }
        if hasOr || lower.hasSuffix(" " + orWord) {
            let rest = stripTrailingConnector(prefixTrimmed, orWord)
            return combineOr(parseOrLevel(rest, whole: whole), eitherNode)
        }
        return .malformed(missingEitherConnectorMessage(whole))
    }

    /// Parse a previously-located `either … or …` body (`A or B or C`) into
    /// `.or`. See the type doc comment for the one deliberate divergence this
    /// introduces relative to the pre-rewrite parser.
    private func parseEitherBody(_ body: String) -> ExpressionAST {
        let masked = maskComparisonOr(body)
        guard hasTopLevelKeyword(orWord, in: masked),
              let parts = splitTopLevel(masked, on: connectors.orMarker) else {
            return recurse(body)
        }
        let ops = parts.map { recurse(unmaskComparisonOr($0)) }
        return .logical(.or, ops)
    }

    private func stripTrailingConnector(_ s: String, _ word: String) -> String {
        let suffix = " " + word
        let lower = s.lowercased()
        guard lower.hasSuffix(suffix) else { return s.trimmingCharacters(in: .whitespaces) }
        return String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
    }

    private func combineAnd(_ lhs: ExpressionAST, _ rhs: ExpressionAST) -> ExpressionAST {
        if case .logical(.and, let xs) = lhs { return .logical(.and, xs + [rhs]) }
        return .logical(.and, [lhs, rhs])
    }

    private func combineOr(_ lhs: ExpressionAST, _ rhs: ExpressionAST) -> ExpressionAST {
        if case .logical(.or, let xs) = lhs { return .logical(.or, xs + [rhs]) }
        return .logical(.or, [lhs, rhs])
    }

    // MARK: - or / and / not

    private func parseOrLevel(_ s: String, whole: String) -> ExpressionAST {
        let masked = maskComparisonOr(s)
        let hasOr = hasTopLevelKeyword(orWord, in: masked)
        let hasAnd = hasTopLevelKeyword(andWord, in: masked)
        if hasOr && hasAnd { return .malformed(mixedBooleanMessage(whole)) }
        if hasOr, let parts = splitTopLevel(masked, on: connectors.orMarker) {
            let ops = parts.map { parseAndLevel(unmaskComparisonOr($0), whole: whole) }
            return .logical(.or, ops)
        }
        return parseAndLevel(s, whole: whole)
    }

    private func parseAndLevel(_ s: String, whole: String) -> ExpressionAST {
        if let parts = splitTopLevel(s, on: connectors.andMarker) {
            let ops = parts.map { parseNotLevel($0, whole: whole) }
            return .logical(.and, ops)
        }
        return parseNotLevel(s, whole: whole)
    }

    private func parseNotLevel(_ s: String, whole: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let inner = stripNotPrefix(t) {
            return .logical(.not, [parseNotLevel(inner, whole: whole)])
        }
        return clause(t)
    }

    /// The diagnostic carried by `.malformed` for an ungrouped `and`/`or` mix.
    private func mixedBooleanMessage(_ s: String) -> String {
        "ambiguous boolean expression \"\(s)\" mixes `and` and `or` without grouping. "
        + "Group the intended sub-clause with `either … or …` — e.g. write "
        + "`A and either B or C` (A ∧ (B ∨ C)) or `either A and B or C` ((A ∧ B) ∨ C)."
    }

    /// The diagnostic carried by `.malformed` when a clause precedes `either …`
    /// without an explicit `and`/`or` connector.
    private func missingEitherConnectorMessage(_ s: String) -> String {
        "boolean expression \"\(s)\" joins a clause and `either … or …` without an explicit "
        + "`and` or `or` connector. Write `A and either B or C` or `either A and B or C`."
    }

    // MARK: - Prefix keywords

    private func stripClauseNegationPrefix(_ t: String) -> String? {
        let introducer = lexicon.grammar.clauseNegationIntroducer
        guard t.lowercased().hasPrefix(introducer) else { return nil }
        return String(t.dropFirst(introducer.count))
    }

    private func stripNotPrefix(_ t: String) -> String? {
        guard t.lowercased().hasPrefix(connectors.notPrefix) else { return nil }
        return String(t.dropFirst(connectors.notPrefix.count))
    }

    /// Normalise Oxford-style `, and`/`, or` joins to plain ` and `/` or `.
    private func normalizeOxfordCommas(_ s: String) -> String {
        var out = replaceOutsideQuotes(s, find: connectors.oxfordAndMarker, with: connectors.andMarker)
        out = replaceOutsideQuotes(out, find: connectors.oxfordOrMarker, with: connectors.orMarker)
        return out
    }

    // MARK: - Comparison-marker `or` shielding
    //
    // The `… than or equal to` family of comparison markers embeds a literal
    // ` or `. Shielding it here (rather than teaching the or/and detection
    // about comparison markers) keeps this grammar's connective-detection
    // logic single-purpose; see `ComparisonGrammar`/`lexicon.comparisonMarkers`
    // for the marker list this is derived from.

    private static let orMaskToken = "\u{E002}OR\u{E002}"

    private var orBearingComparisonMarkers: [String] {
        lexicon.comparisonMarkers
            .map { $0.0.lowercased() }
            .filter { $0.contains(orWord) }
            .sorted { $0.count > $1.count }
    }

    private func maskComparisonOr(_ t: String) -> String {
        guard t.lowercased().contains(connectors.orMarker) else { return t }
        var result = t
        for marker in orBearingComparisonMarkers {
            let masked = marker.replacingOccurrences(of: connectors.orMarker, with: " \(Self.orMaskToken) ")
            result = result.replacingOccurrences(of: marker, with: masked, options: .caseInsensitive)
        }
        return result
    }

    private func unmaskComparisonOr(_ s: String) -> String {
        s.replacingOccurrences(of: " \(Self.orMaskToken) ", with: connectors.orMarker)
    }

    // MARK: - Quote-aware keyword search

    /// Range of the first occurrence of the whole word `word` (space- or
    /// string-boundary before it) outside quotes.
    private func firstTopLevelKeywordRange(_ word: String, in s: String) -> Range<String.Index>? {
        var search = s.startIndex
        while search < s.endIndex {
            let slice = String(s[search...])
            guard let r = QuoteAwareScanner.rangeOfMarker(word, in: slice, caseInsensitive: true) else {
                break
            }
            let lowerOffset = slice.distance(from: slice.startIndex, to: r.lowerBound)
            let absLower = s.index(search, offsetBy: lowerOffset)
            let atLeadingBoundary = absLower == s.startIndex || s[s.index(before: absLower)] == " "
            let absUpper = s.index(absLower, offsetBy: word.count)
            let atTrailingBoundary = absUpper == s.endIndex || s[absUpper] == " "
            if atLeadingBoundary, atTrailingBoundary {
                return absLower..<absUpper
            }
            search = s.index(after: absLower)
        }
        return nil
    }

    private func hasTopLevelKeyword(_ word: String, in s: String) -> Bool {
        // This helper is only used for the fixed `and`/`or` connectives; both
        // markers already carry their own padding spaces.
        let padded = word == andWord ? connectors.andMarker : connectors.orMarker
        return QuoteAwareScanner.rangeOfMarker(padded, in: s) != nil
    }

    /// Split `s` on `sep` but only outside quoted regions. `nil` when `sep`
    /// does not occur outside quotes at all.
    private func splitTopLevel(_ s: String, on sep: String) -> [String]? {
        var parts: [String] = []
        var remaining = s
        var found = false
        while let r = QuoteAwareScanner.rangeOfMarker(sep, in: remaining) {
            parts.append(String(remaining[remaining.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces))
            remaining = String(remaining[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            found = true
        }
        guard found else { return nil }
        parts.append(remaining.trimmingCharacters(in: .whitespaces))
        return parts
    }

    private func replaceOutsideQuotes(_ s: String, find: String, with replace: String) -> String {
        // `remaining` must stay a `String` (not a `Substring`) rebuilt fresh
        // each iteration: `r` is computed by `rangeOfMarker(_:in:)` against
        // whichever value is passed as `in:`, so its indices are only valid
        // for that exact `String` instance. A prior version scanned
        // `String(remaining)` (a throwaway copy with its own index space) but
        // then subscripted the original `remaining` `Substring` with `r` —
        // valid by accident on the first match (a whole-string `Substring`
        // happens to share its base's indices), but on a second match
        // `remaining` is itself a suffix slice, so `r`'s indices (relative to
        // yet another fresh copy) no longer line up with it and the
        // subscript traps ("Range requires lowerBound <= upperBound"). Two
        // Oxford-comma joins in one sentence is enough to hit this.
        var result = ""
        var remaining = s
        while let r = QuoteAwareScanner.rangeOfMarker(find, in: remaining) {
            result += remaining[remaining.startIndex..<r.lowerBound] + replace
            remaining = String(remaining[r.upperBound...])
        }
        result += remaining
        return result
    }
}
