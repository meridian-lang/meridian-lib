import Foundation

struct NonterminalScreen: Sendable {
    private let table: GrammarTable
    /// Anchor word → its stable vocabulary slot.
    private let vocabulary: [String: Int]
    /// The vocabulary slots of each production's anchors. An empty set means
    /// "unscreened" — see the correctness note in `init`.
    private let anchorsByProduction: [String: Set<Int>]

    /// The grammar has ~100 distinct anchors across all productions. The
    /// vocabulary is capped at 128 slots purely as a screening budget: every
    /// tracked anchor needs a stable slot, and a production with an anchor
    /// outside the budget is left unscreened rather than mis-screened.
    private static let vocabularyBudget = 128

    init(table: GrammarTable) {
        self.table = table
        let anchors = Array(stableUnique(table.anchors).prefix(Self.vocabularyBudget))
        let vocabulary = Dictionary(uniqueKeysWithValues: anchors.enumerated().map { index, anchor in
            (anchor, index)
        })
        // A production's anchor set is only meaningful if *every* one of its
        // anchors made it into the vocabulary. If the grammar ever grows past
        // the budget, some anchors would get no vocabulary slot at all
        // (`vocabulary[anchor]` nil for them). Ignoring those would silently
        // produce a set missing entries for real trigger words — e.g.
        // quantifier's `all`/`every`/`any`/… determiners are 10 anchors, and
        // if only `all` fit in the budget, an "every …" sentence would compute
        // a set with nothing in common with quantifier's (partial) set and
        // get wrongly screened out even though `every` is a valid trigger. So:
        // a production with any anchor outside the tracked vocabulary is
        // simply left unscreened (empty set — `candidates` always includes
        // it), which is strictly no less correct than screening it, just
        // without the (currently unrealized for that production) speedup.
        let anchorsByProduction = Dictionary(uniqueKeysWithValues: table.productions.map { production -> (String, Set<Int>) in
            let fullyRepresented = production.anchors.allSatisfy { vocabulary[$0] != nil }
            let indices = fullyRepresented ? Set(production.anchors.compactMap { vocabulary[$0] }) : []
            return (production.name, indices)
        })
        self.vocabulary = vocabulary
        self.anchorsByProduction = anchorsByProduction
    }

    var anchorCount: Int {
        vocabulary.count
    }

    /// The vocabulary slots of every tracked anchor word occurring in `sentence`.
    func anchorIndices(in sentence: String) -> Set<Int> {
        let lower = sentence.lowercased()
        var indices: Set<Int> = []
        for (anchor, index) in vocabulary where containsAnchor(anchor, in: lower) {
            indices.insert(index)
        }
        return indices
    }

    func candidates(for sentence: String) -> [GrammarProduction] {
        let sentenceAnchors = anchorIndices(in: sentence)
        return table.productions.filter { production in
            let productionAnchors = anchorsByProduction[production.name] ?? []
            return productionAnchors.isEmpty || !sentenceAnchors.isDisjoint(with: productionAnchors)
        }
    }

    func anchorIndices(for production: GrammarProduction) -> Set<Int> {
        anchorsByProduction[production.name] ?? []
    }
}

private func containsAnchor(_ anchor: String, in text: String) -> Bool {
    guard anchor.allSatisfy({ $0.isLetter || $0.isNumber }) else {
        return text.contains(anchor)
    }
    var searchStart = text.startIndex
    while let range = text[searchStart...].range(of: anchor) {
        let leftOK = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetterOrNumber
        let rightOK = range.upperBound == text.endIndex || !text[range.upperBound].isLetterOrNumber
        if leftOK && rightOK {
            return true
        }
        searchStart = range.upperBound
    }
    return false
}

private extension Character {
    var isLetterOrNumber: Bool {
        isLetter || isNumber
    }
}
