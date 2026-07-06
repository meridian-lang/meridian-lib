import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore

@Suite("CLI command — inert-yield")
struct InertYieldCommandTests {
    private let inertProcedure = """
    ## Steps (( inert, role: procedure ))
    complete.
    """

    @Test("single-file mode writes a report and autodiscovers dependencies")
    func singleFileOutAutodiscoversDependencies() async throws {
        let t = TempDir()
        t.write("vocab.merconfig", "=== vocabulary ===\n")
        t.write("rules.merrules", "=== sections ===\n")
        let source = t.write("skill.meri", inertProcedure)
        let out = t.path("report.md")

        let cmd = try InertYieldCommand.parse([source.path, "--out", out])
        try await cmd.run()

        let report = try String(contentsOfFile: out, encoding: .utf8)
        #expect(report.contains("# Inert-yield report"), Comment(rawValue: report))
        #expect(report.contains("## skill"), Comment(rawValue: report))
        #expect(report.contains("`Steps`"), Comment(rawValue: report))
    }

    @Test("batch summary-only report omits per-line details but keeps every file")
    func batchSummaryOnlyOut() async throws {
        let t = TempDir()
        t.write("a.meri", inertProcedure)
        t.write("nested/b.meri", inertProcedure)
        t.write("nested/ignore.txt", inertProcedure)
        let out = t.path("summary.md")

        let cmd = try InertYieldCommand.parse([t.url.path, "--batch", "--summary-only", "--out", out])
        try await cmd.run()

        let report = try String(contentsOfFile: out, encoding: .utf8)
        #expect(report.contains("## a"), Comment(rawValue: report))
        #expect(report.contains("## b"), Comment(rawValue: report))
        #expect(!report.contains("  - L"), Comment(rawValue: report))
    }

    @Test("rendered summary ranks repeated unresolved operational phrases")
    func summaryRanksNeedsPhraseWorklist() {
        let sections = [
            InertYieldAnalyzer.SectionYield(
                heading: "Steps",
                line: 1,
                overall: .needsPhrase,
                category: .operationalProcedure,
                lines: [
                    .init(line: 2, text: "frobnicate the page", yield: .needsPhrase,
                          unresolvedPhrase: "frobnicate the page", p1Bucket: .error),
                    .init(line: 3, text: "frobnicate the page", yield: .needsPhrase,
                          unresolvedPhrase: "frobnicate the page", p1Bucket: .error),
                    .init(line: 4, text: "reticulate splines", yield: .needsPhrase,
                          unresolvedPhrase: "reticulate splines", p1Bucket: .reference),
                ]),
            InertYieldAnalyzer.SectionYield(
                heading: "Template",
                line: 10,
                overall: .needsPhrase,
                category: .template,
                lines: [
                    .init(line: 11, text: "template prose", yield: .needsPhrase,
                          unresolvedPhrase: "template prose", p1Bucket: .reference),
                ]),
        ]

        let summary = InertYieldCommand.renderSummary([
            InertYieldAnalyzer.FileYield(file: "demo", sections: sections)
        ])

        #expect(summary.contains("Files analyzed: 1"), Comment(rawValue: summary))
        #expect(summary.contains("2x  frobnicate the page"), Comment(rawValue: summary))
        #expect(!summary.contains("template prose"), Comment(rawValue: summary))
        #expect(summary.contains("residual-error tail:"), Comment(rawValue: summary))
    }

    @Test("missing input and empty batch directories throw validation errors")
    func validationErrors() async throws {
        let missing = try InertYieldCommand.parse(["/definitely/missing.meri"])
        await #expect(throws: (any Error).self) { try await missing.run() }

        let t = TempDir()
        let empty = try InertYieldCommand.parse([t.url.path, "--batch"])
        await #expect(throws: (any Error).self) { try await empty.run() }
    }
}
