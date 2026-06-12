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

        for sec in sections {
            // Content before the first heading is never executable and must not
            // be silently dropped. (When the document has no headings at all the
            // builder is not invoked; the body is parsed verbatim instead.)
            if sec.isPreamble {
                if !sec.rawLines.isEmpty {
                    throw CompilerError.semanticError(
                        message: "content before the first heading: \"\(sec.rawLines[0].statement)\". Every line in a sectioned document must live under a heading — move it under a heading, or make it a comment (`#`/`>`).",
                        range: SourceRange(file: file, line: sec.rawLines[0].number, column: 1)
                    )
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
                case .invariants:
                    prelude.append(try assertLine(for: group, role: role, negated: false))
                case .prohibitions:
                    prelude.append(try assertLine(for: group, role: role, negated: true))
                case .applicability:
                    try applyApplicability(group, negated: false, prelude: &prelude, dispatch: &dispatch)
                case .negativeApplicability:
                    try applyApplicability(group, negated: true, prelude: &prelude, dispatch: &negativeDispatch)
                case .template, .inert:
                    // Non-executable roles never have executes == true.
                    break
                }
            }
        }
        return Result(bodyLines: prelude + procedure,
                      dispatchPhrases: dispatch,
                      negativeDispatchPhrases: negativeDispatch,
                      sections: records)
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
            throw CompilerError.semanticError(
                message: "unknown section marker term `\(unknown)` in heading \"\(heading)\". Use `(( inert ))`, `(( inert, role: <role> ))`, or `(( role: <role> ))` where <role> is one of: \(SkillSectionRole.allCases.map(\.rawValue).joined(separator: ", ")).",
                range: SourceRange(file: file, line: headingLine, column: 1)
            )
        }
        if let marker = parsed.marker, marker.inert || marker.role != nil {
            // Authoritative marker — no heading derivation.
            let role = marker.role
            let executes = !marker.inert && (role?.isExecutable ?? false)
            let recorded = role?.rawValue ?? "inert"
            return (parsed.cleanHeading, executes ? role : nil, executes, recorded)
        }
        // No marker: derive an executable role from the clean heading text.
        let clean = parsed.cleanHeading
        if let role = rulebook.role(forHeading: clean) ?? SkillSectionRole.builtinRole(forHeading: clean) {
            return (clean, role.isExecutable ? role : nil, role.isExecutable, role.rawValue)
        }
        // Unresolved. Empty sections are harmless (recorded as inert); a section
        // with content is a hard error — no silent drops.
        if hasContent {
            throw CompilerError.semanticError(
                message: "unrecognized section heading \"\(clean)\" has content but no role. Rename it to a recognized role, add a `=== sections ===` rulebook alias, force a role with `(( role: <role> ))`, or mark it `(( inert ))`.",
                range: SourceRange(file: file, line: headingLine, column: 1)
            )
        }
        return (clean, nil, false, "inert")
    }

    /// True for a collapsed fenced block whose language tag is a shell dialect
    /// (`bash`/`sh`/`shell`/…). Such blocks lower to deterministic `shell.run`
    /// invokes and remain executable within an executable section.
    private func isShellCodeBlock(_ line: SourceLine) -> Bool {
        guard line.text.hasPrefix(codeBlockSentinelPrefix) else { return false }
        let rest = line.text.dropFirst(codeBlockSentinelPrefix.count)
        guard let colon = rest.firstIndex(of: ":") else { return false }
        let lang = String(rest[rest.startIndex..<colon]).lowercased()
        return shellFenceLanguages.contains(lang)
    }

    // MARK: Role lowering

    private func assertLine(for group: StatementGroup, role: SkillSectionRole, negated: Bool) throws -> SourceLine {
        // Multi-line invariant/prohibition blocks aren't single conditions.
        guard !group.isMultiline else {
            throw CompilerError.semanticError(
                message: "multi-line \(role.rawValue) item under a checkable section is not a single predicate. Make each item a one-line checkable comparison, or mark the section `(( inert, role: \(role.rawValue) ))`.",
                range: SourceRange(file: file, line: group.head.number, column: 1)
            )
        }
        let text = group.head.statement
        switch classify(text) {
        case .checkable:
            let cond = negated ? "not (\(text))" : text
            return canonical("make sure \(cond)", from: group.head)
        case .dispatchPhrase, .fuzzy:
            // Contract/Anti-Patterns prose that isn't a checkable condition can
            // never become a deterministic assert — and we never silently drop
            // it or route it to an LLM. The author marks the section inert.
            throw CompilerError.semanticError(
                message: "\(role.rawValue) item \"\(text)\" is not a structurally checkable predicate. Rephrase it as a comparison (e.g. `the connection count is at least 20`), or mark the section `(( inert, role: \(role.rawValue) ))` to keep it as documentation.",
                range: SourceRange(file: file, line: group.head.number, column: 1)
            )
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
            let canonicalText = negated ? "complete only when \(text)" : "complete unless \(text)"
            prelude.append(canonical(canonicalText, from: group.head))
        case .dispatchPhrase(let phrase):
            dispatch.append(phrase)
            trace.log(.skill, "applicability dispatch phrase @L\(group.head.number): \(phrase)")
        case .fuzzy:
            throw CompilerError.semanticError(
                message: "fuzzy applicability condition \"\(text)\" is neither structurally checkable nor a literal dispatch phrase. Rephrase it as a checkable predicate (a comparison such as `the connection count is at least 20`), move it to a `triggers:` dispatch phrase, or wrap it in an explicit `use judgment to …:` marker.",
                range: SourceRange(file: file, line: group.head.number, column: 1)
            )
        }
    }

    private func canonical(_ text: String, from line: SourceLine) -> SourceLine {
        SourceLine(indent: 0, text: text + ".", raw: text, number: line.number)
    }

    // MARK: Applicability classification

    enum Applicability {
        case checkable
        case dispatchPhrase(String)
        case fuzzy
    }

    /// Classify a section line as a structurally-checkable predicate, a literal
    /// dispatch phrase (an intent), or a fuzzy condition. The distinction is
    /// deterministic: a line that parses to a comparison/logical over concrete
    /// operands is checkable; a line that *reads as a condition* (contains a
    /// copula/comparison marker) but isn't checkable is fuzzy; a line with no
    /// copula/comparison is a descriptive dispatch phrase.
    func classify(_ text: String) -> Applicability {
        let parser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
        let expr = parser.parse(text)
        if isCheckable(expr) { return .checkable }
        if readsAsCondition(text) { return .fuzzy }
        return .dispatchPhrase(text)
    }

    private func isCheckable(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual, .within:
                return true
            case .equal, .notEqual:
                return isConcrete(rhs) || isConcrete(lhs)
            }
        case .logical(let logOp, let parts):
            switch logOp {
            case .and, .or: return !parts.isEmpty && parts.allSatisfy(isCheckable)
            case .not:      return parts.first.map(isCheckable) ?? false
            }
        default:
            return false
        }
    }

    /// A "concrete" operand is one whose value is structurally determinate at
    /// runtime: a literal, a named constant/instance, `now`, or a property
    /// access (`order.total`). A bare identifier (an adjective like `notable`)
    /// is NOT concrete.
    private func isConcrete(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .literal, .constantRef, .instanceRef, .envVar, .now, .propertyAccess:
            return true
        default:
            return false
        }
    }

    /// True when the text grammatically reads as a *condition* (contains a
    /// copula or comparison marker) — used to separate fuzzy conditions from
    /// descriptive dispatch phrases.
    private func readsAsCondition(_ text: String) -> Bool {
        let lower = " \(text.lowercased()) "
        // Copulas come from the lexicon (house convention: no hardcoded word
        // lists). `equals`/`not` are extra condition cues the lexicon's copula
        // set doesn't carry (equality is spelled `is` there).
        let conditionCues = lexicon.copulas.union(["equals", "not"])
        if conditionCues.contains(where: { lower.contains(" \($0) ") }) { return true }
        for marker in lexicon.comparisonMarkers.map(\.0) {
            if lower.contains(" \(marker.lowercased()) ") { return true }
        }
        return false
    }
}
