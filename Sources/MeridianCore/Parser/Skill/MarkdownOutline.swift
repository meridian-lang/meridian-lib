import Foundation

// MARK: - MarkdownOutline
//
// The single heading-detection function plus the two constructors every
// heading scan builds on: tokenized lines (compiler side, fences already
// collapsed by `IndentTokenizer`) and raw markdown lines (migration tooling,
// fence-aware). The raw-line reference implementation lived in
// `Migration/SkillMarkdownShape` before this file absorbed it.

struct MarkdownOutline {

    /// One heading plus the lines that follow it up to the next heading (at any
    /// depth). `bodyLines` is verbatim — blanks and comments included; callers
    /// that want content only filter on `\.isContent` themselves.
    struct Section {
        let level: Int
        let heading: String
        let headingLine: Int
        let bodyLines: [SourceLine]
    }

    /// Recognize a `##`…`######` heading line (no leading whitespace, at least
    /// one space or tab after the hashes, non-empty text). Returns the hash run
    /// and the trimmed heading text.
    static func headingMatch(_ line: String) -> (hashes: String, text: String)? {
        guard line.hasPrefix("##") else { return nil }
        var hashes = 0
        for ch in line {
            if ch == "#" { hashes += 1 } else { break }
        }
        guard (2...6).contains(hashes) else { return nil }
        let after = line.dropFirst(hashes)
        guard let first = after.first, first == " " || first == "\t" else { return nil }
        let text = after.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (String(repeating: "#", count: hashes), text)
    }

    /// Outline of tokenized lines. Heading levels come from `IndentTokenizer`
    /// (`##` → 2, `###` → 3); `heading` is the surface-stripped heading text.
    /// Lines before the first heading belong to no section and are dropped.
    static func build(_ lines: [SourceLine]) -> [Section] {
        var out: [Section] = []
        var heading: (level: Int, text: String, line: Int)?
        var body: [SourceLine] = []
        for line in lines {
            if let level = line.headingLevel {
                if let h = heading {
                    out.append(Section(level: h.level, heading: h.text,
                                       headingLine: h.line, bodyLines: body))
                }
                heading = (level, line.text, line.number)
                body = []
                continue
            }
            if heading != nil { body.append(line) }
        }
        if let h = heading {
            out.append(Section(level: h.level, heading: h.text, headingLine: h.line, bodyLines: body))
        }
        return out
    }

    /// Outline of raw markdown lines: fence-aware (a ``` fence toggles, so `##`
    /// lines inside a code sample are not headings) and heading-matched on the
    /// whitespace-trimmed line. Each raw line is wrapped with `raw` verbatim and
    /// `text` whitespace-trimmed; `indent`/`listMarker`/`headingLevel` are not
    /// populated (migration tooling works on the raw text).
    static func build(rawLines: [String]) -> [Section] {
        var out: [Section] = []
        var heading: (hashes: String, text: String, line: Int)?
        var body: [SourceLine] = []
        var inFence = false
        for (idx, raw) in rawLines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                if heading != nil { body.append(rawSourceLine(raw, number: idx + 1)) }
                continue
            }
            if inFence {
                if heading != nil { body.append(rawSourceLine(raw, number: idx + 1)) }
                continue
            }
            if let m = headingMatch(trimmed) {
                if let h = heading {
                    out.append(Section(level: h.hashes.count, heading: h.text,
                                       headingLine: h.line, bodyLines: body))
                }
                heading = (m.hashes, m.text, idx + 1)
                body = []
                continue
            }
            if heading != nil { body.append(rawSourceLine(raw, number: idx + 1)) }
        }
        if let h = heading {
            out.append(Section(level: h.hashes.count, heading: h.text, headingLine: h.line, bodyLines: body))
        }
        return out
    }

    /// True for a whole-line backticked command span (`\`gbrain sync\``) — a
    /// command with arguments, not a bare backticked term. Shared by the
    /// migrator's procedure-candidate scan and `SkillMetrics`.
    static func wholeLineBacktickedCommand(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let commandSpan = StatementParser.splitCommandAnnotation(trimmed).command
        guard commandSpan.hasPrefix("`"), commandSpan.hasSuffix("`") else { return false }
        let inner = commandSpan.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        return !inner.isEmpty && !inner.contains("`") && (inner.contains(" ") || inner.contains("."))
    }

    private static func rawSourceLine(_ raw: String, number: Int) -> SourceLine {
        SourceLine(indent: 0, text: raw.trimmingCharacters(in: .whitespaces), raw: raw, number: number)
    }
}
