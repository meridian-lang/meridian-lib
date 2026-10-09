import Foundation

// MARK: - SkillDeviation
//
// Authoring/audit-time tool that explains how a ported `.meri` deviates from
// the original `SKILL.md` it was derived from. It is the read-only companion to
// `SkillMigrator`: where the migrator *produces* a strict-compiling `.meri`,
// `SkillDeviation` *reports* what changed between the source SKILL.md and the
// checked-in port, so a corpus migration stays auditable over time.
//
// The analysis is deterministic and dependency-free:
//   1. Frontmatter delta — key-level Added/Removed (authoritative) plus a
//      best-effort Changed set (value-normalized so YAML-vs-inline list
//      reformatting is not flagged).
//   2. Body diff — an LCS-based unified diff over the two line arrays, plus
//      added/removed/unchanged counts and a similarity ratio.
//   3. Tier — a coarse migration-effort bucket derived from similarity.
//   4. Categories — notable structural transforms (frontmatter injected, shell
//      blocks introduced, explicit judgment markers introduced, sections
//      restructured) detected by scanning both sides.

public struct SkillDeviation {

    public struct DeviationReport: Sendable {
        public var originalName: String
        public var portedName: String
        /// Path shown in the diff's `--- ` header (defaults to `originalName`).
        public var originalDiffPath: String
        /// Path shown in the diff's `+++ ` header (defaults to `portedName`).
        public var portedDiffPath: String
        /// 1 = near-verbatim, 2 = light edits, 3 = structural rewrite.
        /// Derived from `similarity`.
        public var tier: Int
        /// Frontmatter keys present in the port but not the original.
        public var frontmatterAdded: [String]
        /// Frontmatter keys present in the original but not the port.
        public var frontmatterRemoved: [String]
        /// Keys on both sides whose values differ after normalization.
        public var frontmatterChanged: [String]
        public var originalLineCount: Int
        public var portedLineCount: Int
        public var added: Int
        public var removed: Int
        public var unchanged: Int
        /// `unchanged / max(1, originalLineCount, portedLineCount)`.
        public var similarity: Double
        public var categories: [String]
        public var unifiedDiff: String
        /// expressiveness counters over the ported `.meri` (see
        /// `SkillMetrics`): section inert ratio and judgment block/line counts.
        public var metrics: SkillMetrics
        /// Ported sections that became inert even though the corresponding
        /// original heading was not already marked inert.
        public var inertSectionDeviations: [SkillMetrics.InertSection]
    }

    // MARK: - Analysis

    public static func analyze(
        originalMarkdown: String,
        portedMeri: String,
        originalName: String,
        portedName: String,
        originalDiffPath: String? = nil,
        portedDiffPath: String? = nil,
        rulebook: Rulebook = .empty,
        lexicon: EnglishLexicon = .default
    ) -> DeviationReport {
        let originalLines = originalMarkdown.components(separatedBy: "\n")
        let portedLines = portedMeri.components(separatedBy: "\n")

        // Faithful difflib: matching-block count M drives the ratio and counts.
        let matcher = DiffMatcher(originalLines, portedLines)
        let m = matcher.matchCount()
        let unchanged = m
        let removed = originalLines.count - m
        let added = portedLines.count - m
        let diff = matcher.unifiedDiffBody(context: 3)
        let length = originalLines.count + portedLines.count
        let similarity = length == 0 ? 1.0 : 2.0 * Double(m) / Double(length)

        let origFM = frontmatter(originalMarkdown)
        let portFM = frontmatter(portedMeri)
        let origKeys = Set(origFM.keys)
        let portKeys = Set(portFM.keys)
        let fmAdded = portKeys.subtracting(origKeys).sorted()
        let fmRemoved = origKeys.subtracting(portKeys).sorted()
        let fmChanged = origKeys.intersection(portKeys)
            .filter { normalizeValue(origFM[$0] ?? "") != normalizeValue(portFM[$0] ?? "") }
            .sorted()

        let metrics = SkillMetrics.analyze(portedMeri, rulebook: rulebook, lexicon: lexicon)
        let inertDeviations = inertSectionDeviations(
            originalMarkdown: originalMarkdown,
            metrics: metrics,
            portedMeri: portedMeri
        )

        var categories = detectCategories(
            originalMarkdown: originalMarkdown, portedMeri: portedMeri,
            frontmatterAdded: fmAdded
        )
        if !inertDeviations.isEmpty {
            categories.append("doc-section-marked")
        }

        return DeviationReport(
            originalName: originalName,
            portedName: portedName,
            originalDiffPath: originalDiffPath ?? originalName,
            portedDiffPath: portedDiffPath ?? portedName,
            tier: tier(for: similarity),
            frontmatterAdded: fmAdded,
            frontmatterRemoved: fmRemoved,
            frontmatterChanged: fmChanged,
            originalLineCount: originalLines.count,
            portedLineCount: portedLines.count,
            added: added,
            removed: removed,
            unchanged: unchanged,
            similarity: similarity,
            categories: categories,
            unifiedDiff: diff,
            metrics: metrics,
            inertSectionDeviations: inertDeviations
        )
    }

    static func tier(for similarity: Double) -> Int {
        if similarity >= 0.85 { return 1 }
        if similarity >= 0.5 { return 2 }
        return 3
    }

    // MARK: - Rendering

    public func renderMarkdown() -> String { Self.renderMarkdown(report, includeDiff: true) }

    let report: DeviationReport
    public init(report: DeviationReport) { self.report = report }

    public static func renderMarkdown(_ r: DeviationReport, includeDiff: Bool) -> String {
        var out: [String] = []
        out.append("# Deviation: \(r.portedName)")
        out.append("")
        out.append("- Original: `\(r.originalName)`")
        out.append("- Ported: `\(r.portedName)`")
        out.append("- Tier: \(r.tier) (\(tierLabel(r.tier)))")
        out.append("- Similarity: \(percent(r.similarity))")
        out.append("- Lines: \(r.originalLineCount) -> \(r.portedLineCount) (+\(r.added) / -\(r.removed))")
        out.append("")
        out.append("## Frontmatter")
        out.append("- Added: \(listOrNone(r.frontmatterAdded))")
        out.append("- Removed: \(listOrNone(r.frontmatterRemoved))")
        out.append("")
        out.append("## Categories")
        if r.categories.isEmpty {
            out.append("- (none)")
        } else {
            for c in r.categories { out.append("- \(c)") }
        }
        if !r.inertSectionDeviations.isEmpty {
            out.append("")
            out.append("## Inert deviations")
            out.append("")
            out.append("These sections were made non-executable in the port and should be reviewed as migration deviations:")
            for detail in r.inertSectionDeviations {
                out.append("- L\(detail.line) `\(detail.heading)`: \(detail.category.rawValue) - \(detail.reason)")
            }
        }
        out.append("")
        out.append("## Metrics")
        let m = r.metrics
        out.append("- generated_loc: \(m.generatedLOC) non-blank ported lines")
        out.append("- Sections inert total: \(m.inertSections)/\(m.totalSections) (\(percent(m.inertRatio)) total inert; includes intentional docs/templates/tools metadata)")
        out.append("- Operational inert: \(m.operationalInertSections)")
        out.append("- Unclassified inert: \(m.unclassifiedInertSections)")
        out.append("- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): \(m.inertMarkerCount)")
        if !m.inertCategoryCounts.isEmpty {
            let categoryText = m.inertCategoryCounts
                .map { "\($0.category.rawValue)=\($0.count)" }
                .joined(separator: ", ")
            out.append("- Inert categories: \(categoryText)")
        }
        out.append("- Judgment: \(m.judgmentBlocks) blocks, \(m.judgmentLines) lines")
        out.append("- canonical_drift: synonym=\(m.canonicalDriftSynonym), structure=\(m.canonicalDriftStructure), desugar=\(m.canonicalDriftDesugar), meaning=\(m.canonicalDriftMeaning)")
        if !m.inertDetails.isEmpty {
            out.append("")
            out.append("### Inert section details")
            for detail in m.inertDetails {
                out.append("- L\(detail.line) `\(detail.heading)`: \(detail.category.rawValue) — \(detail.reason)")
            }
        }
        if includeDiff {
            out.append("")
            out.append("## Unified diff")
            out.append("")
            out.append("```diff")
            if r.unifiedDiff.isEmpty {
                out.append("(identical)")
            } else {
                out.append("--- \(r.originalDiffPath)")
                out.append("+++ \(r.portedDiffPath)")
                out.append(r.unifiedDiff)
            }
            out.append("```")
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func inertSectionDeviations(
        originalMarkdown: String,
        metrics: SkillMetrics,
        portedMeri: String
    ) -> [SkillMetrics.InertSection] {
        let originalInert = originalExplicitInertHeadings(originalMarkdown)
        let splitFamily = generatedSplitFamilyHeadings(portedMeri)
        return metrics.inertDetails.filter { detail in
            !originalInert.contains(normalizeHeading(detail.heading))
                && !splitFamily.contains(normalizeHeading(detail.heading))
        }
    }

    /// Headings in `portedMeri` that belong to a migrator-generated split
    /// family (`SkillMigrator.splitHeadingSeparator`, AGENTS.md Phase 1 item
    /// 3): both the generated sibling(s) themselves and the original heading
    /// they were split from. Paired back to the source heading per the same
    /// rule as `SkillMetrics.analyze`'s section-count fix, so this whole
    /// family isn't flagged as a migration regression — the split's
    /// operational content was preserved (routed to `procedure` via a
    /// rulebook `SectionAlias`), not lost, and a sibling can still look
    /// nominally "inert" here if the caller didn't also supply that rulebook.
    /// Consecutive siblings (`— steps`, `— steps 2`, …) all attribute back to
    /// the nearest non-generated heading above them.
    private static func generatedSplitFamilyHeadings(_ portedMeri: String) -> Set<String> {
        var out: Set<String> = []
        var lastRealHeading: String?
        for section in MarkdownOutline.build(rawLines: bodyLines(of: portedMeri)) {
            let clean = SkillSectionRole.parseMarker(from: section.heading).cleanHeading
            if clean.contains(SkillMigrator.splitHeadingSeparator) {
                out.insert(normalizeHeading(clean))
                if let parent = lastRealHeading { out.insert(normalizeHeading(parent)) }
            } else {
                lastRealHeading = clean
            }
        }
        return out
    }

    private static func originalExplicitInertHeadings(_ source: String) -> Set<String> {
        var out: Set<String> = []
        for section in MarkdownOutline.build(rawLines: bodyLines(of: source)) {
            let parsed = SkillSectionRole.parseMarker(from: section.heading)
            if parsed.marker?.inert == true {
                out.insert(normalizeHeading(parsed.cleanHeading))
            }
        }
        return out
    }

    private static func normalizeHeading(_ heading: String) -> String {
        heading
            .lowercased()
            .replacingOccurrences(of: #"[\s\p{Punct}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func bodyLines(of source: String) -> [String] {
        let lines = source.components(separatedBy: "\n")
        guard let fm = Frontmatter.locate(lines, skipLeadingBlanks: true) else {
            return lines
        }
        var out = Array(lines[..<fm.open])
        if fm.close + 1 < lines.count {
            out.append(contentsOf: lines[(fm.close + 1)...])
        }
        return out
    }

    // MARK: - Frontmatter extraction

    /// Returns the key -> raw value map from the leading `---`/`---` block.
    /// Mirrors `SkillMigrator.frontmatterKeys`' line discipline (skip blanks,
    /// comments, list-item lines) but also captures values for the Changed set.
    static func frontmatter(_ source: String) -> [String: String] {
        let lines = source.components(separatedBy: "\n")
        guard let fm = Frontmatter.locate(lines, skipLeadingBlanks: true) else { return [:] }

        var result: [String: String] = [:]
        var lastKey: String?
        for raw in lines[(fm.open + 1)..<fm.close] {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            // List-item continuation lines belong to the previous key.
            if trimmed.hasPrefix("-"), let key = lastKey {
                let item = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                if !item.isEmpty {
                    result[key] = (result[key].map { $0.isEmpty ? item : $0 + "\n" + item }) ?? item
                }
                continue
            }
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colon]).lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value
            lastKey = key
        }
        return result
    }

    /// Normalize a frontmatter value so YAML-vs-inline list reformatting and
    /// whitespace churn do not register as a genuine change. List items are
    /// split on newlines/commas, trimmed, de-quoted, and sorted.
    static func normalizeValue(_ value: String) -> String {
        let items = value
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
        if items.count <= 1 {
            return value
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .joined(separator: " ")
        }
        return items.sorted().joined(separator: ",")
    }

    // MARK: - Categories

    /// The structural transforms the universal-sections migration applies, named
    /// to match the marking pass in `SkillMigrator`:
    ///   `frontmatter-injected` — the port added frontmatter keys.
    ///   `section-marker-added` — the port introduced `(( … ))` heading markers.
    ///   `shell-block-routed` — at least one heading became `(( role: procedure ))`
    ///     because its body was pure shell fences.
    ///   `preamble-blockquoted` — the port blockquoted pre-heading prose the
    ///     original carried as plain text.
    static func detectCategories(
        originalMarkdown: String,
        portedMeri: String,
        frontmatterAdded: [String]
    ) -> [String] {
        var out: [String] = []
        if !frontmatterAdded.isEmpty { out.append("frontmatter-injected") }
        if portedMeri.contains("(( ") && !originalMarkdown.contains("(( ") {
            out.append("section-marker-added")
        }
        if portedMeri.contains("(( role: procedure ))") {
            out.append("shell-block-routed")
        }
        if preambleBlockquoteCount(portedMeri) > preambleBlockquoteCount(originalMarkdown) {
            out.append("preamble-blockquoted")
        }
        if commandHolesRewritten(originalMarkdown: originalMarkdown, portedMeri: portedMeri) {
            out.append("command-hole-rewritten")
        }
        return out
    }

    /// True when the port turned an angle-bracket placeholder (`<name>`) inside a
    /// command span into a typed command hole (`{name}`) — i.e. the ported text
    /// gained a word-shaped `{…}` hole inside backticks whose name appeared as a
    /// `<…>` placeholder in the original.
    static func commandHolesRewritten(originalMarkdown: String, portedMeri: String) -> Bool {
        let originalAngles = backtickPlaceholders(originalMarkdown, open: "<", close: ">")
        guard !originalAngles.isEmpty else { return false }
        let portedHoles = backtickPlaceholders(portedMeri, open: "{", close: "}")
        return !portedHoles.isDisjoint(with: originalAngles)
    }

    /// Names enclosed by `open`/`close` markers that occur inside a backtick span,
    /// normalized (lowercased, alphanumerics only) and word-shaped.
    private static func backtickPlaceholders(_ source: String, open: Character, close: Character) -> Set<String> {
        var names: Set<String> = []
        for line in source.components(separatedBy: "\n") {
            guard line.contains("`") else { continue }
            var inSpan = false
            var span = ""
            for ch in line {
                if ch == "`" {
                    if inSpan { collectPlaceholders(span, open: open, close: close, into: &names) }
                    inSpan.toggle(); span = ""
                    continue
                }
                if inSpan { span.append(ch) }
            }
        }
        return names
    }

    private static func collectPlaceholders(_ span: String, open: Character, close: Character, into names: inout Set<String>) {
        let chars = Array(span)
        var i = 0
        while i < chars.count {
            if chars[i] == open {
                var j = i + 1
                var inner = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == close { closed = true; break }
                    if chars[j] == open { break }
                    inner.append(chars[j]); j += 1
                }
                let trimmed = inner.trimmingCharacters(in: .whitespaces)
                if closed, SkillMigrator.isWordShaped(trimmed) {
                    names.insert(SkillMigrator.scopeKey(trimmed))
                    i = j + 1; continue
                }
            }
            i += 1
        }
    }

    /// Number of blockquote (`>`) lines before the first `##` section heading —
    /// the region `SkillMigrator` blockquotes. A `#` title line neither counts
    /// nor terminates the scan (the migrator skips it too).
    static func preambleBlockquoteCount(_ source: String) -> Int {
        let lines = source.components(separatedBy: "\n")
        var i = 0
        while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).isEmpty { i += 1 }
        // Skip a leading frontmatter block.
        if let fm = Frontmatter.locate(lines, skipLeadingBlanks: true) { i = fm.close + 1 }
        var count = 0
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("##") { break }
            if t.hasPrefix(">") { count += 1 }
            i += 1
        }
        return count
    }

    // MARK: - Pairing helpers (shared source of truth for batch tools)

    /// Lowercase, mapping any non-alphanumeric run to a single underscore region
    /// (spaces/hyphens/dots become `_`). Matches `SkillMigrator`/CLI slugging.
    public static func slug(_ name: String) -> String {
        var out = ""
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber { out.append(ch) }
            else if ch == " " || ch == "-" || ch == "." { out.append("_") }
        }
        return out.isEmpty ? "skill" : out
    }

    /// A SKILL.md typically lives in `<skill-name>/SKILL.md`; use the parent
    /// directory name as the stem when the file itself is SKILL.md, otherwise
    /// the file's own base name.
    public static func meriStem(forSkillAt url: URL) -> String {
        if url.lastPathComponent.uppercased() == "SKILL.MD" {
            return slug(url.deletingLastPathComponent().lastPathComponent)
        }
        return slug(url.deletingPathExtension().lastPathComponent)
    }

    // MARK: - Render helpers

    private static func tierLabel(_ tier: Int) -> String {
        switch tier {
        case 1: return "near-verbatim"
        case 2: return "light edits"
        default: return "structural rewrite"
        }
    }

    private static func percent(_ x: Double) -> String {
        String(format: "%.0f%%", x * 100)
    }

    private static func listOrNone(_ items: [String]) -> String {
        items.isEmpty ? "(none)" : items.map { "`\($0)`" }.joined(separator: ", ")
    }
}
