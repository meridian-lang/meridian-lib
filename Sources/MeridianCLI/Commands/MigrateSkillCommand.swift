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

        if batch {
            try await runBatch(inputURL: inputURL, migrator: migrator)
        } else {
            try await runSingle(inputURL: inputURL, migrator: migrator)
        }
    }

    // MARK: - Single + batch drivers

    private func runSingle(inputURL: URL, migrator: SkillMigrator) async throws {
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

        if let report {
            let text = singleReport(stem: stem, result: result)
            try text.write(to: URL(fileURLWithPath: report).standardized, atomically: true, encoding: .utf8)
        }

        if !result.compiledOK {
            throw ExitCode(1)
        }
    }

    private func runBatch(inputURL: URL, migrator: SkillMigrator) async throws {
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
        for file in skillFiles {
            let markdown = try String(contentsOf: file, encoding: .utf8)
            let stem = meriStem(forSkillAt: file)
            let result = try await migrator.migrate(markdown, file: "\(stem).meri")
            rows.append((stem, result))
            if !result.compiledOK { failures += 1 }
            if let outDir {
                try writeMeri(result.meriSource, to: outDir.appendingPathComponent("\(stem).meri"))
            }
            print("\(result.compiledOK ? "✓" : "✗") \(stem)  edits=\(result.report.editCount) repairs=\(result.report.repairAttempts)")
        }

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
