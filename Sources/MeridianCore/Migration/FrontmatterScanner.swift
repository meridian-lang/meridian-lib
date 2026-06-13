import Foundation

/// The single `---`/`---` frontmatter boundary walk shared by the migration
/// tooling. The three callers (marking-scope, metrics body-strip, deviation
/// diff-map) parse the block's body differently — key normalization and return
/// shape diverge — so only the genuinely identical part (locating the fences)
/// lives here; each caller keeps its own body loop on top.
enum FrontmatterScanner {

    /// Locate the leading `---`/`---` block. Returns the indices of the opening
    /// and closing fence lines, or `nil` when there is no well-formed block.
    ///
    /// - Parameter skipLeadingBlanks: when `true`, blank lines may precede the
    ///   opening fence (metrics/deviation tolerate this); when `false`, the
    ///   fence must be the very first line (the marking pass requires it at
    ///   line 0).
    static func locate(_ lines: [String], skipLeadingBlanks: Bool) -> (open: Int, close: Int)? {
        var start = 0
        if skipLeadingBlanks {
            while start < lines.count, lines[start].trimmingCharacters(in: .whitespaces).isEmpty { start += 1 }
        }
        guard start < lines.count,
              lines[start].trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var close = start + 1
        while close < lines.count, lines[close].trimmingCharacters(in: .whitespaces) != "---" { close += 1 }
        guard close < lines.count else { return nil }
        return (start, close)
    }
}
