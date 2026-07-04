import Foundation

/// 128-bit bitmask word for `NonterminalScreen`'s anchor vocabulary. A plain
/// two-`UInt64` pair rather than the standard library's `UInt128` (SE-0400),
/// which requires macOS 15+ — this package targets macOS 14 (`Package.swift`).
/// Only the handful of operations `NonterminalScreen` needs are implemented.
struct Bitset128: Sendable, Equatable, ExpressibleByIntegerLiteral {
    private var lo: UInt64
    private var hi: UInt64

    private init(lo: UInt64, hi: UInt64) {
        self.lo = lo
        self.hi = hi
    }

    /// Supports the `== 0` / `!= 0` comparisons call sites use as an "is
    /// empty" check; only the literal `0` is meaningful here.
    init(integerLiteral value: UInt64) {
        lo = value
        hi = 0
    }

    /// The single-bit mask for `index` (0..<128).
    init(bit index: Int) {
        if index < 64 {
            lo = UInt64(1) << UInt64(index)
            hi = 0
        } else {
            lo = 0
            hi = UInt64(1) << UInt64(index - 64)
        }
    }

    static func | (a: Bitset128, b: Bitset128) -> Bitset128 {
        Bitset128(lo: a.lo | b.lo, hi: a.hi | b.hi)
    }

    static func |= (a: inout Bitset128, b: Bitset128) {
        a = a | b
    }

    static func & (a: Bitset128, b: Bitset128) -> Bitset128 {
        Bitset128(lo: a.lo & b.lo, hi: a.hi & b.hi)
    }
}

struct NonterminalScreen: Sendable {
    /// The grammar has ~100 distinct anchors across all productions,
    /// comfortably over 64, and every anchor needs a stable slot (see the
    /// correctness note in `init` below) — `Bitset128` is capacity headroom,
    /// not a perf choice.
    private let table: GrammarTable
    private let vocabulary: [String: Bitset128]
    private let masksByProduction: [String: Bitset128]

    init(table: GrammarTable) {
        self.table = table
        let anchors = Array(stableUnique(table.anchors).prefix(128))
        let vocabulary = Dictionary(uniqueKeysWithValues: anchors.enumerated().map { index, anchor in
            (anchor, Bitset128(bit: index))
        })
        // A production's mask is only meaningful if *every* one of its anchors
        // made it into the (128-slot) vocabulary. If the grammar ever grows
        // past that budget, some anchors would get no vocabulary slot at all
        // (`vocabulary[anchor]` nil for them). Folding those in as `0` would
        // silently produce a mask missing bits for real trigger words — e.g.
        // quantifier's `all`/`every`/`any`/… determiners are 10 anchors, and
        // if only `all` fit in the budget, an "every …" sentence would compute
        // a mask with no bit in common with quantifier's (partial) mask and
        // get wrongly screened out even though `every` is a valid trigger. So:
        // a production with any anchor outside the tracked vocabulary is
        // simply left unscreened (mask 0 — `candidates` always includes it),
        // which is strictly no less correct than screening it, just without
        // the (currently unrealized for that production) speedup.
        let masksByProduction = Dictionary(uniqueKeysWithValues: table.productions.map { production -> (String, Bitset128) in
            let fullyRepresented = production.anchors.allSatisfy { vocabulary[$0] != nil }
            let mask = fullyRepresented ? Self.mask(for: production.anchors, vocabulary: vocabulary) : 0
            return (production.name, mask)
        })
        self.vocabulary = vocabulary
        self.masksByProduction = masksByProduction
    }

    var anchorCount: Int {
        vocabulary.count
    }

    func mask(for sentence: String) -> Bitset128 {
        let lower = sentence.lowercased()
        var mask: Bitset128 = 0
        for (anchor, bit) in vocabulary where containsAnchor(anchor, in: lower) {
            mask |= bit
        }
        return mask
    }

    func candidates(for sentence: String) -> [GrammarProduction] {
        let sentenceMask = mask(for: sentence)
        return table.productions.filter { production in
            let productionMask = masksByProduction[production.name] ?? 0
            return productionMask == 0 || (sentenceMask & productionMask) != 0
        }
    }

    func anchorMask(for production: GrammarProduction) -> Bitset128 {
        masksByProduction[production.name] ?? 0
    }

    private static func mask(for anchors: [String], vocabulary: [String: Bitset128]) -> Bitset128 {
        anchors.reduce(Bitset128(0)) { mask, anchor in
            mask | (vocabulary[anchor] ?? 0)
        }
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
