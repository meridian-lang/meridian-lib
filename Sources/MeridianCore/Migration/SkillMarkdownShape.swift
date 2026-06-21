import Foundation

enum SkillMarkdownShape {
    /// Recognize a `##`…`######` heading line (no leading whitespace, at least
    /// one space after the hashes, non-empty text). Returns the hash run and the
    /// trimmed heading text.
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

    static func headingText(_ line: String) -> String? {
        headingMatch(line)?.text
    }

    static func wholeLineBacktickedCommand(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let commandSpan = StatementParser.splitCommandAnnotation(trimmed).command
        guard commandSpan.hasPrefix("`"), commandSpan.hasSuffix("`") else { return false }
        let inner = commandSpan.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        return !inner.isEmpty && !inner.contains("`") && (inner.contains(" ") || inner.contains("."))
    }
}
