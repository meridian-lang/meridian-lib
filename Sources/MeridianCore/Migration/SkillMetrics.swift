import Foundation

// MARK: - SkillMetrics
//
// Wave 0 measurement. Computes the corpus expressiveness counters a deviation
// report carries, directly from a ported `.meri` text:
//
//   • total / inert section counts and the inert ratio — how much of a skill is
//     non-executable documentation vs lowered procedure;
//   • judgment block / line counts — how much of a skill still routes through
//     the LLM (`use judgment to …:`, `with discretion`, `with autonomy`) rather
//     than deterministic IR.
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

        public init(heading: String, line: Int, role: String,
                    category: InertCategory, reason: String) {
            self.heading = heading
            self.line = line
            self.role = role
            self.category = category
            self.reason = reason
        }
    }

    public var totalSections: Int
    public var inertSections: Int
    public var judgmentBlocks: Int
    public var judgmentLines: Int
    public var inertDetails: [InertSection]

    public init(totalSections: Int = 0, inertSections: Int = 0,
                judgmentBlocks: Int = 0, judgmentLines: Int = 0,
                inertDetails: [InertSection] = []) {
        self.totalSections = totalSections
        self.inertSections = inertSections
        self.judgmentBlocks = judgmentBlocks
        self.judgmentLines = judgmentLines
        self.inertDetails = inertDetails
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

    public static func analyze(_ source: String, rulebook: Rulebook = .empty) -> SkillMetrics {
        let lines = bodyLines(of: source)
        var total = 0
        var inert = 0
        var blocks = 0
        var jLines = 0
        var inFence = false
        var sections: [(heading: String, line: Int, body: [String])] = []

        for (idx, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }

            if let heading = headingText(trimmed) {
                total += 1
                if !sectionExecutes(heading, rulebook: rulebook) { inert += 1 }
                let end = nextHeadingIndex(after: idx, in: lines)
                sections.append((heading, idx + 1, Array(lines[(idx + 1)..<end])))
            }
            if isJudgmentHeader(trimmed) {
                blocks += 1
                jLines += bodyLineCount(in: lines, headerIndex: idx)
            }
        }
        let details = sections.compactMap { section -> InertSection? in
            inertSectionDetail(heading: section.heading, line: section.line, body: section.body, rulebook: rulebook)
        }
        return SkillMetrics(totalSections: total, inertSections: inert,
                            judgmentBlocks: blocks, judgmentLines: jLines,
                            inertDetails: details)
    }

    // MARK: - Section role

    /// Valid section heading text, or nil for non-heading lines.
    private static func headingText(_ trimmed: String) -> String? {
        SkillMarkdownShape.headingText(trimmed)
    }

    /// Mirrors `SkillSectionBuilder.resolve`: a trailing `(( … ))` marker is
    /// authoritative; otherwise the built-in heading alias decides. An
    /// unresolved heading is treated as non-executable for metrics (it is a hard
    /// error only when it has content, which the real builder enforces).
    private static func sectionExecutes(_ heading: String, rulebook: Rulebook) -> Bool {
        let parsed = SkillSectionRole.parseMarker(from: heading)
        // Shared marker-first decision; author rulebook aliases take priority
        // over builtins, matching `SkillSectionBuilder`.
        let derived = rulebook.role(forHeading: parsed.cleanHeading)
            ?? SkillSectionRole.builtinRole(forHeading: parsed.cleanHeading)
        return SectionRoleResolver.decide(marker: parsed.marker, derivedRole: derived).executes
    }

    private static func inertSectionDetail(heading: String, line: Int, body: [String], rulebook: Rulebook) -> InertSection? {
        let parsed = SkillSectionRole.parseMarker(from: heading)
        let derived = rulebook.role(forHeading: parsed.cleanHeading)
            ?? SkillSectionRole.builtinRole(forHeading: parsed.cleanHeading)
        let decision = SectionRoleResolver.decide(marker: parsed.marker, derivedRole: derived)
        guard !decision.executes else { return nil }

        let clean = parsed.cleanHeading
        let category: InertCategory
        let reason: String
        if decision.recordedRole == SkillSectionRole.template.rawValue
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
        } else if looksReferenceLike(clean, body: body) {
            category = .referenceDocumentation
            reason = "Reference documentation, rationale, examples, or changelog."
        } else if decision.recordedRole == SkillSectionRole.procedure.rawValue
                    || decision.recordedRole == SkillSectionRole.applicability.rawValue
                    || decision.recordedRole == SkillSectionRole.negativeApplicability.rawValue {
            category = .operationalProcedure
            reason = "Marked or derived as \(decision.recordedRole), but inert suppresses execution."
        } else if bodyHasExecutableShape(body) {
            category = .operationalContent
            reason = "Body contains command, table, checklist, or explicit AI-routing surface."
        } else if decision.recordedRole == SkillSectionRole.invariants.rawValue
                    || decision.recordedRole == SkillSectionRole.prohibitions.rawValue {
            category = .normativeContract
            reason = "Normative \(decision.recordedRole) prose needs mining into assertions or explicit AI routing."
        } else if decision.resolved || looksReferenceLike(clean, body: body) {
            category = .referenceDocumentation
            reason = "Reference documentation, rationale, examples, or changelog."
        } else {
            category = .unclassified
            reason = "No executable role or known documentation category was recognized."
        }

        return InertSection(heading: clean, line: line, role: decision.recordedRole,
                            category: category, reason: reason)
    }

    private static func nextHeadingIndex(after idx: Int, in lines: [String]) -> Int {
        var j = idx + 1
        var inFence = false
        while j < lines.count {
            let trimmed = lines[j].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                j += 1
                continue
            }
            if !inFence, headingText(trimmed) != nil { return j }
            j += 1
        }
        return lines.count
    }

    private static func bodyHasExecutableShape(_ body: [String]) -> Bool {
        var inFence = false
        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if !inFence {
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if isShellFence(lang) { return true }
                }
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if trimmed.hasPrefix("!!! table") || trimmed.hasPrefix("!!! checklist") { return true }
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("* [x]") { return true }
            if wholeLineBacktickedCommand(trimmed) { return true }
            if trimmed.hasPrefix("|") && trimmed.contains("|") { return true }
            let lower = trimmed.lowercased()
            if lower.contains(TableMode.aiAutonomy.sentinelToken)
                || lower.contains(TableMode.aiDiscretion.sentinelToken)
                || EnglishLexicon.default.grammar.judgmentIntroducers.contains(where: { lower.contains($0) }) {
                return true
            }
        }
        return false
    }

    private static func wholeLineBacktickedCommand(_ trimmed: String) -> Bool {
        SkillMarkdownShape.wholeLineBacktickedCommand(trimmed)
    }

    private static func looksReferenceLike(_ heading: String, body: [String]) -> Bool {
        let lower = heading.lowercased()
        let referenceWords = [
            "what", "why", "philosophy", "example", "examples", "format",
            "changelog", "related", "reference", "background", "overview",
            "notes", "caveats", "prior work", "methodology", "template",
            "guide", "guidance", "tutorial", "vision", "options", "available",
            "semantics", "invocation patterns", "tracking", "state", "vs",
            "cycle", "patterns", "quality bar", "trust boundary", "idempotency",
            "privacy", "cooldown"
        ]
        if referenceWords.contains(where: { lower.contains($0) }) { return true }
        return body.contains { line in
            let t = line.trimmingCharacters(in: .whitespaces).lowercased()
            return t.hasPrefix(">") || t.contains("example:") || t.contains("for reference")
        }
    }

    // MARK: - Judgment

    private static func isJudgmentHeader(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        let grammar = EnglishLexicon.default.grammar
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
        guard let fm = FrontmatterScanner.locate(lines, skipLeadingBlanks: true) else { return lines }
        return Array(lines[(fm.close + 1)...])
    }
}
