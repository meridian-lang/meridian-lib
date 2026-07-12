import ArgumentParser
import Foundation
import MeridianCore

/// Phase 0 measurement-spike CLI surface for `InertYieldAnalyzer`. Read-only:
/// it never rewrites the input `.meri`/SKILL.md, only reports what the
/// trial-lowering oracle found. See docs/13_SKILL_MD_PORTING.md and the
/// "Deterministic lowering for gbrain" plan for context.
public struct InertYieldCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "inert-yield",
        abstract: "Measure how many inert sections would lower today with real vocabulary/rulebook knowledge (Phase 0 spike)."
    )

    @Argument(help: "A .meri file, or a directory of them with --batch.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable. Autodiscovered beside the input when omitted.")
    var vocab: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules file. Repeatable. Autodiscovered beside the input when omitted.")
    var rulebook: [String] = []

    @Flag(name: .long, help: "Treat the input as a directory and analyze every .meri within.")
    var batch: Bool = false

    @Option(name: .shortAndLong, help: "Write the full per-line report (Markdown) to this path.")
    var out: String?

    @Flag(name: .long, help: "Print only the corpus-wide summary and the ranked needs-phrase worklist.")
    var summaryOnly: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        let inputURL = URL(fileURLWithPath: input).standardized
        let fm = FileManager.default
        guard fm.fileExists(atPath: inputURL.path) else {
            throw cliInputNotFound(input)
        }

        let depsDir = batch ? inputURL : inputURL.deletingLastPathComponent()
        let (vocabularies, rulebooks) = try loadDependencies(beside: depsDir)
        let traceInstance = try cliTrace.makeTrace()
        let analyzer = InertYieldAnalyzer(
            compiler: Compiler(options: .init(trace: traceInstance)),
            vocabularies: vocabularies, rulebooks: rulebooks)

        let files = batch ? try discoverMeriFiles(in: inputURL) : [inputURL]
        guard !files.isEmpty else {
            throw ValidationError("No .meri files found under \(inputURL.path)")
        }

        var results: [InertYieldAnalyzer.FileYield] = []
        for file in files.sorted(by: { $0.path < $1.path }) {
            let source = try String(contentsOf: file, encoding: .utf8)
            let stem = file.deletingPathExtension().lastPathComponent
            results.append(try analyzer.analyze(source, file: stem))
        }

        let report = Self.renderReport(results, includeLineDetail: !summaryOnly)
        if let out {
            try report.write(to: URL(fileURLWithPath: out).standardized, atomically: true, encoding: .utf8)
            print("✓ inert-yield report → \(out)")
        } else {
            print(report)
        }
        print(Self.renderSummary(results))
    }

    // MARK: - Discovery + deps (mirrors MigrateSkillCommand)

    private func discoverMeriFiles(in dir: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "meri" {
            result.append(url)
        }
        return result
    }

    private func loadDependencies(beside dir: URL) throws
        -> (vocab: [Compiler.VocabularyInput], rulebooks: [RulebookInput]) {
        let vocabURLs = vocab.isEmpty
            ? try autodiscover(extension: "merconfig", from: dir)
            : try vocab.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw cliInputNotFound(path, label: "merconfig")
                }
                return url
            }
        let rulebookURLs = rulebook.isEmpty
            ? try autodiscover(extension: "merrules", from: dir)
            : try rulebook.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw cliInputNotFound(path, label: "rulebook")
                }
                return url
            }

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

    private func autodiscover(extension ext: String, from dir: URL) throws -> [URL] {
        try autodiscoverFiles(extension: ext, from: dir, parentLevels: 2)
    }

    // MARK: - Rendering

    static func renderReport(_ results: [InertYieldAnalyzer.FileYield], includeLineDetail: Bool) -> String {
        var out: [String] = ["# Inert-yield report", ""]
        for fileYield in results {
            guard !fileYield.sections.isEmpty else { continue }
            out.append("## \(fileYield.file)")
            out.append("")
            for section in fileYield.sections {
                let opNote = section.category.isOperational ? "" : " (non-operational: \(section.category.rawValue))"
                out.append("- L\(section.line) `\(section.heading)`: **\(section.overall.rawValue)**\(opNote)")
                if includeLineDetail {
                    for line in section.lines where line.yield != .lowersAsIs {
                        let phraseNote = line.unresolvedPhrase.map { " → unresolved phrase: \"\($0)\"" } ?? ""
                        out.append("  - L\(line.line) [\(line.yield.rawValue)] \(line.text)\(phraseNote)")
                    }
                }
            }
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    static func renderSummary(_ results: [InertYieldAnalyzer.FileYield]) -> String {
        let allSections = results.flatMap(\.sections)
        let operational = allSections.filter { $0.category.isOperational }
        let nonOperational = allSections.filter { !$0.category.isOperational }

        func breakdown(_ sections: [InertYieldAnalyzer.SectionYield]) -> [String] {
            var counts: [InertYieldAnalyzer.Yield: Int] = [:]
            for s in sections { counts[s.overall, default: 0] += 1 }
            return InertYieldAnalyzer.Yield.allCases.map { "  \($0.rawValue): \(counts[$0, default: 0])" }
        }

        var out: [String] = []
        out.append("=== Summary ===")
        out.append("Files analyzed: \(results.count)")
        out.append("Inert sections probed: \(allSections.count) (\(operational.count) operational, \(nonOperational.count) legitimately-inert)")
        out.append("")
        out.append("-- Operational inert (the migration's real target) --")
        out.append(contentsOf: breakdown(operational))
        out.append("")
        out.append("-- Non-operational (template/tools/convention-ref/reference-doc; expected to stay inert) --")
        out.append(contentsOf: breakdown(nonOperational))

        let ranked = rankedNeedsPhrase(operational)
        if !ranked.isEmpty {
            out.append("")
            out.append("=== Needs-phrase worklist — operational sections only (ranked by frequency) ===")
            for (phrase, count) in ranked.prefix(50) {
                out.append("  \(count)x  \(phrase)")
            }
        }

        out.append("")
        out.append(renderP1Histogram(operational))
        return out.joined(separator: "\n")
    }

    /// The "Eliminate `(( inert ))`" plan §0 deliverable: a cue-gated P1
    /// bucket histogram over every currently-inert operational line, sizing
    /// the residual-error tail *before* the migrator changes to actually emit
    /// these outcomes. Non-operational sections (template/tools/convention-
    /// ref/reference-doc) are excluded — they are already correctly
    /// non-executable and contribute no signal to the P1 policy.
    static func renderP1Histogram(_ operational: [InertYieldAnalyzer.SectionYield]) -> String {
        var counts: [InertYieldAnalyzer.P1Bucket: Int] = [:]
        var lowersAsIsSections = 0
        for section in operational {
            if section.overall == .lowersAsIs {
                lowersAsIsSections += 1
                continue
            }
            for line in section.lines {
                counts[line.p1Bucket, default: 0] += 1
            }
        }
        var out: [String] = ["=== P1 bucket histogram (Phase 0 spike; operational sections only) ==="]
        out.append("  lower (whole-section lowers as-is): \(lowersAsIsSections) section(s)")
        for bucket in InertYieldAnalyzer.P1Bucket.allCases {
            out.append("  \(bucket.rawValue): \(counts[bucket, default: 0]) line(s)")
        }
        let total = counts.values.reduce(0, +)
        let errorCount = counts[.error, default: 0]
        if total > 0 {
            let pct = Double(errorCount) / Double(total) * 100
            out.append(String(format: "  residual-error tail: %d/%d line(s) (%.1f%%)", errorCount, total, pct))
        }
        return out.joined(separator: "\n")
    }

    static func rankedNeedsPhrase(_ sections: [InertYieldAnalyzer.SectionYield]) -> [(phrase: String, count: Int)] {
        var counts: [String: Int] = [:]
        for section in sections {
            for line in section.lines {
                guard let phrase = line.unresolvedPhrase else { continue }
                counts[phrase, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count || ($0.count == $1.count && $0.phrase < $1.phrase) }
    }
}
