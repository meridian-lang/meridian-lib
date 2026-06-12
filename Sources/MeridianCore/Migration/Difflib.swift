import Foundation

// A faithful, line-level port of CPython's `difflib.SequenceMatcher` and
// `difflib.unified_diff`, so deviation reports are byte-for-byte equivalent to
// the original Python-generated corpus (same matching blocks, same similarity
// ratio, same `@@ … @@` hunk headers). Only the parts needed for line diffs are
// ported: `isjunk` is always `None` (no element-level junk); `autojunk=True`
// matches Python's default.
//
// Reference: Lib/difflib.py (SequenceMatcher, unified_diff, _format_range_unified).

struct DiffMatcher {
    let a: [String]
    let b: [String]
    private var b2j: [String: [Int]] = [:]

    init(_ a: [String], _ b: [String], autojunk: Bool = true) {
        self.a = a
        self.b = b
        chainB(autojunk: autojunk)
    }

    // MARK: - chain_b

    private mutating func chainB(autojunk: Bool) {
        for (i, elt) in b.enumerated() {
            b2j[elt, default: []].append(i)
        }
        // isjunk is None -> no element-level junk to strip.
        // autojunk: in a long sequence, drop "popular" elements (appearing more
        // than 1% of the time) from the seed index. They can still be absorbed
        // into a match via the extension loops in findLongestMatch.
        let n = b.count
        if autojunk && n >= 200 {
            let ntest = n / 100 + 1
            var popular = Set<String>()
            for (elt, idxs) in b2j where idxs.count > ntest { popular.insert(elt) }
            for elt in popular { b2j[elt] = nil }
        }
    }

    // MARK: - find_longest_match

    struct Match { var i: Int; var j: Int; var size: Int }

    func findLongestMatch(_ alo: Int, _ ahi: Int, _ blo: Int, _ bhi: Int) -> Match {
        var besti = alo, bestj = blo, bestsize = 0
        var j2len: [Int: Int] = [:]
        for i in alo..<ahi {
            var newj2len: [Int: Int] = [:]
            for j in b2j[a[i]] ?? [] {
                if j < blo { continue }
                if j >= bhi { break }
                let k = (j2len[j - 1] ?? 0) + 1
                newj2len[j] = k
                if k > bestsize { besti = i - k + 1; bestj = j - k + 1; bestsize = k }
            }
            j2len = newj2len
        }
        // Extend over adjacent equal elements (no junk in scope, so only this
        // pair of loops runs; popular elements are absorbed here).
        while besti > alo, bestj > blo, a[besti - 1] == b[bestj - 1] {
            besti -= 1; bestj -= 1; bestsize += 1
        }
        while besti + bestsize < ahi, bestj + bestsize < bhi,
              a[besti + bestsize] == b[bestj + bestsize] {
            bestsize += 1
        }
        return Match(i: besti, j: bestj, size: bestsize)
    }

    // MARK: - get_matching_blocks

    func matchingBlocks() -> [Match] {
        let la = a.count, lb = b.count
        var queue: [(Int, Int, Int, Int)] = [(0, la, 0, lb)]
        var blocks: [Match] = []
        while let (alo, ahi, blo, bhi) = queue.popLast() {
            let m = findLongestMatch(alo, ahi, blo, bhi)
            if m.size > 0 {
                blocks.append(m)
                if alo < m.i && blo < m.j { queue.append((alo, m.i, blo, m.j)) }
                if m.i + m.size < ahi && m.j + m.size < bhi {
                    queue.append((m.i + m.size, ahi, m.j + m.size, bhi))
                }
            }
        }
        blocks.sort { ($0.i, $0.j) < ($1.i, $1.j) }

        // Collapse adjacent equal blocks.
        var i1 = 0, j1 = 0, k1 = 0
        var nonAdjacent: [Match] = []
        for m in blocks {
            if i1 + k1 == m.i && j1 + k1 == m.j {
                k1 += m.size
            } else {
                if k1 > 0 { nonAdjacent.append(Match(i: i1, j: j1, size: k1)) }
                i1 = m.i; j1 = m.j; k1 = m.size
            }
        }
        if k1 > 0 { nonAdjacent.append(Match(i: i1, j: j1, size: k1)) }
        nonAdjacent.append(Match(i: la, j: lb, size: 0))
        return nonAdjacent
    }

    /// Sum of matching-block sizes (difflib's `M`).
    func matchCount() -> Int { matchingBlocks().reduce(0) { $0 + $1.size } }

    /// difflib `ratio()` = 2*M / (len(a)+len(b)); 1.0 for two empty sequences.
    func ratio() -> Double {
        let length = a.count + b.count
        return length == 0 ? 1.0 : 2.0 * Double(matchCount()) / Double(length)
    }

    // MARK: - get_opcodes

    enum Tag: String { case replace, delete, insert, equal }
    struct Opcode { var tag: Tag; var i1: Int; var i2: Int; var j1: Int; var j2: Int }

    func opcodes() -> [Opcode] {
        var i = 0, j = 0
        var answer: [Opcode] = []
        for m in matchingBlocks() {
            var tag: Tag?
            if i < m.i && j < m.j { tag = .replace }
            else if i < m.i { tag = .delete }
            else if j < m.j { tag = .insert }
            if let tag { answer.append(Opcode(tag: tag, i1: i, i2: m.i, j1: j, j2: m.j)) }
            i = m.i + m.size; j = m.j + m.size
            if m.size > 0 { answer.append(Opcode(tag: .equal, i1: m.i, i2: i, j1: m.j, j2: j)) }
        }
        return answer
    }

    // MARK: - get_grouped_opcodes

    func groupedOpcodes(_ n: Int = 3) -> [[Opcode]] {
        var codes = opcodes()
        if codes.isEmpty { codes = [Opcode(tag: .equal, i1: 0, i2: 1, j1: 0, j2: 1)] }
        if codes[0].tag == .equal {
            let c = codes[0]
            codes[0] = Opcode(tag: .equal, i1: max(c.i1, c.i2 - n), i2: c.i2, j1: max(c.j1, c.j2 - n), j2: c.j2)
        }
        if codes[codes.count - 1].tag == .equal {
            let c = codes[codes.count - 1]
            codes[codes.count - 1] = Opcode(tag: .equal, i1: c.i1, i2: min(c.i2, c.i1 + n), j1: c.j1, j2: min(c.j2, c.j1 + n))
        }
        let nn = n + n
        var groups: [[Opcode]] = []
        var group: [Opcode] = []
        for c in codes {
            if c.tag == .equal && c.i2 - c.i1 > nn {
                group.append(Opcode(tag: .equal, i1: c.i1, i2: min(c.i2, c.i1 + n), j1: c.j1, j2: min(c.j2, c.j1 + n)))
                groups.append(group)
                group = []
                group.append(Opcode(tag: .equal, i1: max(c.i1, c.i2 - n), i2: c.i2, j1: max(c.j1, c.j2 - n), j2: c.j2))
                continue
            }
            group.append(c)
        }
        if !group.isEmpty && !(group.count == 1 && group[0].tag == .equal) {
            groups.append(group)
        }
        return groups
    }

    // MARK: - unified_diff body

    /// The hunk body of a unified diff (no `--- `/`+++ ` file headers), matching
    /// `difflib.unified_diff` with `n` context lines: `@@ -a +b @@` hunk headers
    /// followed by ` `/`-`/`+` prefixed lines. Empty when the sequences are equal.
    func unifiedDiffBody(context n: Int = 3) -> String {
        var out: [String] = []
        for group in groupedOpcodes(n) {
            guard let first = group.first, let last = group.last else { continue }
            let r1 = Self.formatRangeUnified(first.i1, last.i2)
            let r2 = Self.formatRangeUnified(first.j1, last.j2)
            out.append("@@ -\(r1) +\(r2) @@")
            for c in group {
                switch c.tag {
                case .equal:
                    for line in a[c.i1..<c.i2] { out.append(" " + line) }
                case .replace:
                    for line in a[c.i1..<c.i2] { out.append("-" + line) }
                    for line in b[c.j1..<c.j2] { out.append("+" + line) }
                case .delete:
                    for line in a[c.i1..<c.i2] { out.append("-" + line) }
                case .insert:
                    for line in b[c.j1..<c.j2] { out.append("+" + line) }
                }
            }
        }
        return out.joined(separator: "\n")
    }

    /// Port of difflib `_format_range_unified`: 1-based start; `length == 1`
    /// renders as just the start; an empty range begins one line earlier.
    static func formatRangeUnified(_ start: Int, _ stop: Int) -> String {
        var beginning = start + 1
        let length = stop - start
        if length == 1 { return "\(beginning)" }
        if length == 0 { beginning -= 1 }
        return "\(beginning),\(length)"
    }
}
