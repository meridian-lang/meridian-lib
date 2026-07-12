import Foundation
import Testing
import MeridianTestKit

@Suite("CLI verbalizer end-to-end (process)")
struct VerbalizerCLIE2ESlowTests {

    @Test("meridian explain/drift/compile fixpoint on order_processing")
    func orderProcessingBinaryPipeline() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("examples/order_processing.meridian").path
        let cfg = slowRepoRoot.appendingPathComponent("examples/ecommerce.merconfig").path
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try slowRunMeridian(bin, ["explain", mer, "--merconfig", cfg])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To process a order placed by a customer:"))
        #expect(explain.stdout.contains("invoke validateOrder"))
        #expect(!explain.stdout.contains("# assertion message:"))

        let canonicalURL = tmp.appendingPathComponent("canonical.meri")
        try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let driftAuthored = try slowRunMeridian(bin, ["drift", mer, "--merconfig", cfg, "--json"])
        #expect(driftAuthored.exitCode == 0, Comment(rawValue: driftAuthored.stderr))
        let authoredReport = try decodeDriftJSON(driftAuthored.stdout)
        #expect(authoredReport.total > 0)
        #expect((authoredReport.counts["synonymCanonicalized"] ?? 0) > 0)

        let explainFolded = try slowRunMeridian(bin, ["explain", canonicalURL.path, "--merconfig", cfg])
        #expect(explainFolded.exitCode == 0, Comment(rawValue: explainFolded.stderr))
        try explainFolded.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let driftCanonical = try slowRunMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--json"
        ])
        #expect(driftCanonical.exitCode == 0, Comment(rawValue: driftCanonical.stderr))
        let canonicalReport = try decodeDriftJSON(driftCanonical.stdout)
        #expect(canonicalReport.total == 0, Comment(rawValue: driftCanonical.stdout))

        let explain2 = try slowRunMeridian(bin, ["explain", canonicalURL.path, "--merconfig", cfg])
        #expect(explain2.exitCode == 0, Comment(rawValue: explain2.stderr))
        #expect(explain2.stdout == explainFolded.stdout)

        let outDir = tmp.appendingPathComponent("out", isDirectory: true)
        let compile = try slowRunMeridian(bin, [
            "compile", canonicalURL.path,
            "--merconfig", cfg,
            "--output", outDir.path,
            "--no-format",
            "--namespace", "none",
        ])
        #expect(compile.exitCode == 0, Comment(rawValue: compile.stderr + compile.stdout))
        let emitted = try FileManager.default.contentsOfDirectory(at: outDir, includingPropertiesForKeys: nil)
        #expect(emitted.contains { $0.pathExtension == "swift" })
    }

    @Test("meridian explain --trace verbalizer writes process trace")
    func explainTraceFile() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("examples/order_processing.meridian").path
        let cfg = slowRepoRoot.appendingPathComponent("examples/ecommerce.merconfig").path
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-explain-trace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let traceURL = tmp.appendingPathComponent("trace.log")

        let explain = try slowRunMeridian(bin, [
            "explain", mer,
            "--merconfig", cfg,
            "--trace", "verbalizer",
            "--trace-file", traceURL.path,
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To process a order placed by a customer:"),
                Comment(rawValue: explain.stdout))
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        #expect(trace.contains("[verbalizer]"), Comment(rawValue: trace))
    }

    @Test("meridian drift --trace verbalizer,drift writes process trace")
    func driftTraceFile() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("examples/order_processing.meridian").path
        let cfg = slowRepoRoot.appendingPathComponent("examples/ecommerce.merconfig").path
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-drift-trace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let traceURL = tmp.appendingPathComponent("trace.log")

        let drift = try slowRunMeridian(bin, [
            "drift", mer,
            "--merconfig", cfg,
            "--trace", "verbalizer,drift",
            "--trace-file", traceURL.path,
            "--json",
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        _ = try decodeDriftJSON(drift.stdout)
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        #expect(trace.contains("[verbalizer]") || trace.contains("[drift]"),
                Comment(rawValue: trace))
    }

    @Test("meridian explain rejects unknown trace category")
    func explainUnknownTraceCategory() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("examples/order_processing.meridian").path
        let cfg = slowRepoRoot.appendingPathComponent("examples/ecommerce.merconfig").path

        let explain = try slowRunMeridian(bin, [
            "explain", mer,
            "--merconfig", cfg,
            "--trace", "not-a-real-category",
        ])
        #expect(explain.exitCode == 1, Comment(rawValue: explain.stderr))
        #expect(explain.stderr.contains("MER2010"), Comment(rawValue: explain.stderr))
    }

    @Test("meridian explain/drift on sample-gbrain briefing with rulebook")
    func briefingBinaryPipeline() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("sample-gbrain/skills/briefing.meri").path
        let cfg = slowRepoRoot.appendingPathComponent("sample-gbrain/brain.merconfig").path
        let rb = slowRepoRoot.appendingPathComponent("sample-gbrain/brain.merrules").path
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-briefing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try slowRunMeridian(bin, [
            "explain", mer, "--merconfig", cfg, "--rulebook", rb
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To briefing"))

        let canonicalURL = tmp.appendingPathComponent("briefing.canonical.meri")
        try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let drift = try slowRunMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        let report = try decodeDriftJSON(drift.stdout)
        #expect(report.total == 0, Comment(rawValue: drift.stdout))
    }

    @Test("meridian grammar-doc and explain-diag stay wired")
    func grammarDocAndExplainDiag() throws {
        let bin = try slowLocateMeridianBinary()

        let grammar = try slowRunMeridian(bin, ["grammar-doc"])
        #expect(grammar.exitCode == 0, Comment(rawValue: grammar.stderr))
        #expect(grammar.stdout.contains("# Meridian Grammar Reference"))
        #expect(grammar.stdout.contains("| `comparison` |"))
        #expect(grammar.stdout.contains("| `quantifier` |"))

        let diag = try slowRunMeridian(bin, ["explain-diag", "MER2001"])
        #expect(diag.exitCode == 0, Comment(rawValue: diag.stderr))
        #expect(diag.stdout.contains("MER2001"))
        #expect(diag.stdout.contains("unresolved phrase"))

        let matchDiag = try slowRunMeridian(bin, ["explain-diag", "MER1012"])
        #expect(matchDiag.exitCode == 0, Comment(rawValue: matchDiag.stderr))
        #expect(matchDiag.stdout.contains("MER1012"))
        #expect(matchDiag.stdout.contains("Worked examples"))
        #expect(matchDiag.stdout.contains("before:"))
        #expect(matchDiag.stdout.contains("after:"))
    }

    @Test("meridian explain/drift on erp placeorder with rulebook")
    func placeorderBinaryPipeline() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("corpora/erp/skills/placeorder.meri").path
        let cfg = slowRepoRoot.appendingPathComponent("corpora/erp/erp.merconfig").path
        let rb = slowRepoRoot.appendingPathComponent("corpora/erp/erp.merrules").path
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-placeorder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try slowRunMeridian(bin, [
            "explain", mer, "--merconfig", cfg, "--rulebook", rb
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To place order"))
        #expect(explain.stdout.contains("invoke order.list"))

        let authoredDrift = try slowRunMeridian(bin, [
            "drift", mer, "--merconfig", cfg, "--rulebook", rb, "--json"
        ])
        #expect(authoredDrift.exitCode == 0, Comment(rawValue: authoredDrift.stderr))
        let authoredReport = try decodeDriftJSON(authoredDrift.stdout)
        assertDriftJSONSchema(authoredReport)
        #expect(authoredReport.total > 0)
        #expect((authoredReport.counts["meaningBearing"] ?? 0) > 0
                || (authoredReport.counts["synonymCanonicalized"] ?? 0) > 0)

        let canonicalURL = tmp.appendingPathComponent("placeorder.canonical.meri")
        try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)
        let drift = try slowRunMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        let report = try decodeDriftJSON(drift.stdout)
        assertDriftJSONSchema(report)
        #expect(report.total == 0, Comment(rawValue: drift.stdout))
    }

    @Test("meridian explain on incident triagealert shows judgment")
    func triagealertBinaryPipeline() throws {
        let bin = try slowLocateMeridianBinary()
        let mer = slowRepoRoot.appendingPathComponent("corpora/incident/skills/triagealert.meri").path
        let cfg = slowRepoRoot.appendingPathComponent("corpora/incident/incident.merconfig").path
        let rb = slowRepoRoot.appendingPathComponent("corpora/incident/incident.merrules").path

        let explain = try slowRunMeridian(bin, [
            "explain", mer, "--merconfig", cfg, "--rulebook", rb
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("use judgment to"), Comment(rawValue: explain.stdout))
        #expect(explain.stdout.contains("wait for signal")
                || explain.stdout.contains("wait for event"),
                Comment(rawValue: explain.stdout))
    }

    @Test("meridian explain/drift fixpoint on sample-gbrain capture")
    func captureBinaryDriftZero() throws {
        try assertExplainDriftZero(
            mer: slowRepoRoot.appendingPathComponent("sample-gbrain/skills/capture.meri").path,
            cfg: slowRepoRoot.appendingPathComponent("sample-gbrain/brain.merconfig").path,
            rb: slowRepoRoot.appendingPathComponent("sample-gbrain/brain.merrules").path,
            mustContain: "To capture"
        )
    }

    @Test("meridian explain/drift fixpoint on incident triagealert")
    func triagealertBinaryDriftZero() throws {
        try assertExplainDriftZero(
            mer: slowRepoRoot.appendingPathComponent("corpora/incident/skills/triagealert.meri").path,
            cfg: slowRepoRoot.appendingPathComponent("corpora/incident/incident.merconfig").path,
            rb: slowRepoRoot.appendingPathComponent("corpora/incident/incident.merrules").path,
            mustContain: "use judgment to"
        )
    }
}

private struct DriftJSONReport: Decodable {
    var file: String
    var total: Int
    var counts: [String: Int]
}

private func decodeDriftJSON(_ text: String) throws -> DriftJSONReport {
    try JSONDecoder().decode(DriftJSONReport.self, from: Data(text.utf8))
}

private func assertDriftJSONSchema(_ report: DriftJSONReport) {
    #expect(!report.file.isEmpty)
    for key in ["synonymCanonicalized", "structureNormalized", "desugarExpanded", "meaningBearing"] {
        #expect(report.counts[key] != nil, Comment(rawValue: "missing counts.\(key)"))
    }
    #expect(report.total == report.counts.values.reduce(0, +))
}

private func assertExplainDriftZero(
    mer: String,
    cfg: String,
    rb: String,
    mustContain: String
) throws {
    let bin = try slowLocateMeridianBinary()
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("meridian-verbalizer-drift-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let explain = try slowRunMeridian(bin, [
        "explain", mer, "--merconfig", cfg, "--rulebook", rb
    ])
    #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
    #expect(explain.stdout.contains(mustContain), Comment(rawValue: explain.stdout))

    let canonicalURL = tmp.appendingPathComponent("canonical.meri")
    try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

    let drift = try slowRunMeridian(bin, [
        "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
    ])
    #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
    let report = try decodeDriftJSON(drift.stdout)
    assertDriftJSONSchema(report)
    #expect(report.total == 0, Comment(rawValue: drift.stdout))
}
