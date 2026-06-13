import Foundation
import MeridianRuntime

// MARK: - Precise source spans (Pillar 4)

extension SourceRange {

    /// Token-precise span: locate `substring` inside `lineText` and return a
    /// `SourceRange` whose start/end columns (1-based) bracket it. Falls back to
    /// a whole-line span (`startColumn = 1`) when the substring isn't found, so
    /// the result is always at least line-accurate.
    public static func span(file: String, line lineNumber: Int,
                            in lineText: String, of substring: String) -> SourceRange {
        guard !substring.isEmpty,
              let r = lineText.range(of: substring) else {
            return SourceRange(file: file,
                               startLine: lineNumber, startColumn: 1,
                               endLine: lineNumber, endColumn: Swift.max(1, lineText.count + 1))
        }
        let startCol = lineText.distance(from: lineText.startIndex, to: r.lowerBound) + 1
        let endCol = lineText.distance(from: lineText.startIndex, to: r.upperBound) + 1
        return SourceRange(file: file,
                           startLine: lineNumber, startColumn: startCol,
                           endLine: lineNumber, endColumn: endCol)
    }
}

extension SourceLine {

    /// A whole-statement span for this line: start column is the first
    /// non-whitespace character (the recorded indent + 1), end column is the end
    /// of the visible text. Tier-1 of Pillar 4 — always available, no per-site
    /// work, so every statement diagnostic gets an accurate caret start.
    public func statementRange(file: String) -> SourceRange {
        let start = indent + 1
        let end = Swift.max(start + 1, indent + text.count + 1)
        return SourceRange(file: file,
                           startLine: number, startColumn: start,
                           endLine: number, endColumn: end)
    }

    /// A token-precise span for `substring` within this line (Tier-2). Resolves
    /// the substring against `raw` (so column math matches the original source),
    /// falling back to `statementRange` when not found.
    public func range(file: String, of substring: String) -> SourceRange {
        guard !substring.isEmpty, let r = raw.range(of: substring) else {
            return statementRange(file: file)
        }
        let startCol = raw.distance(from: raw.startIndex, to: r.lowerBound) + 1
        let endCol = raw.distance(from: raw.startIndex, to: r.upperBound) + 1
        return SourceRange(file: file,
                           startLine: number, startColumn: startCol,
                           endLine: number, endColumn: endCol)
    }
}
