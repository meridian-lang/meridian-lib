import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore
@testable import MeridianRuntime

// The `run` and `test` CLI subcommands compile then spawn a real `swift
// build`/`swift run` through a temporary SwiftPM package (or, for `test`,
// drive a subprocess-executing spec). Moved out of MeridianCLITests into this
// dedicated slow-integration target — see Tests/README.md and the target
// comment in Package.swift.

private let repoRoot = FileManager.default.currentDirectoryPath
private func ex(_ rel: String) -> String { repoRoot + "/" + rel }

/// A throwaway directory under the system temp root, removed on `deinit`.
/// Duplicated from Tests/MeridianCLITests/CLISupportTests.swift's `TempDir`
/// because test targets cannot share source files across SwiftPM targets.
private final class TempDir {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-slow-cli-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func write(_ name: String, _ contents: String) -> URL {
        let dest = url.appendingPathComponent(name)
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? contents.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }
    func path(_ name: String) -> String { url.appendingPathComponent(name).path }
}

// MARK: - test

@Suite("CLI command — test")
struct TestSubcommandTests {
    @Test("no specs found throws ExitCode(1)")
    func noSpecs() throws {
        let t = TempDir()
        let cmd = try TestCommand.parse([t.url.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("runs a single copied spec (success or failure both exercise the body)")
    func singleSpec() throws {
        let t = TempDir()
        let spec = ex("Tests/MeridianCoreTests/MeridianTestSpecs/runtime_happy.meridian.test")
        let body = try String(contentsOfFile: spec, encoding: .utf8)
        t.write("runtime_happy.meridian.test", body)
        let cmd = try TestCommand.parse([t.url.path, "--verbose"])
        do { try cmd.run() } catch { /* ExitCode(1) if the spec fails in isolation */ }
    }

    @Test("tag filter can skip a copied spec")
    func tagFilteredSpecSkips() throws {
        let t = TempDir()
        let spec = ex("Tests/MeridianCoreTests/MeridianTestSpecs/compile_only.meridian.test")
        t.write("compile_only.meridian.test", try String(contentsOfFile: spec, encoding: .utf8))
        t.write("order_processing.meridian", try String(contentsOfFile: ex("Tests/MeridianCoreTests/MeridianTestSpecs/order_processing.meridian"), encoding: .utf8))
        t.write("ecommerce.merconfig", try String(contentsOfFile: ex("Tests/MeridianCoreTests/MeridianTestSpecs/ecommerce.merconfig"), encoding: .utf8))
        let cmd = try TestCommand.parse([t.url.path, "--tag", "does-not-match"])
        try cmd.run()
    }
}

// MARK: - run

@Suite("CLI command — run")
struct RunCommandTests {
    @Test("missing input throws before any SwiftPM work")
    func missing() async throws {
        let cmd = try RunCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("broken source surfaces compiler diagnostics and exits non-zero")
    func brokenSource() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        let cmd = try RunCommand.parse([
            bad.path, "--output", t.url.path, "--diagnostics-format", "json"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("unknown workflow name is rejected after compile")
    func unknownWorkflow() async throws {
        let t = TempDir()
        let cmd = try RunCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--workflow", "DefinitelyNotAWorkflow"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("compiles and runs a minimal workflow end-to-end")
    func minimalHappyPath() async throws {
        let t = TempDir()
        let mer = t.write("minimal.meridian", "To run:\n  complete.\n")
        let cmd = try RunCommand.parse([mer.path, "--output", t.url.path])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("minimal.swift")))
        #expect(FileManager.default.fileExists(atPath: t.path("minimal.meridian.manifest.json")))
    }

    @Test("autodiscovers a rulebook beside the meridian file")
    func withAutodiscoveredRulebook() async throws {
        let t = TempDir()
        t.write("local.merrules", "")
        let mer = t.write("flow.meridian", "To run:\n  complete.\n")
        let cmd = try RunCommand.parse([mer.path, "--output", t.url.path])
        try await cmd.run()
    }

    @Test("run with trace, checkpoint root, and keep-temp")
    func runWithOptions() async throws {
        let t = TempDir()
        let mer = t.write("flow.meridian", "To run:\n  complete.\n")
        let cmd = try RunCommand.parse([
            mer.path,
            "--output", t.url.path,
            "--run-id", "cli-cov-run",
            "--trace", "phrase",
            "--trace-file", t.path("trace.log"),
            "--checkpoint-root", t.path("checkpoints"),
            "--keep-temp"
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("trace.log")))
    }
}
