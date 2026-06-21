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

    /// A markdown heading the migrator routed to a closed section role via a
    /// rulebook `=== sections ===` alias (instead of an inline `(( … ))` marker).
    /// The CLI persists these to the rulebook so future compiles/re-migrations
    /// recognize the heading with no in-file marker.
    public struct SectionAlias: Sendable, Equatable {
        public let heading: String
        public let role: SkillSectionRole
        public init(heading: String, role: SkillSectionRole) {
            self.heading = heading
            self.role = role
        }
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
        /// Section-role aliases the migrator emitted for the rulebook (each an
        /// unrecognized executable heading routed to a closed role). Empty when
        /// every heading resolved via a built-in role or an inline marker.
        public var sectionAliases: [SectionAlias]
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
        let (transformed, addedKeys, aliases) = deterministicTransform(markdown)
        let originalLineCount = markdown.components(separatedBy: "\n").count

        // The aliases the marking pass chose (e.g. a pure-shell heading routed to
        // `procedure`) are left UNMARKED in the .meri, so they must be supplied to
        // the strict compile as a synthetic rulebook — otherwise an unrecognized
        // heading with content is a hard error. The CLI persists the same aliases
        // to the on-disk rulebook so the written .meri compiles standalone.
        let effectiveRulebooks = rulebookInputs + Self.aliasRulebook(aliases)

        var candidate = transformed
        var diagnostics: [String] = []
        var attempts = 0

        while true {
            do {
                _ = try compiler.compile(
                    meridianSource: candidate, meridianFile: file,
                    vocabularies: vocabularies, rulebooks: effectiveRulebooks
                )
                return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                              attempts: attempts, originalLineCount: originalLineCount,
                              compiledOK: true, aliases: aliases)
            } catch {
                let diag = describe(error)
                diagnostics.append(diag)
                guard let repair, attempts < options.maxRepair else {
                    return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                                  attempts: attempts, originalLineCount: originalLineCount,
                                  compiledOK: false, aliases: aliases)
                }
                attempts += 1
                candidate = try await repair(RepairRequest(
                    candidate: candidate, diagnostic: diag, attempt: attempts))
            }
        }
    }

    /// Render section aliases as a synthetic `=== sections ===` rulebook input
    /// (empty array → no input), so the marking pass's unmarked executable
    /// headings resolve during the strict compile.
    static func aliasRulebook(_ aliases: [SectionAlias]) -> [RulebookInput] {
        guard !aliases.isEmpty else { return [] }
        var lines = ["=== sections ==="]
        for a in aliases {
            lines.append("section \"\(a.heading)\" -> \(a.role.rawValue)")
        }
        return [RulebookInput(name: "__migrator-section-aliases__",
                              file: "__migrator-section-aliases__.merrules",
                              source: lines.joined(separator: "\n") + "\n")]
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
    func deterministicTransform(_ markdown: String)
        -> (source: String, addedKeys: [String], aliases: [SectionAlias]) {
        let (marked, aliases) = markSections(markdown)
        return (rewriteCommandPlaceholders(marked), [], aliases)
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
                    inShellFence = isShellFence(lang)
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
        guard let fm = FrontmatterScanner.locate(lines, skipLeadingBlanks: false) else { return names }
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

    static func scopeKey(_ s: String) -> String { ScopeNaming.key(s) }

    /// Apply the blockquote-preamble + heading-marker pass (see
    /// `deterministicTransform`). A heading-less document is returned untouched.
    func markSections(_ markdown: String) -> (markdown: String, aliases: [SectionAlias]) {
        var lines = markdown.components(separatedBy: "\n")
        let bodyStart = frontmatterEnd(lines)

        let headingIdxs = lines.indices.filter { $0 >= bodyStart && headingMatch(lines[$0]) != nil }
        guard let firstHeading = headingIdxs.first else { return (markdown, []) }

        // 1. Blockquote preamble (body lines before the first heading).
        if firstHeading > bodyStart {
            for i in bodyStart..<firstHeading {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
                lines[i] = "> " + lines[i]
            }
        }

        // 2. Mark headings (or route to a rulebook alias).
        var aliases: [SectionAlias] = []
        for (k, idx) in headingIdxs.enumerated() {
            guard let m = headingMatch(lines[idx]) else { continue }
            if m.text.hasSuffix("))") { continue }   // already marked — idempotent
            let end = (k + 1 < headingIdxs.count) ? headingIdxs[k + 1] : lines.count
            let body = lines[(idx + 1)..<end]
            switch decision(forHeading: m.text, body: body) {
            case .leaveUnmarked:
                break
            case .inline(let marker):
                lines[idx] = "\(m.hashes) \(m.text) \(marker)"
            case .alias(let role):
                // Leave the heading clean; the role is supplied via a rulebook
                // `=== sections ===` alias the CLI persists.
                aliases.append(SectionAlias(heading: m.text, role: role))
            }
        }
        return (lines.joined(separator: "\n"), aliases)
    }

    // MARK: - Marking helpers

    /// Index of the first body line (after a leading `--- … ---` frontmatter
    /// block), or 0 when there is no frontmatter.
    private func frontmatterEnd(_ lines: [String]) -> Int {
        FrontmatterScanner.locate(lines, skipLeadingBlanks: false).map { $0.close + 1 } ?? 0
    }

    private func headingMatch(_ line: String) -> (hashes: String, text: String)? {
        SkillMarkdownShape.headingMatch(line)
    }

    /// How the marking pass handles a heading.
    private enum MarkDecision {
        /// Recognized role — leave the heading clean, no marker, no alias.
        case leaveUnmarked
        /// Append an inline `(( … ))` marker (inert / invariants / prohibitions /
        /// convention-ref — non-executable or role-restating prose).
        case inline(String)
        /// Route to a closed role via a rulebook `=== sections ===` alias instead
        /// of an inline `(( role: … ))` marker. Used for unrecognized *executable*
        /// headings (a pure-shell section), so the heading stays clean and the
        /// role lives as reusable rulebook data.
        case alias(SkillSectionRole)
    }

    /// Decide how to handle `heading`, by the built-in role alias and, for
    /// unrecognized headings, whether the body restates a rulebook convention,
    /// then whether the body is provably executable-only.
    private func decision(forHeading heading: String, body: ArraySlice<String>) -> MarkDecision {
        switch SkillSectionRole.builtinRole(forHeading: heading) {
        case .invariants:
            return sectionIsCheckableRoleBody(body) ? .leaveUnmarked : .inline("(( inert, role: invariants ))")
        case .prohibitions:
            return sectionIsCheckableRoleBody(body) ? .leaveUnmarked : .inline("(( inert, role: prohibitions ))")
        case .some:
            // procedure / applicability / negative-applicability / template /
            // tools — these lower as their role, leave them unmarked.
            return .leaveUnmarked
        case .none:
            // 1D: a section whose body verbatim restates an external rulebook
            // convention is recorded as `convention-ref` (inert metadata) rather
            // than generic inert prose.
            if bodyRestatesConvention(body) { return .inline("(( inert, role: convention-ref ))") }
            // An unrecognized *executable* heading is routed to
            // `procedure` via a rulebook alias — preferred over an inline marker
            // (see AGENTS.md §16 / docs/13). Other unknowns stay inert prose.
            return sectionIsExecutableOnly(body) ? .alias(.procedure) : .inline("(( inert ))")
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
        Rulebook.normalizeLine(s, stripListMarkers: true)
    }

    /// True iff every non-blank body line is a structurally checkable predicate
    /// once Markdown bullet/number markers are stripped. This is intentionally
    /// all-or-nothing: one narrative intro line keeps the section inert so the
    /// author can split prose from executable assertions.
    private func sectionIsCheckableRoleBody(_ body: ArraySlice<String>) -> Bool {
        let classifier = ConditionClassifier(symbols: nil, lexicon: .default, trace: .silent())
        var sawContent = false
        for raw in body {
            let t = stripMarkdownListMarker(raw.trimmingCharacters(in: .whitespaces))
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            sawContent = true
            if case .checkable = classifier.classify(t) { continue }
            return false
        }
        return sawContent
    }

    /// True iff every non-blank body line is already executable by today's
    /// deterministic Markdown surface: shell fences, whole-line backticked
    /// commands, explicit block markers, checkable task-list items, or a
    /// choice-gate with quoted options. It deliberately rejects mixed prose.
    private func sectionIsExecutableOnly(_ body: ArraySlice<String>) -> Bool {
        var inShellFence = false
        var inNonShellFence = false
        var sawContent = false
        var pendingTableMarker = false
        var pendingChecklistMarker = false
        let classifier = ConditionClassifier(symbols: nil, lexicon: .default, trace: .silent())

        for raw in body {
            var t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                if !inShellFence && !inNonShellFence {
                    let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if isShellFence(lang) {
                        inShellFence = true
                        sawContent = true
                    } else {
                        inNonShellFence = true
                    }
                } else {
                    inShellFence = false
                    inNonShellFence = false
                }
                continue
            }
            if inShellFence { continue }
            if inNonShellFence { return false }
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }

            t = stripMarkdownListMarker(t)
            if t.isEmpty { continue }
            sawContent = true

            if t.hasPrefix("!!! table") {
                pendingTableMarker = !t.lowercased().contains(TableMode.inert.sentinelToken)
                continue
            }
            if pendingTableMarker {
                if isMarkdownTableLine(t) { continue }
                pendingTableMarker = false
            }

            if t.hasPrefix("!!! checklist") {
                pendingChecklistMarker = !t.lowercased().contains(ChecklistMode.inert.sentinelToken)
                continue
            }
            if pendingChecklistMarker {
                if isTaskListLine(t) { continue }
                pendingChecklistMarker = false
            }

            if isWholeLineBacktickedCommand(t) { continue }
            if isChoiceGateLine(t) { continue }
            if isTaskListLine(t) {
                let item = stripTaskListBox(t)
                if case .checkable = classifier.classify(item) { continue }
            }
            return false
        }
        return sawContent
    }

    private func stripMarkdownListMarker(_ raw: String) -> String {
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

    private func isWholeLineBacktickedCommand(_ s: String) -> Bool {
        SkillMarkdownShape.wholeLineBacktickedCommand(s)
    }

    private func isChoiceGateLine(_ s: String) -> Bool {
        let lower = s.lowercased()
        return EnglishLexicon.default.grammar.choiceGateIntroducers.contains { lower.hasPrefix($0) }
            && s.filter { $0 == "\"" }.count >= 4
    }

    private func isTaskListLine(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.hasPrefix("[ ] ") || lower.hasPrefix("[x] ")
    }

    private func stripTaskListBox(_ s: String) -> String {
        let lower = s.lowercased()
        if lower.hasPrefix("[ ] ") || lower.hasPrefix("[x] ") {
            return String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func isMarkdownTableLine(_ s: String) -> Bool {
        s.contains("|")
    }

    // MARK: - Helpers

    private func result(_ source: String, addedKeys: [String], diagnostics: [String],
                        attempts: Int, originalLineCount: Int, compiledOK: Bool,
                        aliases: [SectionAlias]) -> Result {
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
        return Result(meriSource: source, report: report, compiledOK: compiledOK,
                      sectionAliases: aliases)
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
