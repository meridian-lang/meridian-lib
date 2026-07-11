import Foundation
import Testing

private let repoRoot = FileManager.default.currentDirectoryPath
private let dxRoot = "\(repoRoot)/examples/dx"
private let dxVocab = "\(dxRoot)/dx.merconfig"
private let dxFixtures = "\(dxRoot)/fixtures"

/// Process-level regression tests for `examples/dx/fixtures/*.meridian`.
/// These are the committed counterparts of the ad-hoc CLI sessions used to
/// validate DX tracing and structured diagnostics end-to-end.
@Suite("DX example fixtures (process)")
struct DXCorpusFixtureTests {

    @Test("match_branch_valid compiles and round-trips through explain/drift/trace")
    func validMatchBranchPipeline() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/match_branch_valid.meridian"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-dx-valid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let compile = try runMeridian(bin, [
            "compile", mer,
            "--merconfig", dxVocab,
            "--output", tmp.path,
            "--no-format",
            "--namespace", "none",
        ])
        #expect(compile.exitCode == 0, Comment(rawValue: compile.stderr + compile.stdout))

        let explain = try runMeridian(bin, ["explain", mer, "--merconfig", dxVocab])
        #expect(explain.exitCode == 0, Comment(rawValue: explain.stderr))
        #expect(explain.stdout.contains("branch on the order's status:"))

        let traceURL = tmp.appendingPathComponent("trace.log")
        let drift = try runMeridian(bin, [
            "drift", mer,
            "--merconfig", dxVocab,
            "--trace", "verbalizer,drift",
            "--trace-file", traceURL.path,
            "--json",
        ])
        #expect(drift.exitCode == 0, Comment(rawValue: drift.stderr))
        let trace = try String(contentsOf: traceURL, encoding: .utf8)
        #expect(trace.contains("[verbalizer]") || trace.contains("[drift]"),
                Comment(rawValue: trace))
    }

    @Test("match_branch_missing_colon surfaces MER1012")
    func matchBranchMissingColon() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/match_branch_missing_colon.meridian"

        let compile = try runMeridian(bin, [
            "compile", mer,
            "--merconfig", dxVocab,
            "--namespace", "none",
        ])
        #expect(compile.exitCode == 1, Comment(rawValue: compile.stdout))
        #expect(compile.stderr.contains("MER1012"), Comment(rawValue: compile.stderr))
        #expect(compile.stderr.contains("missing a trailing ':'"),
                Comment(rawValue: compile.stderr))
    }

    @Test("match_branch_duplicate_wildcard surfaces MER3018")
    func matchBranchDuplicateWildcard() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/match_branch_duplicate_wildcard.meridian"

        let compile = try runMeridian(bin, [
            "compile", mer,
            "--merconfig", dxVocab,
            "--namespace", "none",
        ])
        #expect(compile.exitCode == 1, Comment(rawValue: compile.stdout))
        #expect(compile.stderr.contains("MER3018"), Comment(rawValue: compile.stderr))
    }

    @Test("lint_polite_uncertainty surfaces MER6001 and MER6002")
    func lintPoliteAndUncertainty() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/lint_polite_uncertainty.meridian"

        let lint = try runMeridian(bin, ["lint", mer])
        #expect(lint.exitCode == 0, Comment(rawValue: lint.stderr))
        #expect(lint.stderr.contains("MER6001"), Comment(rawValue: lint.stderr))
        #expect(lint.stderr.contains("MER6002"), Comment(rawValue: lint.stderr))
        #expect(lint.stderr.contains("D-DX-7"), Comment(rawValue: lint.stderr))
    }

    @Test("recovery_multi_error surfaces MER2001 and MER6004 recovery summary")
    func recoveryMultiError() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/recovery_multi_error.meridian"

        let compile = try runMeridian(bin, [
            "compile", mer,
            "--merconfig", dxVocab,
            "--namespace", "none",
        ])
        #expect(compile.exitCode == 1, Comment(rawValue: compile.stdout))
        #expect(compile.stderr.contains("MER2001"), Comment(rawValue: compile.stderr))
        #expect(compile.stderr.contains("MER6004"), Comment(rawValue: compile.stderr))
        #expect(compile.stderr.contains("skipped workflow"),
                Comment(rawValue: compile.stderr))
    }

    @Test("unknown trace category on dx fixture surfaces MER2010 with pluralized hint")
    func unknownTraceCategory() throws {
        let bin = try locateMeridianBinary()
        let mer = "\(dxFixtures)/match_branch_valid.meridian"

        let explain = try runMeridian(bin, [
            "explain", mer,
            "--merconfig", dxVocab,
            "--trace", "not-a-real-category",
        ])
        #expect(explain.exitCode == 1, Comment(rawValue: explain.stderr))
        #expect(explain.stderr.contains("MER2010"), Comment(rawValue: explain.stderr))
        #expect(explain.stderr.contains("closest trace categories"),
                Comment(rawValue: explain.stderr))
        #expect(!explain.stderr.contains("categorys"), Comment(rawValue: explain.stderr))
    }
}

// MARK: - helpers

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
