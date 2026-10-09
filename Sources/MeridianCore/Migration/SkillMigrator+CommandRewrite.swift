import Foundation
import MeridianRuntime

extension SkillMigrator {
    // MARK: - Command hole rewrite (1B)

    /// Rewrite `<placeholder>` → `{placeholder}` inside command spans (inline
    /// backtick spans and fenced shell blocks), gated on scope resolution: only
    /// placeholders that name a frontmatter parameter (or the default `input`)
    /// are rewritten, so the result still strict-compiles. Unresolved
    /// placeholders are left as `<…>` (the author wires them up by hand — e.g.
    /// to a bind or loop variable — in the re-port). A heading-less or
    /// parameter-less document is returned untouched.
    func rewriteCommandPlaceholders(_ markdown: String, lexicon: EnglishLexicon) -> String {
        let lines = markdown.components(separatedBy: "\n")
        let scope = frontmatterParamScope(lines)
        guard !scope.isEmpty else { return markdown }
        var out: [String] = []
        var inShellFence = false
        for raw in lines {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                if !inShellFence {
                    let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    inShellFence = lexicon.isShellFence(lang)
                } else {
                    inShellFence = false
                }
                out.append(raw)
                continue
            }
            if inShellFence {
                out.append(rewriteAnglePlaceholders(raw, scope: scope))
            } else {
                out.append(rewriteInBacktickSpans(raw, scope: scope))
            }
        }
        return out.joined(separator: "\n")
    }

    /// Category-4 rescue for `--route-fuzzy` (default off): when strict compile
    /// proves a Markdown item inside a section cannot lower, and the caller has
    /// opted into downgrading hard errors to a reported-but-nonfatal skip for
    /// exploratory runs, mark the enclosing section `(( role: reference ))`
    /// (fully non-executable — never `(( inert ))`) and retry. With
    /// `routeFuzzy` off (the default), this rescue never runs and the
    /// diagnostic surfaces as a hard migration failure per P1 category 4.
    /// Original `SKILL.md` stays untouched; this only edits the generated
    /// `.meri` candidate.
    func markEnclosingSectionReference(forDiagnostic diagnostic: Diagnostic, in source: String) -> (source: String, warning: Diagnostic)? {
        guard options.routeFuzzy else { return nil }
        let line = diagnostic.primaryRange.startLine
        var lines = source.components(separatedBy: "\n")
        let target = max(0, min(line - 1, lines.count - 1))
        var headingIndex: Int?

        for i in stride(from: target, through: 0, by: -1) {
            if MarkdownOutline.headingMatch(lines[i]) != nil {
                headingIndex = i
                break
            }
        }
        guard let idx = headingIndex,
              let heading = MarkdownOutline.headingMatch(lines[idx]),
              !heading.text.hasSuffix("))") else {
            return nil
        }

        lines[idx] = "\(heading.hashes) \(heading.text) (( role: reference ))"
        let warning = Diagnostic.warning(
            .migrationRouteFuzzyDowngrade,
            message: "route-fuzzy marked section \"\(heading.text)\" as reference after \(diagnostic.code.id) at line \(line)",
            range: SourceRange(file: diagnostic.primaryRange.file, line: idx + 1, column: 1),
            notes: [
                DiagnosticNote("original diagnostic: \(diagnostic.message)", range: diagnostic.primaryRange)
            ],
            help: "Review this section and reword any operational content into deterministic Meridian before relying on the migrated skill."
        )
        return (lines.joined(separator: "\n"), warning)
    }

    func diagnosticLine(_ diagnostic: String) -> Int? {
        if diagnostic.hasPrefix("L") {
            let rest = diagnostic.dropFirst()
            let digits = rest.prefix { $0.isNumber }
            if !digits.isEmpty { return Int(digits) }
        }

        var i = diagnostic.startIndex
        while i < diagnostic.endIndex {
            guard diagnostic[i] == ":" else {
                i = diagnostic.index(after: i)
                continue
            }
            let lineStart = diagnostic.index(after: i)
            let lineDigits = diagnostic[lineStart...].prefix { $0.isNumber }
            guard !lineDigits.isEmpty else {
                i = lineStart
                continue
            }
            let afterLine = diagnostic.index(lineStart, offsetBy: lineDigits.count)
            if afterLine < diagnostic.endIndex, diagnostic[afterLine] == ":" {
                let columnStart = diagnostic.index(after: afterLine)
                let columnDigits = diagnostic[columnStart...].prefix { $0.isNumber }
                if !columnDigits.isEmpty { return Int(lineDigits) }
            }
            i = afterLine
        }
        return nil
    }

    /// Frontmatter `parameters:` names (inline comma list or `- ` items) plus the
    /// implicit `input` default, normalized for scope membership.
    func frontmatterParamScope(_ lines: [String]) -> Set<String> {
        var names: Set<String> = []
        guard let fm = Frontmatter.locate(lines, skipLeadingBlanks: false) else { return names }
        var inParams = false
        for raw in lines[(fm.open + 1)..<fm.close] {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if inParams, t.hasPrefix("-") {
                let item = t.dropFirst().trimmingCharacters(in: .whitespaces)
                if !item.isEmpty { names.insert(SkillMigrator.scopeKey(item)) }
                continue
            }
            inParams = false
            if let colon = t.firstIndex(of: ":") {
                let key = t[t.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                if key == "parameters" || key == "input" {
                    let value = t[t.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if value.isEmpty {
                        inParams = true
                    } else {
                        for part in value.split(separator: ",") {
                            let p = part.trimmingCharacters(in: .whitespaces)
                            if !p.isEmpty { names.insert(SkillMigrator.scopeKey(p)) }
                        }
                    }
                }
            }
        }
        // The implicit single `input` parameter is always in scope for a
        // parameter-less skill.
        names.insert("input")
        return names
    }

    /// Apply the angle-placeholder rewrite only inside backtick spans of a line.
    func rewriteInBacktickSpans(_ line: String, scope: Set<String>) -> String {
        guard line.contains("`") else { return line }
        var out = ""
        var inSpan = false
        var span = ""
        for ch in line {
            if ch == "`" {
                if inSpan { out += rewriteAnglePlaceholders(span, scope: scope); span = ""; out.append(ch) }
                else { out.append(ch) }
                inSpan.toggle()
                continue
            }
            if inSpan { span.append(ch) } else { out.append(ch) }
        }
        if inSpan { out += "`" + span }  // unterminated span — leave verbatim
        return out
    }

    /// Replace `<x>` with `{x}` when `x` is word-shaped and resolves in `scope`.
    func rewriteAnglePlaceholders(_ s: String, scope: Set<String>) -> String {
        guard s.contains("<") else { return s }
        var out = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            if chars[i] == "<" {
                var j = i + 1
                var inner = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == ">" { closed = true; break }
                    if chars[j] == "<" { break }
                    inner.append(chars[j]); j += 1
                }
                let trimmed = inner.trimmingCharacters(in: .whitespaces)
                if closed, SkillMigrator.isWordShaped(trimmed), scope.contains(SkillMigrator.scopeKey(trimmed)) {
                    out += "{\(trimmed)}"
                    i = j + 1
                    continue
                }
            }
            out.append(chars[i]); i += 1
        }
        return out
    }

    static func isWordShaped(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        var sawLetter = false
        for ch in s {
            if ch.isLetter { sawLetter = true; continue }
            if ch.isNumber || ch == " " || ch == "'" || ch == "\u{2019}" || ch == "-" || ch == "_" { continue }
            return false
        }
        return sawLetter
    }

    static func scopeKey(_ s: String) -> String { ScopeNaming.key(s) }
}
