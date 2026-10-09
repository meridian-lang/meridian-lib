import Foundation

// MARK: - Frontmatter
//
// The single leading `---`/`---` frontmatter parser. Three shapes over the same
// block, one per consumer tier:
//
//   • `locate` — raw-line fence walk (migration tooling: marking scope,
//     metrics body-strip, deviation diff-map).
//   • `simpleEntries` — lowercase-key reader over raw lines (module layer:
//     `imports`/`module`/`version`/`sealed`).
//   • `parse` — full tokenized parse (compiler: ordered entries + block
//     scalars, inline flow sequences, YAML block sequences, folded
//     continuations).
//
// Placement policy (frontmatter must be first, blank lines tolerated) stays
// with `MeridianParser`, which owns the diagnostic.

enum Frontmatter {

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

    /// Simple lowercase-key reader: the opening fence must be the first line,
    /// keys are lowercased, values whitespace-trimmed with a surrounding pair
    /// of double quotes stripped. Returns `nil` when there is no block or the
    /// block carries no `key: value` entry.
    static func simpleEntries(_ source: String) -> [String: String]? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var entries: [String: String] = [:]
        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
                var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                entries[key] = value
            }
            i += 1
        }
        return entries.isEmpty ? nil : entries
    }

    /// Full tokenized parse of the leading block: the ordered `(key, value)`
    /// entries and the index just past the closing fence (or the end of the
    /// file for an unterminated block), or `nil` when the file has no leading
    /// `---`. Multi-valued keys (YAML block scalars, inline flow sequences,
    /// block sequences) pack their elements/lines into one value joined by
    /// `frontmatterListSeparator`; `SkillFrontmatter` splits them back into
    /// typed arrays. Scalar keys never contain "\n".
    static func parse(_ lines: [SourceLine]) -> (entries: [(key: String, value: String)], consumed: Int)? {
        var i = 0
        while i < lines.count, lines[i].isEmpty { i += 1 }
        guard i < lines.count, lines[i].text == "---" else { return nil }
        i += 1
        var entries: [(key: String, value: String)] = []
        while i < lines.count {
            let l = lines[i]
            if l.text == "---" { i += 1; break }
            guard l.isContent, let colonIdx = l.text.firstIndex(of: ":") else {
                i += 1
                continue
            }
            let key   = String(l.text[l.text.startIndex ..< colonIdx]).trimmingCharacters(in: .whitespaces)
            let inline = String(l.text[l.text.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            var value = inline
            var j = i + 1

            if isBlockScalarMarker(inline) {
                // `key: |` / `key: >` — collect deeper-indented lines verbatim.
                var body: [String] = []
                while j < lines.count {
                    let next = lines[j]
                    if next.isEmpty { body.append(""); j += 1; continue }
                    if next.indent > l.indent {
                        body.append(next.text)
                        j += 1
                    } else { break }
                }
                while body.last == "" { body.removeLast() }
                value = body.joined(separator: frontmatterListSeparator)
            } else if inline.hasPrefix("[") && inline.hasSuffix("]") {
                // Inline flow sequence: `key: [a, b, c]`.
                let inner = String(inline.dropFirst().dropLast())
                value = inner.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "\"'")) }
                    .filter { !$0.isEmpty }
                    .joined(separator: frontmatterListSeparator)
            } else {
                // Peek for a YAML block sequence (`- item` lines) when the
                // value is empty; otherwise fold plain continuation lines.
                let peek = skipBlanksIndex(from: j, in: lines)
                if inline.isEmpty, peek < lines.count,
                   lines[peek].listMarker != nil, lines[peek].indent >= l.indent {
                    var items: [String] = []
                    var k = peek
                    while k < lines.count {
                        let next = lines[k]
                        if next.isEmpty || next.isComment { k += 1; continue }
                        if next.listMarker != nil, next.indent >= l.indent {
                            items.append(next.text.trimmingCharacters(in: .whitespaces))
                            k += 1
                        } else { break }
                    }
                    value = items.joined(separator: frontmatterListSeparator)
                    j = k
                } else {
                    while j < lines.count {
                        let next = lines[j]
                        if next.isEmpty || next.isComment { j += 1; continue }
                        if next.indent > l.indent, next.listMarker == nil {
                            value += " " + next.text.trimmingCharacters(in: .whitespaces)
                            j += 1
                        } else { break }
                    }
                }
            }

            i = j
            if !key.isEmpty { entries.append((key: key, value: value)) }
        }
        return (entries, i)
    }

    /// True for YAML block-scalar introducers (`|`, `|-`, `>`, `>-`, `>+`).
    private static func isBlockScalarMarker(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t == "|" || t == "|-" || t == "|+" || t == ">" || t == ">-" || t == ">+"
    }

    /// First non-blank, non-comment line index at or after `from`.
    private static func skipBlanksIndex(from: Int, in lines: [SourceLine]) -> Int {
        var k = from
        while k < lines.count, lines[k].isEmpty || lines[k].isComment { k += 1 }
        return k
    }
}

/// Separator used to pack multi-valued frontmatter (YAML sequences and block
/// scalars) into a single `FileMetadataAST` value string. `SkillFrontmatter`
/// splits on this to recover typed arrays. Newlines never appear in scalar
/// frontmatter values, so this is an unambiguous delimiter.
let frontmatterListSeparator = "\n"
