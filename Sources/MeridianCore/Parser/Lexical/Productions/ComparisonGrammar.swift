import Foundation

/// `comparison` (`GrammarTable`, `.pegex`): `<lhs> <marker> <rhs>`, e.g.
/// `the total is more than 5`.
///
/// Markers are tried in `lexicon.comparisonMarkers`' own declared order — that
/// list is hand-curated longest-first ("first split wins", see its doc
/// comment), not re-sorted here. A candidate occurrence is found with the
/// quote-aware `QuoteAwareScanner` (so `"is more than a hint"` inside a string
/// literal is never mistaken for a marker). The candidate range is the exact
/// marker string from the lexicon, so there is no second parser to keep in sync.
struct ComparisonGrammar {
    let lexicon: EnglishLexicon
    /// Operand recursion: atoms only (not a full boolean sub-expression) —
    /// matches the pre-rewrite `parseComparison` order, which calls
    /// `parseAtom` on both sides, not `parse`.
    let atom: (String) -> ExpressionAST

    func parse(_ s: String) -> ExpressionAST? {
        let t = s.trimmingCharacters(in: .whitespaces)
        for (marker, op) in lexicon.comparisonMarkers {
            guard let range = paddedMarkerRange(marker, in: t) else { continue }
            let lhs = String(t[t.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rhs = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return .comparison(atom(lhs), op, atom(rhs))
        }
        return nil
    }

    /// Range of ` <marker> ` (space-padded both sides, case-insensitive,
    /// quote-aware) validated with `Keyword`.
    private func paddedMarkerRange(_ marker: String, in s: String) -> Range<String.Index>? {
        let needle = " \(marker) "
        guard let range = QuoteAwareScanner.rangeOfMarker(needle, in: s, caseInsensitive: true) else {
            return nil
        }
        return range
    }
}
