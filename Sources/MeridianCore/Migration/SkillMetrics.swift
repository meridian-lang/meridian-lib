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
    public var totalSections: Int
    public var inertSections: Int
    public var judgmentBlocks: Int
    public var judgmentLines: Int

    public init(totalSections: Int = 0, inertSections: Int = 0,
                judgmentBlocks: Int = 0, judgmentLines: Int = 0) {
        self.totalSections = totalSections
        self.inertSections = inertSections
        self.judgmentBlocks = judgmentBlocks
        self.judgmentLines = judgmentLines
    }

    /// Non-executable sections as a fraction of all sections. `0` when a file
    /// has no headings (a flat-procedure skill).
    public var inertRatio: Double {
        totalSections == 0 ? 0 : Double(inertSections) / Double(totalSections)
    }

    public static func analyze(_ source: String) -> SkillMetrics {
        let lines = bodyLines(of: source)
        var total = 0
        var inert = 0
        var blocks = 0
        var jLines = 0
        var inFence = false

        for (idx, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }

            if let heading = headingText(trimmed) {
                total += 1
                if !sectionExecutes(heading) { inert += 1 }
            }
            if isJudgmentHeader(trimmed) {
                blocks += 1
                jLines += bodyLineCount(in: lines, headerIndex: idx)
            }
        }
        return SkillMetrics(totalSections: total, inertSections: inert,
                            judgmentBlocks: blocks, judgmentLines: jLines)
    }

    // MARK: - Section role

    /// The `##`/`###` heading text (marker included), or nil for non-heading
    /// lines. A level-1 `#` title is not a section.
    private static func headingText(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("##") else { return nil }
        return String(trimmed.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
    }

    /// Mirrors `SkillSectionBuilder.resolve`: a trailing `(( … ))` marker is
    /// authoritative; otherwise the built-in heading alias decides. An
    /// unresolved heading is treated as non-executable for metrics (it is a hard
    /// error only when it has content, which the real builder enforces).
    private static func sectionExecutes(_ heading: String) -> Bool {
        let parsed = SkillSectionRole.parseMarker(from: heading)
        // Shared marker-first decision (metrics has no rulebook, so derivation is
        // builtin-only); see `SectionRoleResolver`.
        let derived = SkillSectionRole.builtinRole(forHeading: parsed.cleanHeading)
        return SectionRoleResolver.decide(marker: parsed.marker, derivedRole: derived).executes
    }

    // MARK: - Judgment

    private static func isJudgmentHeader(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        return lower.contains("use judgment to")
            || lower.contains("with discretion")
            || lower.contains("with autonomy")
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
