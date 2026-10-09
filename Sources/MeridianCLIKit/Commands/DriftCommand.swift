import ArgumentParser
import Foundation
import MeridianCore

public struct DriftCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "drift",
        abstract: "Compare authored Meridian source to its canonical verbalized form."
    )

    @Argument(help: "Path to the .meridian or .meri file to audit.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. May be supplied multiple times; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules rulebook. May be supplied multiple times; auto-discovers when omitted.")
    var rulebook: [String] = []

    @Flag(name: .long, help: "Emit a stable JSON report instead of human-readable markdown.")
    var json: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        let loaded = try loadCLIModelInput(input: input, merconfig: merconfig, rulebook: rulebook)
        let traceInstance = try cliTrace.makeTrace()
        let compiler = Compiler(options: .init(trace: traceInstance))
        do {
            let model = try compiledModel(compiler, loaded)
            let canonical = try traceInstance.phase("verbalize") {
                try traceInstance.run { try Verbalizer(model: model).verbalize() }
            }
            let report = traceInstance.phase("drift") {
                traceInstance.run { DriftEngine.diff(authored: model.authoredSource, canonical: canonical) }
            }
            if json {
                try printJSON(report, file: loaded.meridianURL.lastPathComponent)
            } else {
                print(renderMarkdown(report, file: loaded.meridianURL.lastPathComponent))
            }
        } catch {
            throw reportCompilerError(error, sources: loaded.diagnosticSources)
        }
    }

    private func renderMarkdown(_ report: DriftReport, file: String) -> String {
        var out: [String] = []
        out.append("# Drift: \(file)")
        out.append("")
        out.append("## Summary")
        out.append("- Total hunks: \(report.hunks.count)")
        for category in driftCategoryOrder {
            out.append("- \(categoryLabel(category)): \(report.counts[category] ?? 0)")
        }
        if report.hunks.isEmpty {
            out.append("")
            out.append("No canonical drift detected.")
            return out.joined(separator: "\n")
        }

        for category in driftCategoryOrder {
            let hunks = report.hunks.filter { $0.category == category }
            guard !hunks.isEmpty else { continue }
            out.append("")
            out.append("## \(categoryLabel(category))")
            for (index, hunk) in hunks.enumerated() {
                out.append("### Hunk \(index + 1)")
                out.append("- Authored: \(inlineCodeOrEmpty(hunk.authored))")
                out.append("- Canonical: \(inlineCodeOrEmpty(hunk.canonical))")
            }
        }
        return out.joined(separator: "\n")
    }

    private func printJSON(_ report: DriftReport, file: String) throws {
        struct JSONHunk: Encodable {
            var category: String
            var authored: String
            var canonical: String
        }
        struct JSONReport: Encodable {
            var file: String
            var total: Int
            var counts: [String: Int]
            var hunks: [JSONHunk]
        }
        let payload = JSONReport(
            file: file,
            total: report.hunks.count,
            counts: Dictionary(uniqueKeysWithValues: driftCategoryOrder.map { ($0.rawValue, report.counts[$0] ?? 0) }),
            hunks: report.hunks.map {
                JSONHunk(category: $0.category.rawValue, authored: $0.authored, canonical: $0.canonical)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private func inlineCodeOrEmpty(_ value: String) -> String {
        let text = value.isEmpty ? "(empty)" : value
        return "`\(text.replacingOccurrences(of: "`", with: "\\`"))`"
    }
}

let driftCategoryOrder: [DriftCategory] = [
    .synonymCanonicalized,
    .structureNormalized,
    .desugarExpanded,
    .meaningBearing,
]

func categoryLabel(_ category: DriftCategory) -> String {
    switch category {
    case .synonymCanonicalized:
        return "Synonym canonicalized"
    case .structureNormalized:
        return "Structure normalized"
    case .desugarExpanded:
        return "Desugar expanded"
    case .meaningBearing:
        return "Meaning-bearing"
    }
}
