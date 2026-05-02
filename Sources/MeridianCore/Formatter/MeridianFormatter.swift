import Foundation

// MARK: - MeridianFormatter
//
// A conservative, idempotent formatter for `.meridian` and `.merconfig`
// sources. The intent is to canonicalise the *whitespace* of a file
// without touching any tokens or word order — running the formatter on
// already-formatted source must be a no-op.
//
// Rules applied (and only these):
//
//   1. Normalise line endings: `\r\n` and `\r` → `\n`.
//   2. Strip trailing whitespace from every line.
//   3. Replace leading-tab indentation with two-space indentation, taking
//      one tab to be one indent level. Leading spaces are left alone:
//      authors mix two-space and four-space sometimes and we don't want
//      to second-guess intent.
//   4. Collapse runs of three or more blank lines to a single blank line.
//   5. Guarantee the file ends with exactly one trailing `\n`.
//
// Things the formatter intentionally does NOT do:
//
//   - Re-indent based on parsed structure. The parser is indent-sensitive
//     and we don't want a formatter regression to invalidate working files.
//   - Lowercase identifiers or rewrite kind names. Casing is part of the
//     compiler's own canonicalisation step, which the formatter does not
//     replicate.
//   - Reflow long lines. Meridian sources read best when authors choose
//     line breaks deliberately; auto-wrapping breaks that intent.

public struct MeridianFormatter {

    public init() {}

    /// Apply the formatter to `source` and return the formatted string.
    /// Idempotent: `format(format(s)) == format(s)` for any input.
    public func format(_ source: String) -> String {
        // Step 1 — line endings.
        var s = source.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")

        // Step 2 / 3 — per-line normalisation.
        var lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for i in 0..<lines.count {
            lines[i] = normaliseLine(lines[i])
        }

        // Step 4 — collapse blank-line runs (3+ → 1).
        lines = collapseBlankRuns(lines)

        // Step 5 — exactly one trailing newline.
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n") + "\n"
    }

    /// `true` when `format(source) == source` — useful for `--check` modes
    /// in CI that should fail on un-formatted input.
    public func isFormatted(_ source: String) -> Bool {
        format(source) == source
    }

    // MARK: - Private

    private func normaliseLine(_ line: String) -> String {
        // Replace leading tabs with 2 spaces each.
        var prefix = ""
        var rest = line[line.startIndex...]
        while let first = rest.first, first == "\t" {
            prefix += "  "
            rest = rest.dropFirst()
        }
        // Strip trailing whitespace (spaces + tabs).
        var body = String(rest)
        while let last = body.last, last == " " || last == "\t" {
            body.removeLast()
        }
        return prefix + body
    }

    private func collapseBlankRuns(_ lines: [String]) -> [String] {
        var out: [String] = []
        var blankRun = 0
        for line in lines {
            if line.isEmpty {
                blankRun += 1
                if blankRun <= 1 { out.append(line) }
            } else {
                blankRun = 0
                out.append(line)
            }
        }
        return out
    }
}
