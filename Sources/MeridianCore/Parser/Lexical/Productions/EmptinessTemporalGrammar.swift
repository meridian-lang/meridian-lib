import Foundation

/// `emptiness` + `temporal-window` (`GrammarTable`, `.pegex`): the shared
/// condition grammar used by both bare conditions and quantifier bodies.
///
/// - Emptiness: `<subj> is empty` / `is not empty`, `<subj> has no <prop>` /
///   `has a <prop>` / `has some <prop>` (also plural `have …`).
/// - Temporal window: `<subj> within the last N <unit>` /
///   `<subj> is within the last N <unit>` / `<subj> in the next N <unit>`.
///   A bare participle subject (`updated`, `modified`, `changed`) — or an empty
///   subject — resolves to the lexicon's `timestampProperty`.
///
/// Both are fixed-suffix/fixed-marker shapes: markers are located with the
/// quote-aware `QuoteAwareScanner` against exact lexicon-owned marker strings.
struct EmptinessTemporalGrammar {
    let lexicon: EnglishLexicon
    let atom: (String) -> ExpressionAST

    func parse(_ s: String) -> ExpressionAST? {
        if let e = parseEmptiness(s) { return e }
        if let t = parseTemporal(s) { return t }
        return nil
    }

    // MARK: - Emptiness

    private func parseEmptiness(_ s: String) -> ExpressionAST? {
        let placeholder = ExpressionAST.literal(.boolean(true))
        let lower = s.lowercased()
        let grammar = lexicon.grammar
        if lower.hasSuffix(grammar.notEmptyPredicateSuffix) {
            let subj = String(s.dropLast(grammar.notEmptyPredicateSuffix.count))
            return .comparison(atom(subj), .isNotEmpty, placeholder)
        }
        if lower.hasSuffix(grammar.emptyPredicateSuffix) {
            let subj = String(s.dropLast(grammar.emptyPredicateSuffix.count))
            return .comparison(atom(subj), .isEmpty, placeholder)
        }
        for m in lexicon.emptyMarkers {
            if let r = markerRange(m, in: s) {
                let subj = String(s[s.startIndex..<r.lowerBound])
                let prop = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return .comparison(.propertyAccess(atom(subj), prop), .isEmpty, placeholder)
            }
        }
        for m in lexicon.filledMarkers {
            if let r = markerRange(m, in: s) {
                let subj = String(s[s.startIndex..<r.lowerBound])
                let prop = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return .comparison(.propertyAccess(atom(subj), prop), .isNotEmpty, placeholder)
            }
        }
        return nil
    }

    // MARK: - Temporal window

    private func parseTemporal(_ s: String) -> ExpressionAST? {
        for (marker, op) in lexicon.temporalWindowMarkers {
            if let r = markerRange(marker, in: s) {
                let before = stripTrailingTemporalCopula(
                    String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces))
                let after = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard let dur = parseLeadingDuration(after) else { return nil }
                let lt = before.lowercased()
                let lhs: ExpressionAST
                if before.isEmpty || lexicon.timestampAliases.contains(lt) {
                    lhs = .identifierRef(lexicon.timestampProperty)
                } else {
                    lhs = atom(before)
                }
                return .comparison(lhs, op, .literal(.duration(dur.0, dur.1)))
            }
        }
        return nil
    }

    private func stripTrailingTemporalCopula(_ s: String) -> String {
        let lower = s.lowercased()
        // Strip only lexicon-owned copulas, longest first so multi-word
        // domain extensions cannot be truncated by a shorter suffix.
        for copula in lexicon.copulas.sorted(by: { $0.count > $1.count }) {
            if lower == copula { return "" }
            let suffix = " \(copula)"
            if lower.hasSuffix(suffix) {
                return String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return s
    }

    private func parseLeadingDuration(_ s: String) -> (Double, TimeUnitAST)? {
        let parts = s.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        return lexicon.parseDuration("\(parts[0]) \(parts[1])")
    }

    // MARK: - Marker location

    /// Quote-aware range of an exact lexicon-owned marker.
    private func markerRange(_ marker: String, in s: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: s)
    }
}
