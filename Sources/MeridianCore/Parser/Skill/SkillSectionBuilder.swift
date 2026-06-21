import Foundation
import MeridianRuntime

// MARK: - SkillSectionBuilder
//
// Universal, strictly-deterministic lowering of markdown sections in any
// heading-bearing `.meri` document. The builder groups the implicit-workflow
// body by its preceding `##`/`###` heading, resolves each heading to a closed
// `SkillSectionRole`, and rewrites each executable section's statements to
// canonical Meridian text per role:
//
//   • invariants   (Contract)        → `make sure {cond}.`         (checkable only)
//   • applicability (When To Use)     → `complete unless {cond}.`   (precondition skip)
//   • negative      (When NOT To Use) → `complete only when {cond}.`(soft skip)
//   • prohibitions  (Anti-Patterns)   → `make sure not ({cond}).`   (checkable only)
//   • procedure     (Phases)          → unchanged
//   • template / inert                → recorded in the manifest, never executed
//
// Role resolution is authoritative-marker-first:
//   1. A trailing `(( … ))` marker on the heading wins. `(( inert ))` is
//      non-executable with no role; `(( inert, role: R ))` is non-executable
//      with the recorded role R; `(( role: R ))` forces role R (executable iff
//      R is executable). When a marker is present the heading text is never
//      used to derive a role — for documentation we do not guess.
//   2. Otherwise the executable role is derived from the clean heading text
//      (rulebook `=== sections ===` alias, then built-in alias).
//   3. An unmarked heading that derives nothing is `unresolved`: a hard error
//      if its section has content.
//
// No silent drops: a non-checkable invariant/prohibition item is a hard error
// (rephrase to a checkable predicate or mark `(( inert ))`); content before the
// first heading is a hard error; an unrecognized heading with content is a hard
// error. Every section — executable and non-executable alike — is recorded into
// `Result.sections` for the manifest.

struct SkillSectionBuilder {
    let symbols: SymbolTable
    let lexicon: EnglishLexicon
    let trace: ParserTrace
    let rulebook: Rulebook
    let file: String

    /// One top-level statement plus any deeper-indented continuation lines.
    struct StatementGroup {
        let lines: [SourceLine]
        var head: SourceLine { lines[0] }
        var isMultiline: Bool { lines.count > 1 }
    }

    /// A resolved section: its heading, role (nil = preamble/unresolved), the
    /// executes flag, the manifest role label, and its folded content groups.
    private struct ResolvedSection {
        let heading: String          // clean heading ("" for preamble)
        let headingLine: Int
        let role: SkillSectionRole?  // nil for preamble / unresolved
        let executes: Bool
        let recordedRole: String
        let groups: [StatementGroup]
        let rawLines: [SourceLine]
        let isPreamble: Bool
    }

    /// The result of section lowering: canonical body lines (preconditions and
    /// asserts first, then the procedure in source order), the literal dispatch
    /// phrases mined from applicability sections, and a record of every section
    /// (for the manifest).
    struct Result {
        var bodyLines: [SourceLine]
        var dispatchPhrases: [String]
        var negativeDispatchPhrases: [String]
        var sections: [SkillSectionRecord]
        /// Tool IDs mined from a `## Tools Used` section (1D), in source order.
        var toolsUsed: [String]
    }

    /// Build the canonical implicit-workflow body from the raw region lines
    /// (statements + interleaved heading lines).
    func build(regionLines: [SourceLine]) throws -> Result {
        let sections = try splitSections(regionLines)
        var prelude: [SourceLine] = []
        var procedure: [SourceLine] = []
        var dispatch: [String] = []
        var negativeDispatch: [String] = []
        var records: [SkillSectionRecord] = []
        var toolsUsed: [String] = []

        for sec in sections {
            // Content before the first heading is never executable and must not
            // be silently dropped. (When the document has no headings at all the
            // builder is not invoked; the body is parsed verbatim instead.)
            if sec.isPreamble {
                if !sec.rawLines.isEmpty {
                    try raiseStructural(
                        .sectionStructuralError,
                        message: "content before the first heading: \"\(sec.rawLines[0].statement)\". Every line in a sectioned document must live under a heading — move it under a heading, or make it a comment (`#`/`>`).",
                        range: SourceRange(file: file, line: sec.rawLines[0].number, column: 1),
                        help: "Move the line under a `##`/`###` heading or prefix it with `#` or `>` to make it a comment.")
                }
                continue
            }

            // Record EVERY section (executable or not) for the manifest.
            records.append(SkillSectionRecord(
                heading: sec.heading,
                role: sec.recordedRole,
                executes: sec.executes,
                lines: sec.rawLines.map(\.statement),
                line: sec.headingLine
            ))

            // `## Tools Used` is non-executable but metadata-extracting: mine
            // each bullet's `(<tool_id>)` into the scoped-tool set. Malformed
            // bullets are a hard error (no silent drops).
            if sec.role == .tools {
                for group in sec.groups {
                    toolsUsed.append(try extractToolID(from: group))
                }
                continue
            }

            guard sec.executes, let role = sec.role else {
                trace.log(.skill, "section '\(sec.heading)' role \(sec.recordedRole) non-executable @L\(sec.headingLine)")
                continue
            }

            for group in sec.groups {
                // A verbatim shell-command block is an explicit, deterministic
                // `shell.run` invoke. Within an executable section it stays
                // executable; a non-executable (marked) section never reaches
                // here, so the marker overrides shell-block routing.
                if group.lines.allSatisfy(isShellCodeBlock) {
                    procedure.append(contentsOf: group.lines)
                    continue
                }
                switch role {
                case .procedure:
                    procedure.append(contentsOf: group.lines)
                case .tables:
                    procedure.append(contentsOf: group.lines.map(tableLineDefaultingToData))
                case .invariants:
                    prelude.append(try assertLine(for: group, role: role, negated: false))
                case .prohibitions:
                    prelude.append(try assertLine(for: group, role: role, negated: true))
                case .applicability:
                    try applyApplicability(group, negated: false, prelude: &prelude, dispatch: &dispatch)
                case .negativeApplicability:
                    try applyApplicability(group, negated: true, prelude: &prelude, dispatch: &negativeDispatch)
                case .template, .domain, .tools, .conventionRef, .inert:
                    // Non-executable roles never have executes == true.
                    break
                }
            }
        }
        return Result(bodyLines: prelude + procedure,
                      dispatchPhrases: dispatch,
                      negativeDispatchPhrases: negativeDispatch,
                      sections: records,
                      toolsUsed: toolsUsed)
    }

    /// Extract a tool id from a `## Tools Used` bullet. Two equally-valid forms
    /// are accepted (authors keep whichever reads better):
    ///   • trailing parens — `<description> (<tool_id>)`
    ///   • leading backticks — `` `<tool_id>` — <description> `` (any separator)
    /// The id must be letters/digits/`.`/`_`/`-`. A bullet matching neither form
    /// (or whose candidate id is not a valid identifier) is a hard error.
    private func extractToolID(from group: StatementGroup) throws -> String {
        let text = group.head.statement.trimmingCharacters(in: .whitespaces)
        let line = group.head.number

        // Form 1: id in trailing parentheses. Backwards search so a description
        // that itself contains parentheses keeps the LAST `(…)` as the id.
        if let open = text.range(of: "(", options: .backwards),
           let close = text.range(of: ")", options: .backwards),
           open.upperBound < close.lowerBound {
            let id = String(text[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespaces)
            if isValidToolID(id) { return id }
        }

        // Form 2: id in leading backticks (`` `search` — keyword search``). The
        // backticked token must be a bare tool id — a backticked CLI command
        // (`` `gbrain init …` ``) has spaces and so is correctly rejected.
        if text.hasPrefix("`"), let closeTick = text.dropFirst().firstIndex(of: "`") {
            let id = String(text[text.index(after: text.startIndex)..<closeTick]).trimmingCharacters(in: .whitespaces)
            if isValidToolID(id) { return id }
        }

        throw CompilerError.diagnostics([
            Diagnostic.structural(
                .sectionStructuralError,
                message: "malformed `Tools Used` bullet \"\(text)\": expected `<description> (<tool_id>)` or `` `<tool_id>` — <description> ``. A tool id is letters, digits, `.`, `_`, or `-` (e.g. `gbrain_search`, `http.get`).",
                range: SourceRange(file: file, line: line, column: 1),
                help: "Use `<description> (<tool_id>)` or `` `<tool_id>` — <description> `` with a bare tool id (no spaces inside backticks).")
        ])
    }

    private func tableLineDefaultingToData(_ line: SourceLine) -> SourceLine {
        guard let (mode, body) = decodeTableSentinel(line.text), mode == .decision else {
            return line
        }
        let sentinel = tableSentinelPrefix
            + TableMode.data(name: nil).sentinelToken
            + ":"
            + Data(body.utf8).base64EncodedString()
        return SourceLine(
            indent: line.indent,
            text: sentinel,
            raw: line.raw,
            number: line.number,
            listMarker: line.listMarker,
            headingLevel: line.headingLevel,
            isChecklist: line.isChecklist,
            checklistChecked: line.checklistChecked
        )
    }

    private func isValidToolID(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }

    // MARK: Section splitting

    private func splitSections(_ lines: [SourceLine]) throws -> [ResolvedSection] {
        let hasHeadings = lines.contains { ($0.headingLevel ?? 0) > 0 }
        let baseIndent = lines.filter { $0.headingLevel == nil && $0.isContent }.map(\.indent).min() ?? 0

        // Accumulate raw content lines per section, then resolve + fold.
        struct PendingSection {
            var heading: String?      // nil for preamble
            var headingLine: Int
            var lines: [SourceLine]
        }
        var pending: [PendingSection] = [PendingSection(heading: nil, headingLine: lines.first?.number ?? 1, lines: [])]
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if let level = line.headingLevel, level > 0 {
                pending.append(PendingSection(heading: line.text, headingLine: line.number, lines: []))
                i += 1
                continue
            }
            if line.isContent { pending[pending.count - 1].lines.append(line) }
            i += 1
        }

        var out: [ResolvedSection] = []
        for ps in pending {
            guard let heading = ps.heading else {
                // Preamble. Only meaningful when there are headings (otherwise
                // the builder would not have been invoked). Treat as procedure
                // when the whole document is heading-less.
                if hasHeadings {
                    out.append(ResolvedSection(heading: "", headingLine: ps.headingLine,
                                               role: nil, executes: false, recordedRole: "inert",
                                               groups: [], rawLines: ps.lines, isPreamble: true))
                } else {
                    out.append(ResolvedSection(heading: "", headingLine: ps.headingLine,
                                               role: .procedure, executes: true, recordedRole: "procedure",
                                               groups: foldGroups(ps.lines, baseIndent: baseIndent),
                                               rawLines: ps.lines, isPreamble: false))
                }
                continue
            }
            let resolved = try resolve(heading: heading, headingLine: ps.headingLine, hasContent: !ps.lines.isEmpty)
            out.append(ResolvedSection(heading: resolved.clean, headingLine: ps.headingLine,
                                       role: resolved.role, executes: resolved.executes,
                                       recordedRole: resolved.recordedRole,
                                       groups: foldGroups(ps.lines, baseIndent: baseIndent),
                                       rawLines: ps.lines, isPreamble: false))
        }
        return out
    }

    /// Fold a section's content lines into top-level-statement groups (a new
    /// top-level line starts a group; deeper-indented lines join it).
    private func foldGroups(_ lines: [SourceLine], baseIndent: Int) -> [StatementGroup] {
        var groups: [StatementGroup] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            var groupLines: [SourceLine] = [line]
            var j = i + 1
            while j < lines.count {
                if lines[j].indent > baseIndent { groupLines.append(lines[j]); j += 1 } else { break }
            }
            groups.append(StatementGroup(lines: groupLines))
            i = j
        }
        return groups
    }

    /// Resolve a heading to `(clean, role, executes, recordedRole)`.
    /// Marker-first and authoritative; derivation is executable-only.
    private func resolve(heading: String, headingLine: Int, hasContent: Bool)
        throws -> (clean: String, role: SkillSectionRole?, executes: Bool, recordedRole: String) {
        let parsed = SkillSectionRole.parseMarker(from: heading)
        if let unknown = parsed.unknownRole {
            try raiseStructural(
                .sectionStructuralError,
                message: "unknown section marker term `\(unknown)` in heading \"\(heading)\". Use `(( inert ))`, `(( inert, role: <role> ))`, or `(( role: <role> ))` where <role> is one of: \(SkillSectionRole.allCases.map(\.rawValue).joined(separator: ", ")).",
                range: SourceRange(file: file, line: headingLine, column: 1),
                help: "Fix the marker syntax or choose a recognized role from the list in the message.")
        }
        // Marker-first decision is shared with `SkillMetrics` via
        // `SectionRoleResolver`; the role-retention and error policy below is
        // builder-specific. `.tools` is non-executable but metadata-extracting,
        // so a derived `.tools` role is preserved (build() mines its bullets).
        let clean = parsed.cleanHeading
        let derived = rulebook.role(forHeading: clean) ?? SkillSectionRole.builtinRole(forHeading: clean)
        let decision = SectionRoleResolver.decide(marker: parsed.marker, derivedRole: derived)
        trace.log(.skill, "resolve '\(clean)' -> \(decision.recordedRole) executes=\(decision.executes) marker=\(decision.fromMarker) @L\(headingLine)")
        if decision.resolved {
            let keptRole: SkillSectionRole?
            if decision.fromMarker {
                keptRole = decision.executes ? decision.role : nil
            } else {
                let keep = (decision.role?.isExecutable ?? false) || decision.role == SkillSectionRole.tools
                keptRole = keep ? decision.role : nil
            }
            return (clean, keptRole, decision.executes, decision.recordedRole)
        }
        // Unresolved. Empty sections are harmless (recorded as inert); a section
        // with content is a hard error — no silent drops.
        if hasContent {
            try raiseStructural(
                .sectionStructuralError,
                message: "unrecognized section heading \"\(clean)\" has content but no role. Rename it to a recognized role, add a `=== sections ===` rulebook alias, force a role with `(( role: <role> ))`, or mark it `(( inert ))`.",
                range: SourceRange(file: file, line: headingLine, column: 1),
                help: "Add a `=== sections ===` alias in the rulebook, rename to a recognized heading, add `(( role: … ))`, or mark `(( inert ))`.")
        }
        return (clean, nil, false, "inert")
    }

    /// True for a collapsed fenced block whose language tag is a shell dialect
    /// (`bash`/`sh`/`shell`/…). Such blocks lower to deterministic `shell.run`
    /// invokes and remain executable within an executable section.
    private func isShellCodeBlock(_ line: SourceLine) -> Bool {
        guard let (lang, _) = decodeCodeBlockSentinel(line.text) else { return false }
        return lexicon.isShellFence(lang)
    }

    // MARK: Role lowering

    private func assertLine(for group: StatementGroup, role: SkillSectionRole, negated: Bool) throws -> SourceLine {
        // Multi-line invariant/prohibition blocks aren't single conditions.
        guard !group.isMultiline else {
            try raiseStructural(
                .sectionStructuralError,
                message: "multi-line \(role.rawValue) item under a checkable section is not a single predicate. Make each item a one-line checkable comparison, or mark the section `(( inert, role: \(role.rawValue) ))`.",
                range: SourceRange(file: file, line: group.head.number, column: 1),
                help: "Split into one-line comparisons or mark the section `(( inert, role: \(role.rawValue) ))`.")
        }
        // 1D output invariant: `every emitted <noun> <predicate>` is sugar for an
        // assert on the bound result `<noun>` (shared normalization).
        let classifier = ConditionClassifier(symbols: symbols, lexicon: lexicon, trace: trace)
        let text = classifier.normalizeFormatInvariant(group.head.statement)
        switch classify(text) {
        case .checkable:
            let cond = negated
                ? "\(lexicon.grammar.negationWrapperPrefix)\(text)\(lexicon.grammar.negationWrapperSuffix)"
                : text
            // Synthesize with the lexicon's primary assertion marker (default
            // "make sure") so a domain that renames it stays self-consistent.
            let marker = lexicon.assertionMarkers.first ?? EnglishLexicon.default.assertionMarkers.first ?? ""
            return canonical("\(marker) \(cond)", from: group.head)
        case .dispatchPhrase, .fuzzy:
            // Contract/Anti-Patterns prose that isn't a checkable condition can
            // never become a deterministic assert — and we never silently drop
            // it or route it to an LLM. The author marks the section inert.
            try raiseStructural(
                .uncheckablePredicate,
                message: "\(role.rawValue) item \"\(text)\" is not a structurally checkable predicate. Rephrase it as a comparison (e.g. `the connection count is at least 20`), or mark the section `(( inert, role: \(role.rawValue) ))` to keep it as documentation.",
                range: SourceRange(file: file, line: group.head.number, column: 1),
                help: "Rephrase as a checkable comparison or mark the section `(( inert, role: \(role.rawValue) ))`.")
        }
    }

    private func applyApplicability(_ group: StatementGroup, negated: Bool,
                                    prelude: inout [SourceLine], dispatch: inout [String]) throws {
        guard !group.isMultiline else {
            // A multi-line applicability block is an authored procedure-like
            // construct; treat its lines as procedure to avoid silent drops.
            trace.log(.skill, "multi-line applicability block kept as procedure @L\(group.head.number)")
            prelude.append(contentsOf: group.lines)
            return
        }
        let text = group.head.statement
        switch classify(text) {
        case .checkable:
            // When-To-Use: skip (complete) unless the condition holds.
            // When-NOT-To-Use: skip (complete) when the condition holds.
            // `complete` is a fixed primitive; the suffix-conditional marker is
            // sourced from grammar so this stays in lockstep with the parser.
            let positiveMarker = lexicon.grammar.suffixConditionalMarkers
                .first { $0 != lexicon.grammar.suffixConditionalNegated }
                ?? EnglishLexicon.default.grammar.suffixConditionalMarkers.first { $0 != EnglishLexicon.default.grammar.suffixConditionalNegated }
                ?? ""
            let marker = negated ? positiveMarker : lexicon.grammar.suffixConditionalNegated
            let canonicalText = lexicon.grammar.statement.complete + marker + text
            prelude.append(canonical(canonicalText, from: group.head))
        case .dispatchPhrase(let phrase):
            dispatch.append(phrase)
            trace.log(.skill, "applicability dispatch phrase @L\(group.head.number): \(phrase)")
        case .fuzzy:
            try raiseStructural(
                .uncheckablePredicate,
                message: "fuzzy applicability condition \"\(text)\" is neither structurally checkable nor a literal dispatch phrase. Rephrase it as a checkable predicate (a comparison such as `the connection count is at least 20`), move it to a `triggers:` dispatch phrase, or wrap it in an explicit `use judgment to …:` marker.",
                range: SourceRange(file: file, line: group.head.number, column: 1),
                help: "Rephrase as a comparison, move to `triggers:`, or wrap in `use judgment to …:`.")
        }
    }

    private func canonical(_ text: String, from line: SourceLine) -> SourceLine {
        SourceLine(indent: 0, text: text + ".", raw: text, number: line.number)
    }

    // MARK: Applicability classification

    typealias Applicability = ConditionClassifier.Classification

    /// Classify a section line as a structurally-checkable predicate, a literal
    /// dispatch phrase (an intent), or a fuzzy condition. Delegates to the
    /// shared `ConditionClassifier` (single source of truth).
    func classify(_ text: String) -> Applicability {
        ConditionClassifier(symbols: symbols, lexicon: lexicon, trace: trace).classify(text)
    }

    private func raiseStructural(_ code: DiagnosticCode, message: String,
                                 range: SourceRange, help: String) throws -> Never {
        throw CompilerError.diagnostics([
            Diagnostic.structural(code, message: message, range: range, help: help)
        ])
    }
}
