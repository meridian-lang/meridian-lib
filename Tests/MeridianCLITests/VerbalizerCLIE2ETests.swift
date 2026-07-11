import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore

private let repoRoot = FileManager.default.currentDirectoryPath

/// Process-level end-to-end checks against the built `meridian` binary
/// (`explain` / `drift` / `grammar-doc` / `explain-diag` / `compile`).
@Suite("CLI verbalizer end-to-end (process)")
struct VerbalizerCLIE2ETests {

    @Test("meridian explain/drift/compile fixpoint on order_processing")
    func orderProcessingBinaryPipeline() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/examples/order_processing.meridian"
        let cfg = "\(repoRoot)/examples/ecommerce.merconfig"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try runMeridian(bin, ["explain", mer, "--merconfig", cfg])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To process a order placed by a customer:"))
        #expect(explain.stdout.contains("invoke validateOrder"))
        #expect(!explain.stdout.contains("# assertion message:"))

        let canonicalURL = tmp.appendingPathComponent("canonical.meri")
        try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let driftAuthored = try runMeridian(bin, ["drift", mer, "--merconfig", cfg, "--json"])
        #expect(driftAuthored.exitCode == 0, Comment(rawValue: driftAuthored.stderr))
        let authoredReport = try decodeDriftJSON(driftAuthored.stdout)
        #expect(authoredReport.total > 0)
        #expect((authoredReport.counts["synonymCanonicalized"] ?? 0) > 0)

        // Re-explain once so any residual non-fixpoint surface is folded away,
        // then require zero drift and a byte-identical second explain.
        let explainFolded = try runMeridian(bin, ["explain", canonicalURL.path, "--merconfig", cfg])
        #expect(explainFolded.exitCode == 0, Comment(rawValue: explainFolded.stderr))
        try explainFolded.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let driftCanonical = try runMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--json"
        ])
        #expect(driftCanonical.exitCode == 0, Comment(rawValue: driftCanonical.stderr))
        let canonicalReport = try decodeDriftJSON(driftCanonical.stdout)
        #expect(canonicalReport.total == 0, Comment(rawValue: driftCanonical.stdout))

        let explain2 = try runMeridian(bin, ["explain", canonicalURL.path, "--merconfig", cfg])
        #expect(explain2.exitCode == 0, Comment(rawValue: explain2.stderr))
        #expect(explain2.stdout == explainFolded.stdout)

        let outDir = tmp.appendingPathComponent("out", isDirectory: true)
        let compile = try runMeridian(bin, [
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
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/examples/order_processing.meridian"
        let cfg = "\(repoRoot)/examples/ecommerce.merconfig"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-explain-trace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let traceURL = tmp.appendingPathComponent("trace.log")

        let explain = try runMeridian(bin, [
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
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/examples/order_processing.meridian"
        let cfg = "\(repoRoot)/examples/ecommerce.merconfig"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-drift-trace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let traceURL = tmp.appendingPathComponent("trace.log")

        let drift = try runMeridian(bin, [
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
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/examples/order_processing.meridian"
        let cfg = "\(repoRoot)/examples/ecommerce.merconfig"

        let explain = try runMeridian(bin, [
            "explain", mer,
            "--merconfig", cfg,
            "--trace", "not-a-real-category",
        ])
        #expect(explain.exitCode == 1, Comment(rawValue: explain.stderr))
        #expect(explain.stderr.contains("MER2010"), Comment(rawValue: explain.stderr))
    }

    @Test("meridian explain/drift on sample-gbrain briefing with rulebook")
    func briefingBinaryPipeline() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/sample-gbrain/skills/briefing.meri"
        let cfg = "\(repoRoot)/sample-gbrain/brain.merconfig"
        let rb = "\(repoRoot)/sample-gbrain/brain.merrules"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-briefing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try runMeridian(bin, [
            "explain", mer, "--merconfig", cfg, "--rulebook", rb
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To briefing"))

        let canonicalURL = tmp.appendingPathComponent("briefing.canonical.meri")
        try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

        let drift = try runMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        let report = try decodeDriftJSON(drift.stdout)
        #expect(report.total == 0, Comment(rawValue: drift.stdout))
    }

    @Test("meridian grammar-doc and explain-diag stay wired")
    func grammarDocAndExplainDiag() throws {
        let bin = try locateMeridianBinary()

        let grammar = try runMeridian(bin, ["grammar-doc"])
        #expect(grammar.exitCode == 0, Comment(rawValue: grammar.stderr))
        #expect(grammar.stdout.contains("# Meridian Grammar Reference"))
        #expect(grammar.stdout.contains("| `comparison` |"))
        #expect(grammar.stdout.contains("| `quantifier` |"))

        let diag = try runMeridian(bin, ["explain-diag", "MER2001"])
        #expect(diag.exitCode == 0, Comment(rawValue: diag.stderr))
        #expect(diag.stdout.contains("MER2001"))
        #expect(diag.stdout.contains("unresolved phrase"))

        let matchDiag = try runMeridian(bin, ["explain-diag", "MER1012"])
        #expect(matchDiag.exitCode == 0, Comment(rawValue: matchDiag.stderr))
        #expect(matchDiag.stdout.contains("MER1012"))
        #expect(matchDiag.stdout.contains("Worked examples"))
        #expect(matchDiag.stdout.contains("before:"))
        #expect(matchDiag.stdout.contains("after:"))
    }

    @Test("meridian explain/drift on erp placeorder with rulebook")
    func placeorderBinaryPipeline() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/corpora/erp/skills/placeorder.meri"
        let cfg = "\(repoRoot)/corpora/erp/erp.merconfig"
        let rb = "\(repoRoot)/corpora/erp/erp.merrules"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-verbalizer-placeorder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let explain = try runMeridian(bin, [
            "explain", mer, "--merconfig", cfg, "--rulebook", rb
        ])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("To place order"))
        #expect(explain.stdout.contains("invoke order.list"))

        let authoredDrift = try runMeridian(bin, [
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
        let drift = try runMeridian(bin, [
            "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        let report = try decodeDriftJSON(drift.stdout)
        assertDriftJSONSchema(report)
        #expect(report.total == 0, Comment(rawValue: drift.stdout))
    }

    @Test("meridian explain on incident triagealert shows judgment")
    func triagealertBinaryPipeline() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(repoRoot)/corpora/incident/skills/triagealert.meri"
        let cfg = "\(repoRoot)/corpora/incident/incident.merconfig"
        let rb = "\(repoRoot)/corpora/incident/incident.merrules"

        let explain = try runMeridian(bin, [
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
            mer: "\(repoRoot)/sample-gbrain/skills/capture.meri",
            cfg: "\(repoRoot)/sample-gbrain/brain.merconfig",
            rb: "\(repoRoot)/sample-gbrain/brain.merrules",
            mustContain: "To capture"
        )
    }

    @Test("meridian explain/drift fixpoint on incident triagealert")
    func triagealertBinaryDriftZero() throws {
        try assertExplainDriftZero(
            mer: "\(repoRoot)/corpora/incident/skills/triagealert.meri",
            cfg: "\(repoRoot)/corpora/incident/incident.merconfig",
            rb: "\(repoRoot)/corpora/incident/incident.merrules",
            mustContain: "use judgment to"
        )
    }
}

// MARK: - helpers

private struct DriftJSONReport: Decodable {
    var file: String
    var total: Int
    var counts: [String: Int]
}

private struct ProcessResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

private func locateMeridianBinary() throws -> URL {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["swift", "build", "--product", "meridian", "--show-bin-path"]
    proc.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    try proc.run()
    proc.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let binPath = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    #expect(proc.terminationStatus == 0, Comment(rawValue: "swift build --show-bin-path failed: \(binPath)"))
    let url = URL(fileURLWithPath: binPath).appendingPathComponent("meridian")
    #expect(FileManager.default.isExecutableFile(atPath: url.path),
            Comment(rawValue: "missing meridian binary at \(url.path)"))
    return url
}

private func runMeridian(_ bin: URL, _ args: [String]) throws -> ProcessResult {
    let proc = Process()
    proc.executableURL = bin
    proc.arguments = args
    proc.currentDirectoryURL = URL(fileURLWithPath: repoRoot)
    let out = Pipe()
    let err = Pipe()
    proc.standardOutput = out
    proc.standardError = err
    try proc.run()
    proc.waitUntilExit()
    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ProcessResult(exitCode: proc.terminationStatus, stdout: stdout, stderr: stderr)
}

private func decodeDriftJSON(_ text: String) throws -> DriftJSONReport {
    let data = Data(text.utf8)
    return try JSONDecoder().decode(DriftJSONReport.self, from: data)
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
    let bin = try locateMeridianBinary()
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("meridian-verbalizer-drift-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let explain = try runMeridian(bin, [
        "explain", mer, "--merconfig", cfg, "--rulebook", rb
    ])
    #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
    #expect(explain.stdout.contains(mustContain), Comment(rawValue: explain.stdout))

    let canonicalURL = tmp.appendingPathComponent("canonical.meri")
    try explain.stdout.write(to: canonicalURL, atomically: true, encoding: .utf8)

    let drift = try runMeridian(bin, [
        "drift", canonicalURL.path, "--merconfig", cfg, "--rulebook", rb, "--json"
    ])
    #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
    let report = try decodeDriftJSON(drift.stdout)
    assertDriftJSONSchema(report)
    #expect(report.total == 0, Comment(rawValue: drift.stdout))
}
