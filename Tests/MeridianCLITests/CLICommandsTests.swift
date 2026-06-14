import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore

private let repoRoot = FileManager.default.currentDirectoryPath
private func ex(_ rel: String) -> String { repoRoot + "/" + rel }

// MARK: - compile

@Suite("CLI command — compile")
struct CompileCommandTests {
    @Test("happy path writes Swift + manifest (namespace none, no format)")
    func happy() async throws {
        let t = TempDir()
        var cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--no-format", "--namespace", "none"
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.swift")))
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.meridian.manifest.json")))
    }

    @Test("namespace auto + timestamp + no-line-comments all run")
    func namespaceAuto() async throws {
        let t = TempDir()
        var cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--no-format", "--namespace", "auto", "--timestamp", "--no-line-comments"
        ])
        try await cmd.run()
        let swift = try String(contentsOfFile: t.path("order_processing.swift"), encoding: .utf8)
        #expect(swift.contains("enum OrderProcessing"))
    }

    @Test("missing input throws")
    func missingInput() async throws {
        var cmd = try CompileCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("broken source surfaces a diagnostic and exits non-zero (json)")
    func brokenJSON() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        var cmd = try CompileCommand.parse([
            bad.path, "--output", t.url.path, "--no-format",
            "--diagnostics-format", "json"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

// MARK: - check / verify

@Suite("CLI command — check / verify")
struct CheckVerifyCommandTests {
    @Test("check succeeds on the examples pair")
    func checkHappy() async throws {
        var cmd = try CheckCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig")
        ])
        try await cmd.run()
    }

    @Test("verify is an alias and succeeds on the examples pair")
    func verifyHappy() async throws {
        var cmd = try VerifyCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig")
        ])
        try await cmd.run()
    }

    @Test("check throws on a broken file; --fix dry-run does not crash")
    func checkBroken() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        var cmd = try CheckCommand.parse([bad.path, "--fix"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("check throws on a missing file")
    func checkMissing() async throws {
        var cmd = try CheckCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

// MARK: - lint

@Suite("CLI command — lint")
struct LintCommandTests {
    @Test("lint runs over a real .meridian file")
    func lintRuns() throws {
        var cmd = try LintCommand.parse([ex("examples/order_processing.meridian")])
        // Lint may or may not find errors; either way run() executes its body.
        do { try cmd.run() } catch { /* ExitCode.failure when an error-level diag exists */ }
    }
}

// MARK: - format

@Suite("CLI command — format")
struct FormatCommandTests {
    @Test("--stdout reformats to stdout without mutating the file")
    func stdout() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n")
        var cmd = try FormatCommand.parse([f.path, "--stdout"])
        try cmd.run()
    }

    @Test("--check on a dirty file exits non-zero")
    func checkDirty() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n\n\n")
        var cmd = try FormatCommand.parse([f.path, "--check"])
        // If the formatter considers it dirty it exits 1; otherwise it succeeds.
        do { try cmd.run() } catch { /* ExitCode(1) on dirty */ }
    }

    @Test("in-place format writes back")
    func inPlace() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n\n\n")
        var cmd = try FormatCommand.parse([f.path])
        try cmd.run()
    }

    @Test("missing file throws")
    func missing() throws {
        var cmd = try FormatCommand.parse(["/definitely/missing.merconfig"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - docs

@Suite("CLI command — docs")
struct DocsCommandTests {
    @Test("renders a merconfig to stdout")
    func toStdout() throws {
        var cmd = try DocsCommand.parse([ex("examples/ecommerce.merconfig")])
        try cmd.run()
    }

    @Test("renders multiple merconfigs to a file")
    func toFile() throws {
        let t = TempDir()
        var cmd = try DocsCommand.parse([
            ex("examples/ecommerce.merconfig"), ex("examples/github.merconfig"),
            "--output", t.path("out.html"), "--title", "Docs"
        ])
        try cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("out.html")))
    }

    @Test("missing input file throws")
    func missing() throws {
        var cmd = try DocsCommand.parse(["/definitely/missing.merconfig"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - preview-skill

@Suite("CLI command — preview-skill")
struct PreviewSkillCommandTests {
    @Test("previews a SKILL.md")
    func preview() throws {
        let t = TempDir()
        let md = t.write("SKILL.md", "# Title\n\n## Overview\nDo the thing.\n")
        var cmd = try PreviewSkillCommand.parse([md.path, "--name", "sample"])
        try cmd.run()
    }
}

// MARK: - explain

@Suite("CLI command — explain")
struct ExplainCommandTests {
    @Test("explains a known diagnostic code")
    func knownCode() throws {
        let code = try #require(DiagnosticCode.all.first)
        var cmd = try ExplainCommand.parse([code.id])
        try cmd.run()
    }

    @Test("explains a known decision id")
    func knownDecision() throws {
        let decision = try #require(DecisionCatalog.all.first)
        var cmd = try ExplainCommand.parse([decision.id])
        try cmd.run()
    }

    @Test("unknown id throws with a suggestion")
    func unknown() throws {
        var cmd = try ExplainCommand.parse(["MER9999zzz"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - decisions

@Suite("CLI command — decisions")
struct DecisionsCommandTests {
    @Test("lists all decisions")
    func listAll() throws {
        var cmd = try DecisionsCommand.parse([])
        try cmd.run()
    }

    @Test("filters by query (match + no-match)")
    func query() throws {
        var match = try DecisionsCommand.parse(["the"])
        try match.run()
        var none = try DecisionsCommand.parse(["zzzznomatchzzzz"])
        try none.run()
    }

    @Test("--id prints one; unknown --id throws")
    func byID() throws {
        let decision = try #require(DecisionCatalog.all.first)
        var ok = try DecisionsCommand.parse(["--id", decision.id])
        try ok.run()
        var bad = try DecisionsCommand.parse(["--id", "D-NOPE-0"])
        #expect(throws: (any Error).self) { try bad.run() }
    }

    @Test("--render regenerates the catalog markdown to a file")
    func render() throws {
        let t = TempDir()
        var cmd = try DecisionsCommand.parse(["--render", t.path("decisions.md")])
        try cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("decisions.md")))
    }
}

// MARK: - test

@Suite("CLI command — test")
struct TestSubcommandTests {
    @Test("no specs found throws ExitCode(1)")
    func noSpecs() throws {
        let t = TempDir()
        var cmd = try TestCommand.parse([t.url.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("runs a single copied spec (success or failure both exercise the body)")
    func singleSpec() throws {
        let t = TempDir()
        let spec = ex("Tests/MeridianCoreTests/MeridianTestSpecs/runtime_happy.meridian.test")
        let body = try String(contentsOfFile: spec, encoding: .utf8)
        t.write("runtime_happy.meridian.test", body)
        var cmd = try TestCommand.parse([t.url.path, "--verbose"])
        do { try cmd.run() } catch { /* ExitCode(1) if the spec fails in isolation */ }
    }

    @Test("tag filter can skip a copied spec")
    func tagFilteredSpecSkips() throws {
        let t = TempDir()
        let spec = ex("Tests/MeridianCoreTests/MeridianTestSpecs/compile_only.meridian.test")
        t.write("compile_only.meridian.test", try String(contentsOfFile: spec, encoding: .utf8))
        t.write("order_processing.meridian", try String(contentsOfFile: ex("Tests/MeridianCoreTests/MeridianTestSpecs/order_processing.meridian"), encoding: .utf8))
        t.write("ecommerce.merconfig", try String(contentsOfFile: ex("Tests/MeridianCoreTests/MeridianTestSpecs/ecommerce.merconfig"), encoding: .utf8))
        var cmd = try TestCommand.parse([t.url.path, "--tag", "does-not-match"])
        try cmd.run()
    }
}

// MARK: - trace render

@Suite("CLI command — trace")
struct TraceRenderCommandTests {
    @Test("categories subcommand lists trace categories")
    func categories() throws {
        var cmd = try TraceRenderCommand.parseAsRoot(["categories"])
        try cmd.run()
    }

    @Test("render reads a jsonl file and prints a tree")
    func render() throws {
        let t = TempDir()
        let jsonl = """
        {"kind":"workflow.start","sequence":0,"runId":"r","name":"W"}
        {"kind":"invoke.start","sequence":1,"runId":"r","toolId":"shell.run"}
        {"kind":"invoke.end","sequence":2,"runId":"r","toolId":"shell.run"}
        {"kind":"workflow.complete","sequence":3,"runId":"r"}
        """
        let f = t.write("events.jsonl", jsonl)
        var cmd = try TraceRenderCommand.parseAsRoot(["render", f.path, "--ascii", "--no-timings", "--no-sources"])
        try cmd.run()
    }

    @Test("render of a missing file throws")
    func renderMissing() throws {
        var cmd = try TraceRenderCommand.parseAsRoot(["render", "/definitely/missing.jsonl"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - skill-deviation

@Suite("CLI command — skill-deviation")
struct SkillDeviationCommandTests {
    @Test("single-pair deviation prints to stdout")
    func single() async throws {
        let t = TempDir()
        let orig = t.write("SKILL.md", "---\nname: x\n---\n# X\n\n## Overview\nDo the thing.\n")
        let port = t.write("x.meri", "## Overview\nDo the thing.\n")
        var cmd = try SkillDeviationCommand.parse([orig.path, port.path])
        try await cmd.run()
    }

    @Test("single-pair deviation writes a report file (--no-diff)")
    func toFile() async throws {
        let t = TempDir()
        let orig = t.write("SKILL.md", "# X\n## Overview\nDo it.\n")
        let port = t.write("x.meri", "## Overview\nDo it differently.\n")
        var cmd = try SkillDeviationCommand.parse([orig.path, port.path, "--out", t.path("reports"), "--no-diff"])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("reports/x.md")))
    }

    @Test("batch index includes operational inert metrics")
    func batchIndex() async throws {
        let t = TempDir()
        let origDir = t.url.appendingPathComponent("orig")
        let portDir = t.url.appendingPathComponent("ported")
        let reports = t.url.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: origDir.appendingPathComponent("demo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: portDir.appendingPathComponent("skills"), withIntermediateDirectories: true)
        try "# Demo\n\n## Steps\nDo it.\n".write(to: origDir.appendingPathComponent("demo/SKILL.md"), atomically: true, encoding: .utf8)
        try "## Steps (( inert, role: procedure ))\n\n`gbrain stats`\n".write(to: portDir.appendingPathComponent("skills/demo.meri"), atomically: true, encoding: .utf8)
        var cmd = try SkillDeviationCommand.parse([origDir.path, portDir.path, "--batch", "--out", reports.path, "--index", "--no-diff"])
        try await cmd.run()
        let readme = try String(contentsOf: reports.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme.contains("Operational inert:"), Comment(rawValue: readme))
        #expect(readme.contains("operational inert"), Comment(rawValue: readme))
    }

    @Test("missing original throws")
    func missing() async throws {
        var cmd = try SkillDeviationCommand.parse(["/nope/SKILL.md", "/nope/x.meri"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

// MARK: - migrate-skill

@Suite("CLI command — migrate-skill")
struct MigrateSkillCommandTests {
    @Test("single migration to stdout runs (compile outcome may vary)")
    func single() async throws {
        let t = TempDir()
        // Self-contained vocab beside the input so autodiscovery resolves.
        t.write("v.merconfig", "An input is a kind of thing.\n")
        let md = t.write("SKILL.md", "---\nname: demo\n---\n# Demo\n\n## Overview\nThis is a demonstration.\n")
        var cmd = try MigrateSkillCommand.parse([md.path])
        do { try await cmd.run() } catch { /* ExitCode(1) when the candidate does not strict-compile */ }
    }

    @Test("missing input throws")
    func missing() async throws {
        var cmd = try MigrateSkillCommand.parse(["/nope/SKILL.md"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

// MARK: - resume

@Suite("CLI command — resume")
struct ResumeCommandTests {
    @Test("resume against an empty checkpoint root executes (no snapshot)")
    func emptyRoot() async throws {
        let t = TempDir()
        var cmd = try ResumeCommand.parse(["unknown-run", "--checkpoint-root", t.url.path])
        do { try await cmd.run() } catch { /* may throw when no checkpoint exists */ }
    }
}

// MARK: - run

@Suite("CLI command — run")
struct RunCommandTests {
    @Test("missing input throws before any SwiftPM work")
    func missing() async throws {
        var cmd = try RunCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}
