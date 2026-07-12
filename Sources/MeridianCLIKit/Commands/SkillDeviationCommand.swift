import ArgumentParser
import Foundation
import MeridianCore

public struct SkillDeviationCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "skill-deviation",
        abstract: "Report how a ported .meri deviates from its original SKILL.md."
    )

    @Argument(help: "Original SKILL.md (or a directory of skills with --batch).")
    var original: String

    @Argument(help: "Ported .meri (or a directory of .meri files with --batch).")
    var ported: String

    @Option(name: .shortAndLong, help: "Output directory for per-skill deviation reports. Printed to stdout (single mode) when omitted.")
    var out: String?

    @Flag(name: .long, help: "Treat both inputs as directories and pair SKILL.md files with their <slug>.meri ports.")
    var batch: Bool = false

    @Flag(name: .long, help: "With --batch, also write a README.md index summarizing tiers/similarity.")
    var index: Bool = false

    @Flag(name: .long, help: "Omit the raw unified diff; emit summary-only reports.")
    var noDiff: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        let traceInstance = try cliTrace.makeTrace()
        if batch {
            try runBatch(trace: traceInstance)
        } else {
            try runSingle(trace: traceInstance)
        }
    }

    // MARK: - Single

    private func runSingle(trace: ParserTrace) throws {
        let origURL = URL(fileURLWithPath: original).standardized
        let portURL = URL(fileURLWithPath: ported).standardized
        let fm = FileManager.default
        guard fm.fileExists(atPath: origURL.path) else { throw ValidationError("Original not found: \(original)") }
        guard fm.fileExists(atPath: portURL.path) else { throw ValidationError("Ported file not found: \(ported)") }
        let rulebook = try loadRulebook(beside: portURL, trace: trace)
        let lexicon = try loadLexicon(beside: portURL, trace: trace)
        let dependencies = try loadCompilerInputs(beside: portURL)
        let originalSource = try String(contentsOf: origURL, encoding: .utf8)
        let portedSource = try String(contentsOf: portURL, encoding: .utf8)

        var report = SkillDeviation.analyze(
            originalMarkdown: originalSource,
            portedMeri: portedSource,
            originalName: origURL.lastPathComponent,
            portedName: portURL.lastPathComponent,
            rulebook: rulebook,
            lexicon: lexicon
        )
        try recordCanonicalDrift(into: &report, portedMeri: portedSource, portedFile: portURL.lastPathComponent,
                                  dependencies: dependencies, trace: trace)
        let markdown = SkillDeviation.renderMarkdown(report, includeDiff: !noDiff)

        if let out {
            let dir = URL(fileURLWithPath: out).standardized
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let stem = portURL.deletingPathExtension().lastPathComponent
            let file = dir.appendingPathComponent("\(stem).md")
            try markdown.write(to: file, atomically: true, encoding: .utf8)
            print("✓ \(file.path)  tier=\(report.tier) similarity=\(percent(report.similarity))")
        } else {
            print(markdown)
        }
    }

    // MARK: - Batch

    private func runBatch(trace: ParserTrace) throws {
        let fm = FileManager.default
        let origDir = URL(fileURLWithPath: original).standardized
        let portDir = URL(fileURLWithPath: ported).standardized
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: origDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("--batch requires a directory: \(original)")
        }
        guard fm.fileExists(atPath: portDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("--batch requires a directory: \(ported)")
        }

        // Index the ported .meri files by stem (recursive, so a corpus whose
        // dispatcher .meri sits beside the skills/ subdir is still covered).
        // Keyed by the lowercased filename stem. `.meri` stems are already in the
        // slug target form (underscores), so only case needs normalizing to match
        // the original-side `meriStem` (e.g. `RESOLVER.meri` <-> `RESOLVER.md`).
        var meriByStem: [String: URL] = [:]
        if let enumerator = fm.enumerator(at: portDir, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "meri" {
                meriByStem[url.deletingPathExtension().lastPathComponent.lowercased()] = url
            }
        }
        var pairedMeriStems = Set<String>()

        // Discover original sources: <name>/SKILL.md and top-level *.md.
        let originalSources = try discoverOriginals(in: origDir)
        let skippedNonSkillDirs = try countDirsWithoutSkill(in: origDir)

        let outDir = out.map { URL(fileURLWithPath: $0).standardized }
        if let outDir { try fm.createDirectory(at: outDir, withIntermediateDirectories: true) }
        let placeholder = portDir.appendingPathComponent("placeholder.meri")
        let rulebook = try loadRulebook(beside: placeholder, trace: trace)
        let lexicon = try loadLexicon(beside: placeholder, trace: trace)
        let dependencies = try loadCompilerInputs(beside: placeholder)

        var rows: [SkillDeviation.DeviationReport] = []
        var unpairedOriginals: [String] = []

        for src in originalSources.sorted(by: { $0.path < $1.path }) {
            let stem = SkillDeviation.meriStem(forSkillAt: src)
            guard let meriURL = meriByStem[stem] else {
                unpairedOriginals.append("\(displayName(src, base: origDir)) (expected \(stem).meri)")
                continue
            }
            pairedMeriStems.insert(stem)
            // Diff headers use corpus-root-relative paths: `<origDirName>/<rel>`
            // on the original side and the ported file's path relative to the
            // ported root (e.g. `skills/foo.meri`, or `RESOLVER.meri` at root).
            let origRel = displayName(src, base: origDir)
            let originalSource = try String(contentsOf: src, encoding: .utf8)
            let portedSource = try String(contentsOf: meriURL, encoding: .utf8)
            var report = SkillDeviation.analyze(
                originalMarkdown: originalSource,
                portedMeri: portedSource,
                originalName: origRel,
                portedName: meriURL.lastPathComponent,
                originalDiffPath: "\(origDir.lastPathComponent)/\(origRel)",
                portedDiffPath: displayName(meriURL, base: portDir),
                rulebook: rulebook,
                lexicon: lexicon
            )
            try recordCanonicalDrift(into: &report, portedMeri: portedSource, portedFile: meriURL.lastPathComponent,
                                      dependencies: dependencies, trace: trace)
            rows.append(report)
            let reportStem = meriURL.deletingPathExtension().lastPathComponent
            if let outDir {
                let file = outDir.appendingPathComponent("\(reportStem).md")
                try SkillDeviation.renderMarkdown(report, includeDiff: !noDiff).write(to: file, atomically: true, encoding: .utf8)
            }
            print("✓ \(reportStem)  tier=\(report.tier) similarity=\(percent(report.similarity))")
        }

        let unpairedPorted = meriByStem
            .filter { !pairedMeriStems.contains($0.key) }
            .map { $0.value.lastPathComponent }
            .sorted()

        if index, let outDir {
            let readme = buildIndex(
                rows: rows.sorted { $0.portedName < $1.portedName },
                unpairedOriginals: unpairedOriginals.sorted(),
                unpairedPorted: unpairedPorted,
                skippedNonSkillDirs: skippedNonSkillDirs
            )
            try readme.write(to: outDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            print("✓ index → \(outDir.appendingPathComponent("README.md").path)")
        }

        print("Analyzed \(rows.count) pairs. unpaired-originals=\(unpairedOriginals.count) unpaired-ported=\(unpairedPorted.count) skipped-non-skill-dirs=\(skippedNonSkillDirs)")
    }

    // MARK: - Discovery

    private func discoverOriginals(in dir: URL) throws -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            throw cliDirectoryEnumerationFailed(dir.path)
        }
        for case let url as URL in enumerator where url.lastPathComponent.uppercased() == "SKILL.MD" {
            result.append(url)
        }
        let topLevel = try listDirectoryContents(at: dir, label: "originals directory")
        for url in topLevel where url.pathExtension.lowercased() == "md" && !url.lastPathComponent.hasPrefix("_") {
            result.append(url)
        }
        return result
    }

    private func countDirsWithoutSkill(in dir: URL) throws -> Int {
        let fm = FileManager.default
        let entries = try listDirectoryContents(at: dir, label: "batch originals directory")
        var count = 0
        for url in entries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let skill = url.appendingPathComponent("SKILL.md")
            if !fm.fileExists(atPath: skill.path) { count += 1 }
        }
        return count
    }

    private func displayName(_ url: URL, base: URL) -> String {
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        if url.path.hasPrefix(basePath) { return String(url.path.dropFirst(basePath.count)) }
        return url.lastPathComponent
    }

    private func loadRulebook(beside inputURL: URL, trace: ParserTrace) throws -> Rulebook {
        let urls = try DependencyDiscovery.resolveRulebooks(explicit: [], beside: inputURL)
        var merged = Rulebook.empty
        let parser = RulebookParser(trace: trace)
        for url in urls {
            let source = try String(contentsOf: url, encoding: .utf8)
            merged = merged.merging(try parser.parse(source, file: url.lastPathComponent))
        }
        return merged
    }

    private func loadCompilerInputs(beside inputURL: URL) throws
        -> (vocabularies: [Compiler.VocabularyInput], rulebooks: [RulebookInput]) {
        let vocabURLs = try DependencyDiscovery.resolveMerconfigs(explicit: [], beside: inputURL)
        let rulebookURLs = try DependencyDiscovery.resolveRulebooks(explicit: [], beside: inputURL)
        return (
            try DependencyDiscovery.loadVocabularies(vocabURLs),
            try DependencyDiscovery.loadRulebooks(rulebookURLs)
        )
    }

    private func recordCanonicalDrift(
        into report: inout SkillDeviation.DeviationReport,
        portedMeri: String,
        portedFile: String,
        dependencies: (vocabularies: [Compiler.VocabularyInput], rulebooks: [RulebookInput]),
        trace: ParserTrace
    ) throws {
        guard !dependencies.vocabularies.isEmpty || !dependencies.rulebooks.isEmpty else { return }
        let model = try Compiler(options: .init(trace: trace)).compileToModel(
            meridianSource: portedMeri,
            meridianFile: portedFile,
            vocabularies: dependencies.vocabularies,
            rulebooks: dependencies.rulebooks
        )
        let canonical = try trace.phase("verbalize") {
            try Verbalizer(model: model, trace: trace).verbalize()
        }
        let drift = trace.phase("drift") {
            DriftEngine.diff(authored: model.authoredSource, canonical: canonical, trace: trace)
        }
        report.metrics.recordCanonicalDrift(drift)
    }

    /// Real `EnglishLexicon` merged with every discovered `.merconfig`'s
    /// `=== language ===` synonyms (`normativeCueWords`/`inferenceCueWords`/
    /// `referenceHeadingWords`, per P2) — the same corpus-tuned vocabulary
    /// `SkillMetrics.analyze`'s reference/operational discrimination (§5)
    /// needs, rather than the conservative built-in default.
    private func loadLexicon(beside inputURL: URL, trace: ParserTrace) throws -> EnglishLexicon {
        let urls = try DependencyDiscovery.resolveMerconfigs(explicit: [], beside: inputURL)
        guard !urls.isEmpty else { return .default }
        let parser = MerConfigParser(trace: trace)
        var merged = MerConfigFile()
        for url in urls {
            let source = try String(contentsOf: url, encoding: .utf8)
            merged = try merged.merging(try parser.parse(source, file: url.lastPathComponent))
        }
        return EnglishLexicon.default.merging(
            comparisonSynonyms: merged.languageSynonyms.comparisonSynonyms,
            durationSynonyms: merged.languageSynonyms.durationSynonyms,
            assertionSynonyms: merged.languageSynonyms.assertionSynonyms,
            normativeCueSynonyms: merged.languageSynonyms.normativeCueSynonyms,
            inferenceCueSynonyms: merged.languageSynonyms.inferenceCueSynonyms,
            referenceHeadingSynonyms: merged.languageSynonyms.referenceHeadingSynonyms
        )
    }

    // MARK: - Index

    private func buildIndex(
        rows: [SkillDeviation.DeviationReport],
        unpairedOriginals: [String],
        unpairedPorted: [String],
        skippedNonSkillDirs: Int
    ) -> String {
        var out: [String] = []
        out.append("# Migration deviations")
        out.append("")
        out.append("Per-skill deviation between the original gbrain `SKILL.md` and the ported `.meri`.")
        out.append("Generated by `meridian skill-deviation --batch`.")
        out.append("")
        let tier1 = rows.filter { $0.tier == 1 }.count
        let tier2 = rows.filter { $0.tier == 2 }.count
        let tier3 = rows.filter { $0.tier == 3 }.count
        let avg = rows.isEmpty ? 0 : rows.map(\.similarity).reduce(0, +) / Double(rows.count)
        let totalSections = rows.reduce(0) { $0 + $1.metrics.totalSections }
        let inertSections = rows.reduce(0) { $0 + $1.metrics.inertSections }
        let operationalInertSections = rows.reduce(0) { $0 + $1.metrics.operationalInertSections }
        let unclassifiedInertSections = rows.reduce(0) { $0 + $1.metrics.unclassifiedInertSections }
        let inertMarkers = rows.reduce(0) { $0 + $1.metrics.inertMarkerCount }
        let inertDeviations = rows.reduce(0) { $0 + $1.inertSectionDeviations.count }
        let totalJudgmentBlocks = rows.reduce(0) { $0 + $1.metrics.judgmentBlocks }
        let totalJudgmentLines = rows.reduce(0) { $0 + $1.metrics.judgmentLines }
        let driftSynonym = rows.reduce(0) { $0 + $1.metrics.canonicalDriftSynonym }
        let driftStructure = rows.reduce(0) { $0 + $1.metrics.canonicalDriftStructure }
        let driftDesugar = rows.reduce(0) { $0 + $1.metrics.canonicalDriftDesugar }
        let driftMeaning = rows.reduce(0) { $0 + $1.metrics.canonicalDriftMeaning }
        let avgInertRatio = rows.isEmpty ? 0 : rows.map(\.metrics.inertRatio).reduce(0, +) / Double(rows.count)
        let categoryCounts = inertCategorySummary(rows)
        out.append("## Summary")
        out.append("")
        out.append("- Pairs analyzed: \(rows.count)")
        out.append("- Tier 1 (near-verbatim): \(tier1)")
        out.append("- Tier 2 (light edits): \(tier2)")
        out.append("- Tier 3 (structural rewrite): \(tier3)")
        out.append("- Average similarity: \(percent(avg))")
        let totalGeneratedLOC = rows.reduce(0) { $0 + $1.metrics.generatedLOC }
        out.append("- generated_loc total: \(totalGeneratedLOC) non-blank ported lines")
        out.append("- Sections inert total: \(inertSections)/\(totalSections) (avg total-inert ratio \(percent(avgInertRatio)); includes intentional docs/templates/tools metadata)")
        out.append("- Inert deviations: \(inertDeviations)")
        out.append("- Operational inert: \(operationalInertSections)")
        out.append("- Unclassified inert: \(unclassifiedInertSections)")
        out.append("- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): \(inertMarkers)")
        if !categoryCounts.isEmpty {
            out.append("- Inert categories: " + categoryCounts.map { "\($0.category.rawValue)=\($0.count)" }.joined(separator: ", "))
        }
        out.append("- Judgment: \(totalJudgmentBlocks) blocks, \(totalJudgmentLines) lines")
        out.append("- canonical_drift: synonym=\(driftSynonym), structure=\(driftStructure), desugar=\(driftDesugar), meaning=\(driftMeaning)")
        out.append("- Non-skill directories skipped (no SKILL.md, e.g. `conventions/`, `migrations/`): \(skippedNonSkillDirs)")
        out.append("")
        out.append("## Per-skill")
        out.append("")
        out.append("| skill | tier | similarity | lines | generated_loc | inert deviations | inert | operational inert | judgment | canonical_drift | frontmatter added | categories |")
        out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for r in rows {
            let stem = (r.portedName as NSString).deletingPathExtension
            let fmAdded = r.frontmatterAdded.isEmpty ? "(none)" : r.frontmatterAdded.joined(separator: " ")
            let cats = r.categories.isEmpty ? "(none)" : r.categories.joined(separator: " ")
            let m = r.metrics
            let drift = "\(m.canonicalDriftSynonym)/\(m.canonicalDriftStructure)/\(m.canonicalDriftDesugar)/\(m.canonicalDriftMeaning)"
            out.append("| [\(stem)](\(stem).md) | \(r.tier) | \(percent(r.similarity)) | \(r.originalLineCount)→\(r.portedLineCount) | \(m.generatedLOC) | \(r.inertSectionDeviations.count) | \(m.inertSections)/\(m.totalSections) | \(m.operationalInertSections) | \(m.judgmentBlocks)/\(m.judgmentLines) | \(drift) | \(fmAdded) | \(cats) |")
        }
        if !unpairedOriginals.isEmpty {
            out.append("")
            out.append("## Unpaired originals (no matching .meri)")
            out.append("")
            for u in unpairedOriginals { out.append("- \(u)") }
        }
        if !unpairedPorted.isEmpty {
            out.append("")
            out.append("## Unpaired ports (no matching SKILL.md)")
            out.append("")
            for u in unpairedPorted { out.append("- `\(u)`") }
        }
        return out.joined(separator: "\n") + "\n"
    }

    private func inertCategorySummary(_ rows: [SkillDeviation.DeviationReport])
        -> [(category: SkillMetrics.InertCategory, count: Int)] {
        var counts: [SkillMetrics.InertCategory: Int] = [:]
        for row in rows {
            for detail in row.metrics.inertDetails {
                counts[detail.category, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.category < $1.category }
    }

    private func percent(_ x: Double) -> String { String(format: "%.0f%%", x * 100) }
}
