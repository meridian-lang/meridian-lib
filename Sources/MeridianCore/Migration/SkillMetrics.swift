import Foundation

// MARK: - SkillMetrics
//
// measurement. Computes the corpus expressiveness counters a deviation
// report carries, directly from a ported `.meri` text:
//
//   • total / inert section counts and the inert ratio — how much of a skill is
//     non-executable documentation vs lowered procedure;
//   • judgment block / line counts — how much of a skill still routes through
//     the LLM (`use judgment to …:`, `with discretion`, `with autonomy`) rather
//     than deterministic IR;
//   • generated LOC — a simple per-skill size signal for the ported `.meri`,
//     counted as non-blank body lines after frontmatter and before any
//     downstream compile-output expansion.
//
// The scan is dependency-free and deterministic (no parser, no IR): section
// executability reuses the same pure role functions as `SkillSectionBuilder`
// (`SkillSectionRole.parseMarker` / `.builtinRole` / `.isExecutable`), so the
// numbers track the real lowering. Fenced code blocks are skipped so a `##`
// inside an Output Format sample is not miscounted as a section.

public struct SkillMetrics: Sendable, Equatable {
    public enum InertCategory: String, Sendable, Equatable, Comparable, CaseIterable {
        case operationalProcedure = "operational-procedure"
        case operationalContent = "operational-content"
        case normativeContract = "normative-contract"
        case template
        case toolsMetadata = "tools-metadata"
        case conventionReference = "convention-reference"
        case referenceDocumentation = "reference-documentation"
        case unclassified

        public static func < (lhs: InertCategory, rhs: InertCategory) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var isOperational: Bool {
            switch self {
            case .operationalProcedure, .operationalContent, .normativeContract, .unclassified:
                return true
            case .template, .toolsMetadata, .conventionReference, .referenceDocumentation:
                return false
            }
        }
    }

    public struct InertSection: Sendable, Equatable {
        public var heading: String
        public var line: Int
        public var role: String
        public var category: InertCategory
        public var reason: String
        /// Raw body lines of the section (between this heading and the next),
        /// fences included verbatim. Empty by default for source compatibility;
        /// populated by `analyze(_:rulebook:)` so tooling (the inert-yield
        /// analyzer) can re-probe the section's actual content without
        /// re-walking headings itself.
        public var body: [String]

        public init(heading: String, line: Int, role: String,
                    category: InertCategory, reason: String, body: [String] = []) {
            self.heading = heading
            self.line = line
            self.role = role
            self.category = category
            self.reason = reason
            self.body = body
        }
    }

    public var totalSections: Int
    public var inertSections: Int
    public var judgmentBlocks: Int
    public var judgmentLines: Int
    public var generatedLOC: Int
    public var inertDetails: [InertSection]
    public var canonicalDriftSynonym: Int
    public var canonicalDriftStructure: Int
    public var canonicalDriftDesugar: Int
    public var canonicalDriftMeaning: Int

    public init(totalSections: Int = 0, inertSections: Int = 0,
                judgmentBlocks: Int = 0, judgmentLines: Int = 0,
                generatedLOC: Int = 0,
                inertDetails: [InertSection] = [],
                canonicalDriftSynonym: Int = 0,
                canonicalDriftStructure: Int = 0,
                canonicalDriftDesugar: Int = 0,
                canonicalDriftMeaning: Int = 0) {
        self.totalSections = totalSections
        self.inertSections = inertSections
        self.judgmentBlocks = judgmentBlocks
        self.judgmentLines = judgmentLines
        self.generatedLOC = generatedLOC
        self.inertDetails = inertDetails
        self.canonicalDriftSynonym = canonicalDriftSynonym
        self.canonicalDriftStructure = canonicalDriftStructure
        self.canonicalDriftDesugar = canonicalDriftDesugar
        self.canonicalDriftMeaning = canonicalDriftMeaning
    }

    /// Non-executable sections as a fraction of all sections. `0` when a file
    /// has no headings (a flat-procedure skill).
    public var inertRatio: Double {
        totalSections == 0 ? 0 : Double(inertSections) / Double(totalSections)
    }

    public var operationalInertSections: Int {
        inertDetails.filter { $0.category.isOperational }.count
    }

    public var unclassifiedInertSections: Int {
        inertDetails.filter { $0.category == .unclassified }.count
    }

    public var inertCategoryCounts: [(category: InertCategory, count: Int)] {
        Dictionary(grouping: inertDetails, by: \.category)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.category < $1.category }
    }

    /// Sections whose recorded role is the literal `inert` keyword — the
    /// "Eliminate `(( inert ))`" plan's dedicated violation signal (§5),
    /// independent of `InertCategory`. The migrator never emits `inert`
    /// (it emits `reference`/`template`/`tools`/`convention-ref` or lowers/
    /// errors instead), so any nonzero count here is a hand-authored or
    /// stale marker a corpus should not carry.
    public var inertMarkerCount: Int {
        inertDetails.filter { $0.role == SkillSectionRole.inert.rawValue }.count
    }

    public var canonicalDriftTotal: Int {
        canonicalDriftSynonym + canonicalDriftStructure + canonicalDriftDesugar + canonicalDriftMeaning
    }

    public mutating func recordCanonicalDrift(_ report: DriftReport) {
        canonicalDriftSynonym = report.counts[.synonymCanonicalized] ?? 0
        canonicalDriftStructure = report.counts[.structureNormalized] ?? 0
        canonicalDriftDesugar = report.counts[.desugarExpanded] ?? 0
        canonicalDriftMeaning = report.counts[.meaningBearing] ?? 0
    }

    public static func analyze(_ source: String, rulebook: Rulebook = .empty,
                               lexicon: EnglishLexicon = .default) -> SkillMetrics {
        let lines = bodyLines(of: source)
        var total = 0
        var inert = 0
        var blocks = 0
        var jLines = 0
        let generatedLOC = lines.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        var sections: [(heading: String, line: Int, body: [String])] = []

        for section in MarkdownOutline.build(rawLines: lines) {
            let body = section.bodyLines.map(\.raw)
            // A heading whose own body (before the next heading, at any depth)
            // is blank is a pure structural container for nested child headings
            // — e.g. `## Phases` immediately followed by `### Phase 1: ...`.
            // It owns no content of its own, so nothing is suppressed by
            // marking it inert; tallying it (or worse, a spurious
            // `operationalProcedure` `inertDetails` entry, since a
            // `role: procedure` marker with an empty body still resolves to
            // that category) would inflate both the inert ratio and
            // `operationalInertSections` for content that was never dropped —
            // the real content lives in, and is already tallied via, its child
            // headings.
            let ownsContent = body.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // A migrator-generated split-sibling heading (AGENTS.md Phase 1
            // item 3, `SkillMigrator.splitHeadingSeparator`) is a rendering
            // detail of its parent section, not an independent section the
            // original ever had — counting it would spuriously inflate
            // `totalSections` relative to the original and dilute the inert
            // ratio. Only a non-generated heading gets an `inertDetails` entry
            // either (see the same exclusion one branch up); without that, a
            // sibling with a synthetic heading text no rulebook/builtin role
            // recognizes would leak into `inertDetails` as a spurious
            // `unclassified` entry — inflating `operationalInertSections` /
            // `unclassifiedInertSections` even though it was already excluded
            // from `inertSections`.
            if !section.heading.contains(SkillMigrator.splitHeadingSeparator), ownsContent {
                total += 1
                let clean = SkillSectionRole.parseMarker(from: section.heading).cleanHeading
                if !sectionExecutes(section.heading, rulebook: rulebook),
                   !bodyIsJudgmentWrapped(body, heading: clean, lexicon: lexicon) {
                    inert += 1
                }
                sections.append((section.heading, section.headingLine, body))
            }
        }

        // Judgment blocks are counted independently of section structure: any
        // non-fence line carrying a judgment introducer/discretion/autonomy
        // marker (heading lines included).
        var inFence = false
        for (idx, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if isJudgmentHeader(trimmed, lexicon: lexicon) {
                blocks += 1
                jLines += bodyLineCount(in: lines, headerIndex: idx)
            }
        }
        let details = sections.compactMap { section -> InertSection? in
            inertSectionDetail(heading: section.heading, line: section.line, body: section.body,
                              rulebook: rulebook, lexicon: lexicon)
        }
        return SkillMetrics(totalSections: total, inertSections: inert,
                            judgmentBlocks: blocks, judgmentLines: jLines,
                            generatedLOC: generatedLOC,
                            inertDetails: details)
    }

    // MARK: - Section role

    /// Mirrors `SkillSectionBuilder.resolve`: a trailing `(( … ))` marker is
    /// authoritative; otherwise the rulebook/built-in heading alias decides.
    /// An unresolved heading is treated as non-executable for metrics (it is a
    /// hard error only when it has content, which the real builder enforces).
    private static func sectionExecutes(_ heading: String, rulebook: Rulebook) -> Bool {
        SectionRoleResolver.decision(for: heading, rulebook: rulebook).executes
    }

    private static func inertSectionDetail(heading: String, line: Int, body: [String],
                                           rulebook: Rulebook, lexicon: EnglishLexicon) -> InertSection? {
        let parsed = SkillSectionRole.parseMarker(from: heading)
        let decision = SectionRoleResolver.decision(for: heading, rulebook: rulebook)
        guard !decision.executes else { return nil }

        let clean = parsed.cleanHeading
        // A `use judgment to follow the <heading> guidance:` opener means the
        // migrator already routed this section to the planner — not silent
        // inert residue. Count it under `judgmentBlocks`, not operational inert.
        guard !bodyIsJudgmentWrapped(body, heading: clean, lexicon: lexicon) else { return nil }

        let category: InertCategory
        let reason: String
        if decision.recordedRole == SkillSectionRole.reference.rawValue {
            category = .referenceDocumentation
            reason = "Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal."
        } else if decision.recordedRole == SkillSectionRole.template.rawValue
                    || SkillSectionRole.builtinRole(forHeading: clean) == .template {
            category = .template
            reason = "Template/output shape is metadata unless explicit output assertions are authored."
        } else if decision.recordedRole == SkillSectionRole.tools.rawValue
                    || SkillSectionRole.builtinRole(forHeading: clean) == .tools {
            category = .toolsMetadata
            reason = "Tools sections are metadata-mining, not workflow execution."
        } else if decision.recordedRole == SkillSectionRole.conventionRef.rawValue {
            category = .conventionReference
            reason = "External convention is recorded here; executable behavior belongs in the rulebook."
        } else if looksReferenceLike(clean, body: body, lexicon: lexicon) {
            category = .referenceDocumentation
            reason = "Reference documentation, rationale, examples, or changelog."
        } else if inertContractDocumentsExistingGuard(body, lexicon: lexicon) {
            category = .referenceDocumentation
            reason = "Documentary contract note: the executable workflow already carries the referenced guard."
        } else if decision.recordedRole == SkillSectionRole.procedure.rawValue
                    || decision.recordedRole == SkillSectionRole.applicability.rawValue
                    || decision.recordedRole == SkillSectionRole.negativeApplicability.rawValue {
            category = .operationalProcedure
            reason = "Marked or derived as \(decision.recordedRole), but inert suppresses execution."
        } else if bodyHasExecutableShape(body, lexicon: lexicon) {
            category = .operationalContent
            reason = "Body contains command, table, checklist, or explicit AI-routing surface."
        } else if decision.recordedRole == SkillSectionRole.invariants.rawValue
                    || decision.recordedRole == SkillSectionRole.prohibitions.rawValue {
            category = .normativeContract
            reason = "Normative \(decision.recordedRole) prose needs mining into assertions or explicit AI routing."
        } else {
            // No `decision.resolved` fallback to reference here (§5): a bare
            // `(( inert ))` (or an unresolved heading) that matched none of
            // the categories above is genuinely uncategorized, not laundered
            // into reference-documentation. It surfaces as `unclassified`
            // (operational) so it registers in the residual-error tail
            // instead of silently passing as legitimate documentation.
            category = .unclassified
            reason = "No executable role or known documentation category was recognized."
        }

        return InertSection(heading: clean, line: line, role: decision.recordedRole,
                            category: category, reason: reason, body: body)
    }

    private static func inertContractDocumentsExistingGuard(_ body: [String], lexicon: EnglishLexicon) -> Bool {
        let joined = body
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !joined.isEmpty else { return false }
        return lexicon.contractReferencePhrases.contains { joined.contains($0) }
    }

    private static func bodyHasExecutableShape(_ body: [String], lexicon: EnglishLexicon) -> Bool {
        var inFence = false
        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if !inFence {
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if lexicon.isShellFence(lang) { return true }
                }
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if trimmed.hasPrefix("!!! table") || trimmed.hasPrefix("!!! checklist") { return true }
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("* [x]") { return true }
            if MarkdownOutline.wholeLineBacktickedCommand(trimmed) { return true }
            if trimmed.hasPrefix("|") && trimmed.contains("|") { return true }
            let lower = trimmed.lowercased()
            if lower.contains(TableMode.aiAutonomy.sentinelToken)
                || lower.contains(TableMode.aiDiscretion.sentinelToken)
                || lexicon.grammar.judgmentIntroducers.contains(where: { lower.contains($0) }) {
                return true
            }
        }
        return false
    }

    /// Word list de-hardcoded to `EnglishLexicon.referenceHeadingWords` (§5 /
    /// P2): the documentary-heading discriminator is corpus-tunable via
    /// `=== language ===` `Reference-heading synonym:` rather than a fixed
    /// literal list in this file.
    private static func looksReferenceLike(_ heading: String, body: [String], lexicon: EnglishLexicon) -> Bool {
        let lower = heading.lowercased()
        if lexicon.referenceHeadingWords.contains(where: { lower.contains($0) }) { return true }
        if bodyIsOnlyNonShellFence(body, lexicon: lexicon) { return true }
        if bodyIsOnlyNonCommandBacktickSpans(body) { return true }
        return body.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces).lowercased()
            if t.hasPrefix(">") { return true }
            return lexicon.referenceHeadingWords.contains { t.contains($0) }
        }
    }

    /// True when a body's only non-blank content is inline backtick-quoted
    /// spans that are not real commands (`wholeLineBacktickedCommand` is
    /// false — a bare single word/token, or an unterminated span, not a
    /// runnable command with arguments) — e.g. a body listing `` `Page` ``,
    /// `` `unfinished` `` as terminology, not commands to execute.
    private static func bodyIsOnlyNonCommandBacktickSpans(_ body: [String]) -> Bool {
        var sawContent = false
        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            guard trimmed.hasPrefix("`"), !MarkdownOutline.wholeLineBacktickedCommand(trimmed) else { return false }
            sawContent = true
        }
        return sawContent
    }

    /// True when a body's only real content is one or more fenced code blocks
    /// that are not shell-executable (a JSON/markdown data-shape sample,
    /// etc.) — such a body can never lower or execute regardless of what the
    /// heading is called, so it is reference-like independent of
    /// `referenceHeadingWords`. Mirrors the migrator's own `SplitBlock`
    /// classification, where a non-shell/non-tool fence is `.documentation`.
    private static func bodyIsOnlyNonShellFence(_ body: [String], lexicon: EnglishLexicon) -> Bool {
        var inFence = false
        var sawFence = false
        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if !inFence {
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if lexicon.isShellFence(lang) { return false }
                    sawFence = true
                }
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if trimmed.isEmpty { continue }
            return false
        }
        return sawFence
    }

    /// True when the section body's first content line is the exact judgment
    /// wrap the migrator emits for `heading` (mirrors `SkillMigrator.bodyIsJudgmentWrapped`).
    private static func bodyIsJudgmentWrapped(_ body: [String], heading: String, lexicon: EnglishLexicon) -> Bool {
        guard let first = body.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return false
        }
        return first.trimmingCharacters(in: .whitespaces)
            == lexicon.grammar.judgmentFollowCollectLine(heading: heading)
    }

    // MARK: - Judgment

    private static func isJudgmentHeader(_ trimmed: String, lexicon: EnglishLexicon) -> Bool {
        let lower = trimmed.lowercased()
        let grammar = lexicon.grammar
        return grammar.judgmentIntroducers.contains { lower.contains($0) }
            || lower.contains(grammar.discretionMarker)
            || lower.contains(grammar.autonomyMarker)
    }

    /// Count of non-blank lines indented deeper than the judgment header,
    /// stopping at the first non-blank line at or below the header's indent.
    /// Blank lines neither count nor terminate the block.
    private static func bodyLineCount(in lines: [String], headerIndex: Int) -> Int {
        let headerIndent = indent(lines[headerIndex])
        var count = 0
        var j = headerIndex + 1
        while j < lines.count {
            let line = lines[j]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { j += 1; continue }
            if indent(line) <= headerIndent { break }
            count += 1
            j += 1
        }
        return count
    }

    private static func indent(_ s: String) -> Int {
        s.prefix(while: { $0 == " " || $0 == "\t" }).count
    }

    // MARK: - Frontmatter strip

    /// Body lines after a leading `---`/`---` frontmatter block (so a
    /// `description:` mentioning "use judgment" is not miscounted). Files
    /// without frontmatter are returned verbatim.
    private static func bodyLines(of source: String) -> [String] {
        let lines = source.components(separatedBy: "\n")
        guard let fm = Frontmatter.locate(lines, skipLeadingBlanks: true) else { return lines }
        return Array(lines[(fm.close + 1)...])
    }
}
