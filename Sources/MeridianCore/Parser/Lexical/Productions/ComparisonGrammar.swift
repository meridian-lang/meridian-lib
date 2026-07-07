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
        // A `whose` relative clause runs to the end of its enclosing phrase
        // (see `DescriptionGrammar`/`QuantifierGrammar`, which recurse the
        // full expression grammar on everything after `whose`), so it owns
        // any comparison marker inside it. A marker found *at or after* the
        // first top-level `whose` therefore belongs to the clause's own
        // predicate, not to a comparison wrapping the whole phrase — e.g.
        // `the number of patients whose status is "held"` must not split
        // into `<the number of patients whose status> is "held"` (which
        // would silently drop the intended filter and compare a count to a
        // string). Skip those candidates so the phrase falls through to
        // `atom`/`aggregate`, which parses the `whose` clause correctly.
        let whoseBound = QuoteAwareScanner.rangeOfMarker(
            lexicon.grammar.iterationMarkers.whoseMarker, in: t, caseInsensitive: true
        )?.lowerBound
        for (marker, op) in lexicon.comparisonMarkers {
            guard let range = paddedMarkerRange(marker, in: t) else { continue }
            if let whoseBound, range.lowerBound >= whoseBound { continue }
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
