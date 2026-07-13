import Foundation
import MeridianRuntime

// Multi-line phrase-invocation folding — extracted from StatementParser
// for Phase 3 readability.

extension StatementParser {

    // MARK: - Multi-line phrase invocation collector

    /// Fold continuation lines (deeper indent than the header) into a single text
    /// fragment, returning both the joined string and the number of continuation
    /// lines consumed. The header line is *not* counted in `consumed`.
    ///
    /// Two early-exit conditions:
    ///   - If the header line is `.`-terminated (a complete statement), no
    ///     continuation lines are folded — even if subsequent indented lines
    ///     exist. They belong to a structurally separate statement (e.g. an
    ///     attached `recover from …:` block).
    ///   - A subsequent line that begins with a known structural keyword
    ///     (`recover from`, `recover where`, `simultaneously:`) is also a
    ///     boundary — it cannot be a phrase continuation.
    func collectMultiLineCounted(_ lines: [SourceLine], at i: Int) -> (text: String, consumed: Int) {
        let header = lines[i]
        var result = header.statement
        // `.statement` strips a trailing `.`; consult `text` to detect it.
        if header.text.hasSuffix(".") {
            return (result, 0)
        }
        let parentIndent = header.indent
        var j = i + 1
        var consumed = 0
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent, !isStructuralBoundary(l) {
                result += " " + l.statement
                j += 1
                consumed += 1
            } else {
                break
            }
        }
        return (result, consumed)
    }

    /// Lines that are themselves complete statements rather than phrase
    /// continuations. Folding them into a phrase invocation hides the
    /// statement from the parser entirely.
    func isStructuralBoundary(_ line: SourceLine) -> Bool {
        let t = line.statement.lowercased()
        let statement = lexicon.grammar.statement
        return t.hasPrefix(statement.recoverFromPrefix)
            || t.hasPrefix(statement.recoverWherePrefix)
            || t == statement.simultaneouslyHeader
    }
}
