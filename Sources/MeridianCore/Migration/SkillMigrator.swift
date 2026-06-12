import Foundation

// MARK: - SkillMigrator
//
// Authoring-time tool that converts a gbrain `SKILL.md` into a strict-compiling
// `.meri`. It is the inverse-friendly companion to the rulebook engine:
//
//   1. Deterministic transform — the marking pass. It injects no frontmatter
//      (section semantics activate structurally on any `##`/`###` heading, and
//      the CLI autodiscovers `.merconfig`/`.merrules`), but it blockquotes
//      pre-heading preamble and appends an authoritative `(( … ))` marker to
//      every heading that would not otherwise resolve to an executable role
//      (prose Contract/Anti-Patterns → inert-with-role, pure-shell unknown →
//      `(( role: procedure ))`, other unknown → `(( inert ))`). It does NOT
//      strip `skill: true` (a one-time corpus edit). See `deterministicTransform`.
//   2. Strict compile — run the candidate through `Compiler` exactly like a
//      hand-authored file.
//   3. Bounded repair — when compilation fails AND a repair closure is
//      supplied, hand the diagnostic + candidate to the closure (which may be
//      LLM-backed) for at most `maxRepair` rounds. The closure may ONLY
//      rephrase a flagged line into a resolvable phrase or wrap a genuine
//      judgment step in an explicit `use judgment to …:` marker — it can never
//      introduce a silent LLM path, because the result is re-compiled strict.
//
// LLM proposes, compiler disposes: a migration is "successful" only when the
// emitted `.meri` passes the same strict compile as a hand-authored file. The
// repair closure is a Core-LOCAL `(RepairRequest) async throws -> String`, so
// `MeridianCore` keeps no dependency on `MeridianRuntime`'s `LLMProvider`; the
// CLI adapts a concrete provider to this closure, and tests pass an inline one.

public struct SkillMigrator {

    public struct Options: Sendable {
        /// Maximum repair rounds (0 = deterministic-only).
        public var maxRepair: Int

        public init(maxRepair: Int = 0) {
            self.maxRepair = maxRepair
        }
    }

    /// A request handed to the repair closure when a candidate fails strict
    /// compilation. The closure returns a revised `.meri` source.
    public struct RepairRequest: Sendable {
        public let candidate: String
        public let diagnostic: String
        public let attempt: Int
    }

    public struct Report: Sendable {
        public var compiledOK: Bool
        public var repairAttempts: Int
        public var diagnostics: [String]
        public var addedFrontmatterKeys: [String]
        public var originalLineCount: Int
        public var resultLineCount: Int
        /// Lines changed vs the original (added frontmatter keys + repair rounds).
        public var editCount: Int
    }

    public struct Result: Sendable {
        public var meriSource: String
        public var report: Report
        public var compiledOK: Bool
    }

    let compiler: Compiler
    let vocabularies: [Compiler.VocabularyInput]
    let rulebookInputs: [RulebookInput]
    let options: Options
    let repair: (@Sendable (RepairRequest) async throws -> String)?

    public init(compiler: Compiler,
                vocabularies: [Compiler.VocabularyInput],
                rulebooks: [RulebookInput] = [],
                options: Options = Options(),
                repair: (@Sendable (RepairRequest) async throws -> String)? = nil) {
        self.compiler = compiler
        self.vocabularies = vocabularies
        self.rulebookInputs = rulebooks
        self.options = options
        self.repair = repair
    }

    public func migrate(_ markdown: String, file: String = "skill.meri") async throws -> Result {
        let (transformed, addedKeys) = deterministicTransform(markdown)
        let originalLineCount = markdown.components(separatedBy: "\n").count

        var candidate = transformed
        var diagnostics: [String] = []
        var attempts = 0

        while true {
            do {
                _ = try compiler.compile(
                    meridianSource: candidate, meridianFile: file,
                    vocabularies: vocabularies, rulebooks: rulebookInputs
                )
                return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                              attempts: attempts, originalLineCount: originalLineCount,
                              compiledOK: true)
            } catch {
                let diag = describe(error)
                diagnostics.append(diag)
                guard let repair, attempts < options.maxRepair else {
                    return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                                  attempts: attempts, originalLineCount: originalLineCount,
                                  compiledOK: false)
                }
                attempts += 1
                candidate = try await repair(RepairRequest(
                    candidate: candidate, diagnostic: diag, attempt: attempts))
            }
        }
    }

    // MARK: - Deterministic transform

    /// The reusable, deterministic marking pass. It injects **no frontmatter**
    /// (section semantics activate structurally on `##`/`###` headings, and the
    /// CLI autodiscovers `.merconfig`/`.merrules`) — instead it does the two
    /// edits the universal-sections model needs to make a `SKILL.md`-shaped
    /// document compile with minimal change:
    ///
    ///   1. **Blockquote preamble** — any non-comment content before the first
    ///      heading is prefixed with `> ` (a markdown blockquote, treated as a
    ///      comment by the tokenizer), so it doesn't trip the "content before
    ///      the first heading" hard error.
    ///   2. **Mark headings** — append an authoritative `(( … ))` marker to each
    ///      heading that would otherwise not resolve to an executable role:
    ///        • Contract/Guarantees/Invariants → `(( inert, role: invariants ))`
    ///          (the gbrain corpus states these as prose, not checkable predicates)
    ///        • Anti-Patterns/Avoid/Pitfalls   → `(( inert, role: prohibitions ))`
    ///        • a recognized procedure/applicability/negative/template heading
    ///          → left unmarked (it lowers as that role)
    ///        • an unrecognized heading whose body is *only* shell fences
    ///          → `(( role: procedure ))` (the fences stay deterministic
    ///          `shell.run` invokes)
    ///        • every other unrecognized heading → `(( inert ))`
    ///
    /// Idempotent (an already-marked heading is left untouched) and
    /// frontmatter-preserving. It does NOT strip `skill: true` — that is a
    /// one-time corpus edit, not a reusable transform. Role recognition uses the
    /// built-in alias table (`SkillSectionRole.builtinRole`); idiosyncratic
    /// organizational headings get `(( inert ))` and are the author's residue to
    /// resolve (split into a procedure section, alias in the rulebook, or keep
    /// inert). `addedKeys` is always empty — the pass adds no frontmatter.
    func deterministicTransform(_ markdown: String) -> (source: String, addedKeys: [String]) {
        (rewriteCommandPlaceholders(markSections(markdown)), [])
    }

    // MARK: - Command hole rewrite (1B)

    /// Rewrite `<placeholder>` → `{placeholder}` inside command spans (inline
    /// backtick spans and fenced shell blocks), gated on scope resolution: only
    /// placeholders that name a frontmatter parameter (or the default `input`)
    /// are rewritten, so the result still strict-compiles. Unresolved
    /// placeholders are left as `<…>` (the author wires them up by hand — e.g.
    /// to a bind or loop variable — in the re-port). A heading-less or
    /// parameter-less document is returned untouched.
    func rewriteCommandPlaceholders(_ markdown: String) -> String {
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
                    inShellFence = shellFenceLanguages.contains(lang)
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

    /// Frontmatter `parameters:` names (inline comma list or `- ` items) plus the
    /// implicit `input` default, normalized for scope membership.
    private func frontmatterParamScope(_ lines: [String]) -> Set<String> {
        var names: Set<String> = []
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return names }
        var i = 1
        var inParams = false
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t == "---" { break }
            if inParams, t.hasPrefix("-") {
                let item = t.dropFirst().trimmingCharacters(in: .whitespaces)
                if !item.isEmpty { names.insert(SkillMigrator.scopeKey(item)) }
                i += 1; continue
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
            i += 1
        }
        // The implicit single `input` parameter is always in scope for a
        // parameter-less skill.
        names.insert("input")
        return names
    }

    /// Apply the angle-placeholder rewrite only inside backtick spans of a line.
    private func rewriteInBacktickSpans(_ line: String, scope: Set<String>) -> String {
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
    private func rewriteAnglePlaceholders(_ s: String, scope: Set<String>) -> String {
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

    static func scopeKey(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// Apply the blockquote-preamble + heading-marker pass (see
    /// `deterministicTransform`). A heading-less document is returned untouched.
    func markSections(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        let bodyStart = frontmatterEnd(lines)

        let headingIdxs = lines.indices.filter { $0 >= bodyStart && headingMatch(lines[$0]) != nil }
        guard let firstHeading = headingIdxs.first else { return markdown }

        // 1. Blockquote preamble (body lines before the first heading).
        if firstHeading > bodyStart {
            for i in bodyStart..<firstHeading {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
                lines[i] = "> " + lines[i]
            }
        }

        // 2. Mark headings.
        for (k, idx) in headingIdxs.enumerated() {
            guard let m = headingMatch(lines[idx]) else { continue }
            if m.text.hasSuffix("))") { continue }   // already marked — idempotent
            let end = (k + 1 < headingIdxs.count) ? headingIdxs[k + 1] : lines.count
            let body = lines[(idx + 1)..<end]
            if let marker = marker(forHeading: m.text, body: body) {
                lines[idx] = "\(m.hashes) \(m.text) \(marker)"
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Marking helpers

    /// Index of the first body line (after a leading `--- … ---` frontmatter
    /// block), or 0 when there is no frontmatter.
    private func frontmatterEnd(_ lines: [String]) -> Int {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return 0 }
        var i = 1
        while i < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" { return i + 1 }
            i += 1
        }
        return 0
    }

    /// Recognize a `##`…`######` heading line (no leading whitespace, at least
    /// one space after the hashes, non-empty text). Returns the hash run and the
    /// trimmed heading text.
    private func headingMatch(_ line: String) -> (hashes: String, text: String)? {
        guard line.hasPrefix("##") else { return nil }
        var hashes = 0
        for ch in line { if ch == "#" { hashes += 1 } else { break } }
        guard (2...6).contains(hashes) else { return nil }
        let after = line.dropFirst(hashes)
        guard let first = after.first, first == " " || first == "\t" else { return nil }
        let text = after.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (String(repeating: "#", count: hashes), text)
    }

    /// The marker to append to `heading` (or nil to leave it unmarked), chosen by
    /// the built-in role alias and, for unrecognized headings, whether the body
    /// restates a rulebook convention, then whether the body is pure shell.
    private func marker(forHeading heading: String, body: ArraySlice<String>) -> String? {
        switch SkillSectionRole.builtinRole(forHeading: heading) {
        case .invariants:
            return "(( inert, role: invariants ))"
        case .prohibitions:
            return "(( inert, role: prohibitions ))"
        case .some:
            // procedure / applicability / negative-applicability / template /
            // tools — these lower as their role, leave them unmarked.
            return nil
        case .none:
            // 1D: a section whose body verbatim restates an external rulebook
            // convention is recorded as `convention-ref` (inert metadata) rather
            // than generic inert prose.
            if bodyRestatesConvention(body) { return "(( inert, role: convention-ref ))" }
            return sectionIsPureShell(body) ? "(( role: procedure ))" : "(( inert ))"
        }
    }

    /// Lazily-parsed, normalized rulebook convention strings (each rule's
    /// `action` and `body`) used for convention-restatement detection.
    private var conventionStrings: Set<String> {
        var out: Set<String> = []
        for input in rulebookInputs {
            guard let book = try? RulebookParser().parse(input.source, file: input.file) else { continue }
            for rule in book.conventions {
                let action = SkillMigrator.normalizeConvention(rule.action)
                let body = SkillMigrator.normalizeConvention(rule.body)
                if !action.isEmpty { out.insert(action) }
                if !body.isEmpty { out.insert(body) }
            }
        }
        return out
    }

    /// True iff every non-blank, non-fence body line restates a known rulebook
    /// convention (exact, case-insensitive, punctuation/whitespace-normalized).
    private func bodyRestatesConvention(_ body: ArraySlice<String>) -> Bool {
        let conventions = conventionStrings
        guard !conventions.isEmpty else { return false }
        var sawContent = false
        var inFence = false
        for raw in body {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") { inFence.toggle(); continue }
            if inFence || t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            sawContent = true
            let normalized = SkillMigrator.normalizeConvention(t)
            if !conventions.contains(normalized) { return false }
        }
        return sawContent
    }

    /// Normalize a convention/section line for exact comparison: lowercased,
    /// list-marker stripped, internal whitespace collapsed, trailing punctuation
    /// removed.
    static func normalizeConvention(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        for marker in ["- ", "* ", "+ "] where t.hasPrefix(marker) {
            t = String(t.dropFirst(marker.count)); break
        }
        let collapsed = t.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
    }

    /// True iff every non-blank body line lives inside a shell fence
    /// (```bash/```sh/…) — i.e. the section is only deterministic shell commands.
    private func sectionIsPureShell(_ body: ArraySlice<String>) -> Bool {
        var inFence = false
        var sawShell = false
        var sawOther = false
        for raw in body {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                if !inFence {
                    inFence = true
                    let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if shellFenceLanguages.contains(lang) { sawShell = true } else { sawOther = true }
                } else {
                    inFence = false
                }
                continue
            }
            if inFence { continue }
            if t.isEmpty { continue }
            sawOther = true
        }
        return sawShell && !sawOther
    }

    // MARK: - Helpers

    private func result(_ source: String, addedKeys: [String], diagnostics: [String],
                        attempts: Int, originalLineCount: Int, compiledOK: Bool) -> Result {
        let resultLineCount = source.components(separatedBy: "\n").count
        let report = Report(
            compiledOK: compiledOK,
            repairAttempts: attempts,
            diagnostics: diagnostics,
            addedFrontmatterKeys: addedKeys,
            originalLineCount: originalLineCount,
            resultLineCount: resultLineCount,
            editCount: addedKeys.count + attempts
        )
        return Result(meriSource: source, report: report, compiledOK: compiledOK)
    }

    private func describe(_ error: any Error) -> String {
        if let compilerError = error as? CompilerError {
            switch compilerError {
            case .semanticError(let message, let range):
                return "L\(range.startLine): \(message)"
            default:
                return String(describing: compilerError)
            }
        }
        return String(describing: error)
    }
}
