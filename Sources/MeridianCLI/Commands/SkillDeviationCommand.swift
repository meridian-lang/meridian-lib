import ArgumentParser
import Foundation
import MeridianCore

struct SkillDeviationCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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

    func run() async throws {
        if batch {
            try runBatch()
        } else {
            try runSingle()
        }
    }

    // MARK: - Single

    private func runSingle() throws {
        let origURL = URL(fileURLWithPath: original).standardized
        let portURL = URL(fileURLWithPath: ported).standardized
        let fm = FileManager.default
        guard fm.fileExists(atPath: origURL.path) else { throw ValidationError("Original not found: \(original)") }
        guard fm.fileExists(atPath: portURL.path) else { throw ValidationError("Ported file not found: \(ported)") }

        let report = SkillDeviation.analyze(
            originalMarkdown: try String(contentsOf: origURL, encoding: .utf8),
            portedMeri: try String(contentsOf: portURL, encoding: .utf8),
            originalName: origURL.lastPathComponent,
            portedName: portURL.lastPathComponent
        )
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

    private func runBatch() throws {
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
        let skippedNonSkillDirs = countDirsWithoutSkill(in: origDir)

        let outDir = out.map { URL(fileURLWithPath: $0).standardized }
        if let outDir { try fm.createDirectory(at: outDir, withIntermediateDirectories: true) }

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
            let report = SkillDeviation.analyze(
                originalMarkdown: try String(contentsOf: src, encoding: .utf8),
                portedMeri: try String(contentsOf: meriURL, encoding: .utf8),
                originalName: origRel,
                portedName: meriURL.lastPathComponent,
                originalDiffPath: "\(origDir.lastPathComponent)/\(origRel)",
                portedDiffPath: displayName(meriURL, base: portDir)
            )
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
        // <name>/SKILL.md
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in enumerator where url.lastPathComponent.uppercased() == "SKILL.MD" {
            result.append(url)
        }
        // Top-level *.md (e.g. RESOLVER.md), excluding leading-underscore support docs.
        let topLevel = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for url in topLevel where url.pathExtension.lowercased() == "md" && !url.lastPathComponent.hasPrefix("_") {
            result.append(url)
        }
        return result
    }

    private func countDirsWithoutSkill(in dir: URL) -> Int {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
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
        out.append("## Summary")
        out.append("")
        out.append("- Pairs analyzed: \(rows.count)")
        out.append("- Tier 1 (near-verbatim): \(tier1)")
        out.append("- Tier 2 (light edits): \(tier2)")
        out.append("- Tier 3 (structural rewrite): \(tier3)")
        out.append("- Average similarity: \(percent(avg))")
        out.append("- Non-skill directories skipped (no SKILL.md, e.g. `conventions/`, `migrations/`): \(skippedNonSkillDirs)")
        out.append("")
        out.append("## Per-skill")
        out.append("")
        out.append("| skill | tier | similarity | lines | frontmatter added | categories |")
        out.append("|---|---|---|---|---|---|")
        for r in rows {
            let stem = (r.portedName as NSString).deletingPathExtension
            let fmAdded = r.frontmatterAdded.isEmpty ? "(none)" : r.frontmatterAdded.joined(separator: " ")
            let cats = r.categories.isEmpty ? "(none)" : r.categories.joined(separator: " ")
            out.append("| [\(stem)](\(stem).md) | \(r.tier) | \(percent(r.similarity)) | \(r.originalLineCount)→\(r.portedLineCount) | \(fmAdded) | \(cats) |")
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

    private func percent(_ x: Double) -> String { String(format: "%.0f%%", x * 100) }
}
