import ArgumentParser
import Foundation
import MeridianCore

struct MigrateSkillCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate-skill",
        abstract: "Migrate a gbrain SKILL.md into a strict-compiling .meri file (injects no frontmatter; section semantics activate on the ##/### headings)."
    )

    @Argument(help: "Path to a SKILL.md file, or a directory of them when --batch is set.")
    var input: String

    @Option(name: .shortAndLong, help: "Output .meri path (single) or directory (--batch). Required to write; without it, the result is printed to stdout.")
    var out: String?

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable. Autodiscovered beside the input when omitted.")
    var vocab: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules file. Repeatable. Autodiscovered beside the input when omitted.")
    var rulebook: [String] = []

    @Option(name: .long, help: "Model identifier for LLM-assisted repair. Repair requires a host-provided LLM provider; not wired in this build.")
    var llm: String?

    @Option(name: .long, help: "Maximum LLM repair rounds when a candidate fails strict compilation.")
    var maxRepair: Int = 0

    @Option(name: .long, help: "Write a migration report to this path (text). With --batch, written as a coverage matrix.")
    var report: String?

    @Flag(name: .long, help: "Treat the input as a directory and migrate every SKILL.md within.")
    var batch: Bool = false

    @Flag(name: .long, help: "Overwrite an existing output file.")
    var force: Bool = false

    func run() async throws {
        let inputURL = URL(fileURLWithPath: input).standardized
        let fm = FileManager.default
        guard fm.fileExists(atPath: inputURL.path) else {
            throw ValidationError("Input not found: \(input)")
        }

        let (vocabularies, rulebooks) =
            try loadDependencies(beside: batch ? inputURL : inputURL.deletingLastPathComponent())

        let migrator = SkillMigrator(
            compiler: Compiler(options: .init(trace: ParserTrace.silent())),
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            options: .init(maxRepair: maxRepair),
            repair: repairClosure()
        )

        let depsDir = batch ? inputURL : inputURL.deletingLastPathComponent()
        let rulebookTarget = out == nil ? nil : primaryRulebookTarget(beside: depsDir)

        if batch {
            try await runBatch(inputURL: inputURL, migrator: migrator, rulebookTarget: rulebookTarget)
        } else {
            try await runSingle(inputURL: inputURL, migrator: migrator, rulebookTarget: rulebookTarget)
        }
    }

    // MARK: - Single + batch drivers

    private func runSingle(inputURL: URL, migrator: SkillMigrator, rulebookTarget: URL?) async throws {
        let markdown = try String(contentsOf: inputURL, encoding: .utf8)
        let stem = inputURL.deletingPathExtension().lastPathComponent
        let result = try await migrator.migrate(markdown, file: "\(meriStem(forSkillAt: inputURL)).meri")

        if let out {
            let outURL = URL(fileURLWithPath: out).standardized
            try writeMeri(result.meriSource, to: outURL)
            print(result.compiledOK ? "✓ \(outURL.path)" : "✗ \(outURL.path) (does not strict-compile)")
        } else {
            print(result.meriSource)
        }

        try persistSectionAliases(result.sectionAliases, to: rulebookTarget)

        if let report {
            let text = singleReport(stem: stem, result: result)
            try text.write(to: URL(fileURLWithPath: report).standardized, atomically: true, encoding: .utf8)
        }

        if !result.compiledOK {
            throw ExitCode(1)
        }
    }

    private func runBatch(inputURL: URL, migrator: SkillMigrator, rulebookTarget: URL?) async throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: inputURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("--batch requires a directory: \(input)")
        }
        let skillFiles = try discoverSkillFiles(in: inputURL).sorted { $0.path < $1.path }
        guard !skillFiles.isEmpty else {
            throw ValidationError("No SKILL.md files found under \(inputURL.path)")
        }

        var rows: [(stem: String, result: SkillMigrator.Result)] = []
        let outDir = out.map { URL(fileURLWithPath: $0).standardized }
        if let outDir { try fm.createDirectory(at: outDir, withIntermediateDirectories: true) }

        var failures = 0
        var allAliases: [SkillMigrator.SectionAlias] = []
        for file in skillFiles {
            let markdown = try String(contentsOf: file, encoding: .utf8)
            let stem = meriStem(forSkillAt: file)
            let result = try await migrator.migrate(markdown, file: "\(stem).meri")
            rows.append((stem, result))
            allAliases.append(contentsOf: result.sectionAliases)
            if !result.compiledOK { failures += 1 }
            if let outDir {
                try writeMeri(result.meriSource, to: outDir.appendingPathComponent("\(stem).meri"))
            }
            print("\(result.compiledOK ? "✓" : "✗") \(stem)  edits=\(result.report.editCount) repairs=\(result.report.repairAttempts)")
        }

        try persistSectionAliases(allAliases, to: rulebookTarget)

        if let report {
            let matrix = coverageMatrix(rows: rows)
            try matrix.write(to: URL(fileURLWithPath: report).standardized, atomically: true, encoding: .utf8)
            print("✓ coverage matrix → \(report)")
        }

        print("Migrated \(rows.count) skills, \(rows.count - failures) compile, \(failures) failing.")
        if failures > 0 { throw ExitCode(1) }
    }

    // MARK: - Repair closure

    /// LLM-assisted repair requires a host-supplied `LLMProvider`. This build
    /// ships no networked provider (mirroring the deliberately-unimplemented
    /// `llm.chat` built-in), so repair is not wired here. The deterministic
    /// transform + strict compile path is fully functional; `--max-repair`/`--llm`
    /// are reserved for hosts that embed `SkillMigrator` with a real provider.
    private func repairClosure() -> (@Sendable (SkillMigrator.RepairRequest) async throws -> String)? {
        nil
    }

    // MARK: - Dependency loading

    private func loadDependencies(beside dir: URL) throws
        -> (vocab: [Compiler.VocabularyInput], rulebooks: [RulebookInput]) {
        let vocabURLs = vocab.isEmpty
            ? autodiscover(extension: "merconfig", from: dir)
            : vocab.map { URL(fileURLWithPath: $0).standardized }
        let rulebookURLs = rulebook.isEmpty
            ? autodiscover(extension: "merrules", from: dir)
            : rulebook.map { URL(fileURLWithPath: $0).standardized }

        var vocabularies: [Compiler.VocabularyInput] = []
        for url in vocabURLs {
            let src = try String(contentsOf: url, encoding: .utf8)
            vocabularies.append(.init(name: url.deletingPathExtension().lastPathComponent,
                                      file: url.lastPathComponent, source: src))
        }
        var rulebooks: [RulebookInput] = []
        for url in rulebookURLs {
            let src = try String(contentsOf: url, encoding: .utf8)
            rulebooks.append(.init(name: url.deletingPathExtension().lastPathComponent,
                                   file: url.lastPathComponent, source: src))
        }
        return (vocabularies, rulebooks)
    }

    /// The rulebook file section aliases are persisted to: the first `--rulebook`
    /// if given, else the first autodiscovered `.merrules`, else a new
    /// `migrated-sections.merrules` beside the output (single: output's parent;
    /// batch: the output directory).
    private func primaryRulebookTarget(beside dir: URL) -> URL? {
        if let first = rulebook.first { return URL(fileURLWithPath: first).standardized }
        if let discovered = autodiscover(extension: "merrules", from: dir).first { return discovered }
        guard let out else { return nil }
        let outURL = URL(fileURLWithPath: out).standardized
        let base = batch ? outURL : outURL.deletingLastPathComponent()
        return base.appendingPathComponent("migrated-sections.merrules")
    }

    /// Append section-role aliases (heading → role) to the rulebook so future
    /// compiles/re-migrations recognize the heading with no in-file marker. Skips
    /// aliases already present (normalized-heading match), creates the
    /// `=== sections ===` block (and the file) when absent, and — when there is
    /// no target (stdout/preview mode) — prints a snippet instead of writing.
    private func persistSectionAliases(_ aliases: [SkillMigrator.SectionAlias], to target: URL?) throws {
        let unique = dedupeAliases(aliases)
        guard !unique.isEmpty else { return }

        guard let target else {
            print("// Add these section aliases to your .merrules (=== sections ===):")
            for a in unique { print("section \"\(a.heading)\" -> \(a.role.rawValue)") }
            return
        }

        let existing = (try? String(contentsOf: target, encoding: .utf8)) ?? ""
        let known = existingAliasHeadings(in: existing)
        let fresh = unique.filter { !known.contains(Rulebook.normalizeHeading($0.heading)) }
        guard !fresh.isEmpty else { return }

        let newLines = fresh.map { "section \"\($0.heading)\" -> \($0.role.rawValue)" }
        let updated = insertSectionLines(newLines, into: existing)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try updated.write(to: target, atomically: true, encoding: .utf8)
        print("✓ \(fresh.count) section alias(es) → \(target.lastPathComponent)")
    }

    /// De-duplicate by normalized heading (first role wins).
    private func dedupeAliases(_ aliases: [SkillMigrator.SectionAlias]) -> [SkillMigrator.SectionAlias] {
        var seen = Set<String>()
        var out: [SkillMigrator.SectionAlias] = []
        for a in aliases where seen.insert(Rulebook.normalizeHeading(a.heading)).inserted {
            out.append(a)
        }
        return out
    }

    /// Normalized headings already aliased by any `section "…" -> role` line.
    private func existingAliasHeadings(in source: String) -> Set<String> {
        var out: Set<String> = []
        for raw in source.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("section ") else { continue }
            var rest = Substring(t)
            while let open = rest.firstIndex(of: "\"") {
                let afterOpen = rest.index(after: open)
                guard let close = rest[afterOpen...].firstIndex(of: "\"") else { break }
                out.insert(Rulebook.normalizeHeading(String(rest[afterOpen..<close])))
                rest = rest[rest.index(after: close)...]
            }
        }
        return out
    }

    /// Insert `section …` lines under an existing `=== sections ===` header, or
    /// append a fresh block when none exists.
    private func insertSectionLines(_ lines: [String], into source: String) -> String {
        var fileLines = source.isEmpty ? [] : source.components(separatedBy: "\n")
        if let headerIdx = fileLines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "=== sections ==="
        }) {
            fileLines.insert(contentsOf: lines, at: headerIdx + 1)
            return fileLines.joined(separator: "\n")
        }
        var text = source
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        if !text.isEmpty { text += "\n" }
        text += "=== sections ===\n" + lines.joined(separator: "\n") + "\n"
        return text
    }

    private func autodiscover(extension ext: String, from dir: URL) -> [URL] {
        let fm = FileManager.default
        for candidate in [dir, dir.deletingLastPathComponent(), dir.deletingLastPathComponent().deletingLastPathComponent()] {
            let files = (try? fm.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil)) ?? []
            let matches = files.filter { $0.pathExtension == ext }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            if !matches.isEmpty { return matches }
        }
        return []
    }

    private func discoverSkillFiles(in dir: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent.uppercased() == "SKILL.MD" {
            result.append(url)
        }
        return result
    }

    // MARK: - Output helpers

    private func writeMeri(_ source: String, to url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path), !force {
            throw ValidationError("Refusing to overwrite \(url.path) (pass --force).")
        }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try source.write(to: url, atomically: true, encoding: .utf8)
    }

    /// A SKILL.md typically lives in a `<skill-name>/SKILL.md` directory; use the
    /// parent directory name as the .meri stem when the file itself is SKILL.md.
    private func meriStem(forSkillAt url: URL) -> String {
        SkillDeviation.meriStem(forSkillAt: url)
    }

    private func slug(_ name: String) -> String {
        SkillDeviation.slug(name)
    }

    // MARK: - Reports

    private func singleReport(stem: String, result: SkillMigrator.Result) -> String {
        let r = result.report
        var lines = [
            "skill: \(stem)",
            "compiles: \(r.compiledOK)",
            "added frontmatter keys: \(r.addedFrontmatterKeys.joined(separator: ", "))",
            "repair attempts: \(r.repairAttempts)",
            "edit count: \(r.editCount)",
            "lines: \(r.originalLineCount) → \(r.resultLineCount)"
        ]
        if !r.diagnostics.isEmpty {
            lines.append("diagnostics:")
            lines.append(contentsOf: r.diagnostics.map { "  - \($0)" })
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func coverageMatrix(rows: [(stem: String, result: SkillMigrator.Result)]) -> String {
        var out = ["| skill | compiles | edits | repairs | added keys |",
                   "|---|---|---|---|---|"]
        for row in rows {
            let r = row.result.report
            out.append("| \(row.stem) | \(r.compiledOK ? "✓" : "✗") | \(r.editCount) | \(r.repairAttempts) | \(r.addedFrontmatterKeys.joined(separator: " ")) |")
        }
        let ok = rows.filter { $0.result.compiledOK }.count
        out.append("")
        out.append("Total: \(rows.count), compiling: \(ok), failing: \(rows.count - ok)")
        return out.joined(separator: "\n") + "\n"
    }
}
