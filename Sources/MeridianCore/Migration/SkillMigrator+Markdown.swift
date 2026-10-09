import Foundation

extension SkillMigrator {
    func normalizeMarkdownFormattingForLowering(_ lines: inout [String], _ range: Range<Int>) {
        var inFence = false
        for i in range where i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence || trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(">") {
                continue
            }
            let leading = lines[i].prefix { $0 == " " || $0 == "\t" }
            let normalized = normalizeMarkdownLineForLowering(trimmed)
            lines[i] = String(leading) + normalized
        }
    }

    func normalizeMarkdownLineForLowering(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if isWholeLineBacktickedCommand(trimmed) { return trimmed }
        return stripMarkdownLinksAndEmphasis(stripLeadingBoldLabel(trimmed))
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// idiom: bold-label step tolerance. A numbered/bulleted step
    /// written as `1. **Run health check.** Check gbrain health.` restates its
    /// own action as a bold label before the real statement. Left alone,
    /// `stripMarkdownLinksAndEmphasis` only removes the `**` markers, leaving
    /// two back-to-back sentences ("Run health check. Check gbrain health.")
    /// that `SentenceBreaker` splits into two statements — the label sentence
    /// then fails to lower on its own. Drop just the leading bold label,
    /// keeping any list marker (`1. `, `- `) and the real statement intact.
    /// Only fires when the remainder has no backtick command: a bold label
    /// before a backticked command (`**Sync.** `gbrain sync``) already lowers
    /// correctly via `embeddedBacktickedCommand`'s `cleanCommandAnnotation`,
    /// which keeps the label as the command's `-- annotation` comment — this
    /// function must not preempt that richer path.
    func stripLeadingBoldLabel(_ raw: String) -> String {
        var prefixEnd = raw.startIndex
        if raw.hasPrefix("- ") || raw.hasPrefix("* ") || raw.hasPrefix("+ ") {
            prefixEnd = raw.index(raw.startIndex, offsetBy: 2)
        } else if let dot = raw.firstIndex(of: "."), !raw[..<dot].isEmpty,
                  raw[..<dot].allSatisfy(\.isNumber),
                  raw.index(after: dot) < raw.endIndex, raw[raw.index(after: dot)] == " " {
            prefixEnd = raw.index(dot, offsetBy: 2)
        }
        let listPrefix = String(raw[..<prefixEnd])
        let rest = raw[prefixEnd...].trimmingCharacters(in: .whitespaces)

        guard rest.hasPrefix("**") else { return raw }
        let afterOpen = rest.index(rest.startIndex, offsetBy: 2)
        guard let closeRange = rest.range(of: "**", range: afterOpen..<rest.endIndex) else { return raw }
        let label = rest[afterOpen..<closeRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let remainder = rest[closeRange.upperBound...].trimmingCharacters(in: .whitespaces)
        // Only a complete label *sentence* (ends its own bold span with
        // terminal punctuation, e.g. "**Run health check.**") is a restated
        // label to drop. Mid-sentence emphasis of a single word or short
        // phrase with no terminal punctuation inside the bold span (e.g.
        // "**Complete** the setup") is not a label — it is part of the same
        // sentence and must keep its emphasized text (stripped elsewhere by
        // `stripMarkdownLinksAndEmphasis`, not dropped here).
        guard !label.isEmpty, !remainder.isEmpty, !remainder.contains("`"),
              label.hasSuffix(".") || label.hasSuffix("!") || label.hasSuffix("?") else { return raw }
        return listPrefix + remainder
    }

    func stripMarkdownLinksAndEmphasis(_ raw: String) -> String {
        var out = ""
        var i = raw.startIndex
        while i < raw.endIndex {
            if raw[i] == "[",
               let close = raw[i...].firstIndex(of: "]") {
                let afterClose = raw.index(after: close)
                if afterClose < raw.endIndex,
                   raw[afterClose] == "(",
                   let closeParen = raw[afterClose...].firstIndex(of: ")") {
                    out += raw[raw.index(after: i)..<close]
                    i = raw.index(after: closeParen)
                    continue
                }
            }
            if raw[i] == "*", raw.index(after: i) < raw.endIndex, raw[raw.index(after: i)] == "*" {
                i = raw.index(i, offsetBy: 2)
                continue
            }
            if raw[i] == "_", raw.index(after: i) < raw.endIndex, raw[raw.index(after: i)] == "_" {
                i = raw.index(i, offsetBy: 2)
                continue
            }
            out.append(raw[i])
            i = raw.index(after: i)
        }
        return out
    }

    func isProcedureCandidateLine(_ text: String, lexicon: EnglishLexicon) -> Bool {
        let lower = text.lowercased()
        let statementGrammar = lexicon.grammar.statement
        return lower.hasPrefix(statementGrammar.doPrefix)
            || statementGrammar.primitivePrefixes.contains { lower.hasPrefix($0) }
            || isWholeLineBacktickedCommand(text)
            || isChoiceGateLine(text, lexicon: lexicon)
    }

    /// AGENTS.md Phase 1 item 5: tolerates exactly one leading label line
    /// ending in `:` (e.g. "Use this structure:", "Report format:") that
    /// isn't itself template-shaped, as long as it precedes any real
    /// template content — the label introduces the template, it doesn't
    /// break it. Converts most of the corpus's inert `## Output Format`-style
    /// sections whose template rows are preceded by a one-line lead-in.
    func sectionIsTemplateBody(_ body: ArraySlice<String>) -> Bool {
        func isTemplateShaped(_ t: String) -> Bool {
            t.hasPrefix("|") || t.contains("{{") || t.hasPrefix("- ") || t.hasPrefix("* ")
        }
        var sawContent = false
        var inFence = false
        var sawLabel = false
        for raw in body {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                inFence.toggle()
                sawContent = true
                continue
            }
            if inFence {
                sawContent = true
                continue
            }
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            if !sawContent, !sawLabel, t.hasSuffix(":"), !isTemplateShaped(t) {
                sawLabel = true
                continue
            }
            sawContent = true
            if isTemplateShaped(t) { continue }
            return false
        }
        return sawContent
    }

    func sectionIsToolListBody(_ body: ArraySlice<String>) -> Bool {
        var sawContent = false
        for raw in body {
            let t = stripMarkdownListMarker(raw.trimmingCharacters(in: .whitespaces))
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            sawContent = true
            if isValidToolBullet(t) { continue }
            return false
        }
        return sawContent
    }

    func isValidToolBullet(_ t: String) -> Bool {
        if let open = t.lastIndex(of: "("), t.hasSuffix(")") {
            let id = String(t[t.index(after: open)..<t.index(before: t.endIndex)])
            return isToolID(id)
        }
        if t.hasPrefix("`"), let close = t.dropFirst().firstIndex(of: "`") {
            let id = String(t[t.index(after: t.startIndex)..<close])
            let rest = t[t.index(after: close)...].trimmingCharacters(in: .whitespaces)
            return isToolID(id) && (rest.hasPrefix("—") || rest.hasPrefix("--"))
        }
        return false
    }

    func isToolID(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return id.allSatisfy { ch in
            ch.isLetter || ch.isNumber || ch == "." || ch == "_" || ch == "-"
        }
    }

    func blockquoteBody(_ lines: [String], from start: Int, to end: Int? = nil) -> [String] {
        var out = lines
        let upper = end ?? lines.count
        guard start < upper else { return out }
        for i in start..<upper {
            let t = out[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            out[i] = "> " + out[i]
        }
        return out
    }

    func stripMarkdownListMarker(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("- ") || s.hasPrefix("* ") {
            return String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        if !digits.isEmpty, idx < s.endIndex, s[idx] == "." || s[idx] == ")" {
            let after = s.index(after: idx)
            if after == s.endIndex || s[after].isWhitespace {
                s = String(s[after...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return s
    }

    func isMarkdownListLine(_ raw: String) -> Bool {
        stripMarkdownListMarker(raw) != raw.trimmingCharacters(in: .whitespaces)
    }

    /// True when a trimmed line's own sentence/clause already ended on this
    /// raw line, so the paragraph-continuation scan above should NOT look at
    /// the next line as a wrapped continuation. Three cases: (1) it ends
    /// with sentence-terminal punctuation (`.`/`:`/`?`/`!` — `:` doubles as
    /// the existing annotation-label terminator, so treating it as "already
    /// complete" here doesn't change that separate lookahead); (2) it is
    /// already a complete whole-line backticked command; (3) it is already a
    /// complete choice-gate line. Markdown hard-wraps a paragraph by breaking
    /// *without* terminal punctuation on the intermediate lines, so this is a
    /// cheap, reliable signal that the line break was cosmetic, not semantic.
    func endsSentenceForSplitting(_ trimmed: String, lexicon: EnglishLexicon) -> Bool {
        if let last = trimmed.last, ".:?!".contains(last) { return true }
        let stripped = normalizeMarkdownLineForLowering(stripMarkdownListMarker(trimmed))
        return isWholeLineBacktickedCommand(stripped) || isChoiceGateLine(stripped, lexicon: lexicon)
    }

    func isWholeLineBacktickedCommand(_ s: String) -> Bool {
        MarkdownOutline.wholeLineBacktickedCommand(s)
    }

    func isChoiceGateLine(_ s: String, lexicon: EnglishLexicon) -> Bool {
        let lower = s.lowercased()
        return lexicon.grammar.choiceGateIntroducers.contains { lower.hasPrefix($0) }
            && s.filter { $0 == "\"" }.count >= 4
    }

    func isTaskListLine(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("[ ] ") || lower.hasPrefix("[x] ")
    }

    func stripTaskListBox(_ s: String) -> String {
        let lower = s.lowercased()
        if lower.hasPrefix("[ ] ") || lower.hasPrefix("[x] ") {
            return String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    func isMarkdownTableLine(_ s: String) -> Bool {
        s.contains("|")
    }
}
