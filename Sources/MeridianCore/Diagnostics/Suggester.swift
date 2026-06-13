import Foundation

/// Reusable "did you mean" engine. Generalizes the verb-only helper that used
/// to live on `SymbolTable` (`nearestVerbForm` / `levenshtein`) so every
/// name-resolution failure in the compiler can offer a hint from a finite
/// candidate set.
///
/// Two public entry points:
///   - `closest(_:among:budget:)` — the single best candidate within an
///     edit-distance budget (used for `did you mean "<x>"?`).
///   - `ranked(_:among:limit:)`  — the top-N candidates ordered by closeness
///     (used for the candidate-list note when nothing is within budget).
///
/// Scoring blends Levenshtein edit distance (primary) with token overlap
/// (tiebreak), so multi-word phrase candidates like `validate an order` rank
/// sensibly against an invocation like `validate the order`.
public struct Suggester: Sendable {

    public init() {}

    /// Default edit-distance budget for a target of the given length:
    /// `max(2, count / 3)`. Mirrors the historical `nearestVerbForm` budget so
    /// suggestion behaviour is unchanged for verbs.
    public static func defaultBudget(for target: String) -> Int {
        Swift.max(2, target.count / 3)
    }

    /// The single closest candidate within `budget` (default
    /// `defaultBudget(for:)`), or `nil` when nothing is close enough.
    /// Comparison is case-insensitive; the original candidate spelling is
    /// returned.
    public func closest(_ target: String, among candidates: [String], budget: Int? = nil) -> String? {
        let t = normalize(target)
        guard !t.isEmpty else { return nil }
        let limit = budget ?? Self.defaultBudget(for: t)
        var best: (cand: String, dist: Int, overlap: Int)?
        for cand in candidates {
            let c = normalize(cand)
            if c.isEmpty { continue }
            let d = Self.levenshtein(t, c)
            let o = tokenOverlap(t, c)
            if best == nil
                || d < best!.dist
                || (d == best!.dist && o > best!.overlap) {
                best = (cand, d, o)
            }
        }
        guard let b = best, b.dist <= limit else { return nil }
        return b.cand
    }

    /// The top `limit` candidates ordered by closeness (closest first).
    /// Used to build a candidate-list note when nothing is within budget, so an
    /// unresolved name is never reported without *some* actionable hint.
    public func ranked(_ target: String, among candidates: [String], limit: Int = 8) -> [String] {
        let t = normalize(target)
        let scored = candidates.compactMap { cand -> (cand: String, dist: Int, overlap: Int)? in
            let c = normalize(cand)
            if c.isEmpty { return nil }
            return (cand, Self.levenshtein(t, c), tokenOverlap(t, c))
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.overlap != rhs.overlap { return lhs.overlap > rhs.overlap }
                if lhs.dist != rhs.dist { return lhs.dist < rhs.dist }
                return lhs.cand < rhs.cand
            }
            .prefix(limit)
            .map(\.cand)
    }

    // MARK: - Internals

    private func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenOverlap(_ a: String, _ b: String) -> Int {
        let at = Set(a.split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
        let bt = Set(b.split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
        return at.intersection(bt).count
    }

    /// Classic iterative Levenshtein edit distance (two-row variant).
    public static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }
}
