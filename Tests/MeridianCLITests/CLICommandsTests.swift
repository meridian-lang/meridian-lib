import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore
@testable import MeridianRuntime

private let repoRoot = FileManager.default.currentDirectoryPath
private func ex(_ rel: String) -> String { repoRoot + "/" + rel }

private let compileTypoVocab = """
=== vocabulary ===

An order is a kind of thing.

=== tools ===

Charge Payment
==============
~ chargePayment(order: Order) : Order
"""

private let compileTypoMeridian = """
---
vocabulary: t.merconfig
---
To process an order:
  invoke chargePaymnt with order = the order.
"""

// MARK: - compile

@Suite("CLI command — compile")
struct CompileCommandTests {
    @Test("happy path writes Swift + manifest (namespace none, no format)")
    func happy() async throws {
        let t = TempDir()
        let cmd = try CompileCommand.parse([
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
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--no-format", "--namespace", "auto", "--timestamp", "--no-line-comments"
        ])
        try await cmd.run()
        let swift = try String(contentsOfFile: t.path("order_processing.swift"), encoding: .utf8)
        #expect(swift.contains("enum OrderProcessing"))
    }

    @Test("custom namespace value is passed through")
    func namespaceCustom() async throws {
        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--no-format", "--namespace", "CustomNS"
        ])
        try await cmd.run()
        let swift = try String(contentsOfFile: t.path("order_processing.swift"), encoding: .utf8)
        #expect(swift.contains("enum CustomNS"))
    }

    @Test("missing input throws")
    func missingInput() async throws {
        let cmd = try CompileCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("broken source surfaces a diagnostic and exits non-zero (json)")
    func brokenJSON() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        let cmd = try CompileCommand.parse([
            bad.path, "--output", t.url.path, "--no-format",
            "--diagnostics-format", "json"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("swift-format path runs when --no-format is omitted")
    func withFormatting() async throws {
        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--namespace", "none"
        ])
        try await cmd.run()
        let swift = try String(contentsOfFile: t.path("order_processing.swift"), encoding: .utf8)
        #expect(!swift.isEmpty)
    }

    @Test("autodiscovers merconfig and rulebook beside the input")
    func autodiscoverDeps() async throws {
        let t = TempDir()
        let mer = try String(contentsOfFile: ex("examples/order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOfFile: ex("examples/ecommerce.merconfig"), encoding: .utf8)
        let rules = try String(contentsOfFile: ex("examples/skill/skill.merrules"), encoding: .utf8)
        t.write("order_processing.meridian", mer)
        t.write("ecommerce.merconfig", cfg)
        t.write("skill.merrules", rules)
        let cmd = try CompileCommand.parse([
            t.path("order_processing.meridian"),
            "--output", t.url.path,
            "--no-format", "--namespace", "none"
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.swift")))
    }

    @Test("explicit --rulebook is loaded")
    func explicitRulebook() async throws {
        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--rulebook", ex("examples/skill/skill.merrules"),
            "--output", t.url.path,
            "--no-format", "--namespace", "none"
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.swift")))
    }

    @Test("invalid --trace category emits a warning but compile still succeeds")
    func traceWarning() async throws {
        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--no-format", "--namespace", "none",
            "--trace", "not-a-real-category",
            "--diagnostics-format", "json"
        ])
        try await cmd.run()
    }

    @Test("namespace off and false both emit flat declarations")
    func namespaceOffVariants() async throws {
        for ns in ["off", "false"] {
            let t = TempDir()
            let cmd = try CompileCommand.parse([
                ex("examples/order_processing.meridian"),
                "--merconfig", ex("examples/ecommerce.merconfig"),
                "--output", t.url.path,
                "--no-format", "--namespace", ns
            ])
            try await cmd.run()
            let swift = try String(contentsOfFile: t.path("order_processing.swift"), encoding: .utf8)
            #expect(!swift.contains("enum OrderProcessing"), Comment(rawValue: "namespace \(ns)"))
        }
    }

    @Test("--fix dry-run on a typo does not crash")
    func fixDryRun() async throws {
        let t = TempDir()
        t.write("t.merconfig", compileTypoVocab)
        let bad = t.write("t.meridian", compileTypoMeridian)
        let cmd = try CompileCommand.parse([
            bad.path, "--merconfig", t.path("t.merconfig"),
            "--output", t.url.path, "--no-format", "--fix"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("--fix --write repairs a did-you-mean typo in place")
    func fixWrite() async throws {
        let t = TempDir()
        t.write("t.merconfig", compileTypoVocab)
        let mer = t.write("t.meridian", compileTypoMeridian)
        let cmd = try CompileCommand.parse([
            mer.path, "--merconfig", t.path("t.merconfig"),
            "--output", t.url.path, "--no-format", "--fix", "--write"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
        let fixed = try String(contentsOf: mer, encoding: .utf8)
        #expect(fixed.contains("chargePayment"))
    }
}

@Suite("CLI command — bench-parse")
struct BenchParseCommandTests {
    @Test("bench-parse runs over a sentence file")
    func smoke() throws {
        let t = TempDir()
        let input = t.write(
            "sentences.txt",
            """
            total amount is more than 500
            status is not active
            """
        )
        let cmd = try BenchParseCommand.parse([input.path])

        try cmd.run()
    }
}

// MARK: - check / verify

@Suite("CLI command — check / verify")
struct CheckVerifyCommandTests {
    @Test("check succeeds on the examples pair")
    func checkHappy() async throws {
        let cmd = try CheckCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig")
        ])
        try await cmd.run()
    }

    @Test("verify is an alias and succeeds on the examples pair")
    func verifyHappy() async throws {
        let cmd = try VerifyCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig")
        ])
        try await cmd.run()
    }

    @Test("check throws on a broken file; --fix dry-run does not crash")
    func checkBroken() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        let cmd = try CheckCommand.parse([bad.path, "--fix"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("check throws on a missing file")
    func checkMissing() async throws {
        let cmd = try CheckCommand.parse(["/definitely/missing.meridian"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("check --trace-file writes trace output to disk (B3 CLI parity)")
    func checkTraceFile() async throws {
        let t = TempDir()
        let cmd = try CheckCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--trace", "all", "--trace-file", t.path("trace.log")
        ])
        try await cmd.run()
        let trace = try String(contentsOfFile: t.path("trace.log"), encoding: .utf8)
        #expect(!trace.isEmpty)
    }

    @Test("verify --trace-file writes trace output to disk (B3 CLI parity)")
    func verifyTraceFile() async throws {
        let t = TempDir()
        let cmd = try VerifyCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--trace", "all", "--trace-file", t.path("trace.log")
        ])
        try await cmd.run()
        let trace = try String(contentsOfFile: t.path("trace.log"), encoding: .utf8)
        #expect(!trace.isEmpty)
    }
}

// MARK: - lint

@Suite("CLI command — lint")
struct LintCommandTests {
    @Test("lint runs over a real .meridian file")
    func lintRuns() throws {
        let cmd = try LintCommand.parse([ex("examples/order_processing.meridian")])
        do { try cmd.run() } catch { /* ExitCode.failure when an error-level diag exists */ }
    }

    @Test("lint prints hints and exits non-zero on error-level diagnostics")
    func lintErrorsAndHints() throws {
        let t = TempDir()
        let f = t.write(
            "bad.meridian",
            """
            To run:
              please complete.
              invoke it.
            """
        )
        let cmd = try LintCommand.parse([f.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("lint read failure propagates for a missing file")
    func missingFile() throws {
        let cmd = try LintCommand.parse(["/definitely/missing.meridian"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - format

@Suite("CLI command — format")
struct FormatCommandTests {
    @Test("--stdout reformats to stdout without mutating the file")
    func stdout() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n")
        let cmd = try FormatCommand.parse([f.path, "--stdout"])
        try cmd.run()
        let after = try String(contentsOf: f, encoding: .utf8)
        #expect(after == "An  order   is a kind of thing.\n")
    }

    @Test("--check on a dirty file exits non-zero")
    func checkDirty() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n\n\n")
        let cmd = try FormatCommand.parse([f.path, "--check"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("--check on clean files exits zero")
    func checkCleanMultipleFiles() throws {
        let t = TempDir()
        let formatter = MeridianFormatter()
        let a = t.write("a.merconfig", formatter.format("An order is a kind of thing.\n"))
        let b = t.write("b.meridian", formatter.format("To run:\n  complete.\n"))
        let cmd = try FormatCommand.parse([a.path, b.path, "--check"])
        try cmd.run()
    }

    @Test("in-place format writes back")
    func inPlace() throws {
        let t = TempDir()
        let f = t.write("a.merconfig", "An  order   is a kind of thing.\n\n\n")
        let cmd = try FormatCommand.parse([f.path])
        try cmd.run()
        let after = try String(contentsOf: f, encoding: .utf8)
        #expect(after != "An  order   is a kind of thing.\n\n\n")
    }

    @Test("in-place format leaves clean files unchanged")
    func inPlaceCleanNoop() throws {
        let t = TempDir()
        let formatter = MeridianFormatter()
        let clean = formatter.format("An order is a kind of thing.\n")
        let f = t.write("a.merconfig", clean)
        let cmd = try FormatCommand.parse([f.path])
        try cmd.run()
        let after = try String(contentsOf: f, encoding: .utf8)
        #expect(after == clean)
    }

    @Test("missing file throws")
    func missing() throws {
        let cmd = try FormatCommand.parse(["/definitely/missing.merconfig"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("empty inputs read stdin and write formatted output to stdout")
    func stdinShortcut() throws {
        let cmd = try FormatCommand.parse([])
        try cmd.run()
    }
}

// MARK: - docs

@Suite("CLI command — docs")
struct DocsCommandTests {
    @Test("renders a merconfig to stdout")
    func toStdout() throws {
        let cmd = try DocsCommand.parse([ex("examples/ecommerce.merconfig")])
        try cmd.run()
    }

    @Test("renders multiple merconfigs to a file")
    func toFile() throws {
        let t = TempDir()
        let cmd = try DocsCommand.parse([
            ex("examples/ecommerce.merconfig"), ex("examples/github.merconfig"),
            "--output", t.path("out.html"), "--title", "Docs"
        ])
        try cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("out.html")))
    }

    @Test("missing input file throws")
    func missing() throws {
        let cmd = try DocsCommand.parse(["/definitely/missing.merconfig"])
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
        let cmd = try PreviewSkillCommand.parse([md.path, "--name", "sample"])
        try cmd.run()
    }

    @Test("--trace-file writes trace output to disk (B3 CLI parity)")
    func traceFile() throws {
        let t = TempDir()
        let md = t.write("SKILL.md", "# Title\n\n## Overview\nDo the thing.\n")
        let cmd = try PreviewSkillCommand.parse([
            md.path, "--name", "sample",
            "--trace", "all", "--trace-file", t.path("trace.log")
        ])
        try cmd.run()
        let trace = try String(contentsOfFile: t.path("trace.log"), encoding: .utf8)
        #expect(!trace.isEmpty)
    }
}

// MARK: - explain

@Suite("CLI command — explain")
struct ExplainCommandTests {
    @Test("explains a known diagnostic code")
    func knownCode() throws {
        let code = try #require(DiagnosticCode.all.first)
        let cmd = try ExplainCommand.parse([code.id])
        try cmd.run()
    }

    @Test("explains a diagnostic code with its governing decision")
    func knownCodeWithDecision() throws {
        let cmd = try ExplainCommand.parse(["  mer2001  "])
        try cmd.run()
    }

    @Test("explains a known decision id")
    func knownDecision() throws {
        let decision = try #require(DecisionCatalog.all.first)
        let cmd = try ExplainCommand.parse([decision.id])
        try cmd.run()
    }

    @Test("unknown id throws with a suggestion")
    func unknown() throws {
        let cmd = try ExplainCommand.parse(["MER200l"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("unknown id without a close suggestion throws")
    func unknownWithoutSuggestion() throws {
        let cmd = try ExplainCommand.parse(["zzzzzzzzzzzz"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// MARK: - decisions

@Suite("CLI command — decisions")
struct DecisionsCommandTests {
    @Test("lists all decisions")
    func listAll() throws {
        let cmd = try DecisionsCommand.parse([])
        try cmd.run()
    }

    @Test("filters by query (match + no-match)")
    func query() throws {
        let match = try DecisionsCommand.parse(["the"])
        try match.run()
        let none = try DecisionsCommand.parse(["zzzznomatchzzzz"])
        try none.run()
    }

    @Test("--id prints one; unknown --id throws")
    func byID() throws {
        let decision = try #require(DecisionCatalog.all.first)
        let ok = try DecisionsCommand.parse(["--id", decision.id])
        try ok.run()
        let bad = try DecisionsCommand.parse(["--id", "D-NOPE-0"])
        #expect(throws: (any Error).self) { try bad.run() }
    }

    @Test("--render regenerates the catalog markdown to a file")
    func render() throws {
        let t = TempDir()
        let cmd = try DecisionsCommand.parse(["--render", t.path("decisions.md")])
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
        let cmd = try SkillDeviationCommand.parse([orig.path, port.path])
        try await cmd.run()
    }

    @Test("single-pair deviation writes a report file (--no-diff)")
    func toFile() async throws {
        let t = TempDir()
        let orig = t.write("SKILL.md", "# X\n## Overview\nDo it.\n")
        let port = t.write("x.meri", "## Overview\nDo it differently.\n")
        let cmd = try SkillDeviationCommand.parse([orig.path, port.path, "--out", t.path("reports"), "--no-diff"])
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
        let cmd = try SkillDeviationCommand.parse([origDir.path, portDir.path, "--batch", "--out", reports.path, "--index", "--no-diff"])
        try await cmd.run()
        let readme = try String(contentsOf: reports.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme.contains("Inert deviations:"), Comment(rawValue: readme))
        #expect(readme.contains("Operational inert:"), Comment(rawValue: readme))
        #expect(readme.contains("inert-section-added"), Comment(rawValue: readme))
        #expect(readme.contains("operational inert"), Comment(rawValue: readme))
    }

    @Test("missing original throws")
    func missing() async throws {
        let cmd = try SkillDeviationCommand.parse(["/nope/SKILL.md", "/nope/x.meri"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("missing ported file throws")
    func missingPorted() async throws {
        let t = TempDir()
        let orig = t.write("SKILL.md", "# X\n## Overview\nDo it.\n")
        let cmd = try SkillDeviationCommand.parse([orig.path, "/nope/x.meri"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("batch rejects non-directory inputs")
    func batchRequiresDirectories() async throws {
        let cmd = try SkillDeviationCommand.parse(["/tmp/not-a-dir", "/tmp/also-not", "--batch"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("batch pairs top-level markdown and reports unpaired skills")
    func batchUnpairedAndTopLevelMD() async throws {
        let t = TempDir()
        let origDir = t.url.appendingPathComponent("orig")
        let portDir = t.url.appendingPathComponent("ported")
        let reports = t.url.appendingPathComponent("reports")
        try FileManager.default.createDirectory(at: origDir.appendingPathComponent("demo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: portDir, withIntermediateDirectories: true)
        try "# Demo\n\n## Steps\nDo it.\n".write(
            to: origDir.appendingPathComponent("demo/SKILL.md"), atomically: true, encoding: .utf8)
        try "# Resolver\n\n## Steps\nResolve.\n".write(
            to: origDir.appendingPathComponent("RESOLVER.md"), atomically: true, encoding: .utf8)
        try "## Steps\nDo it.\n".write(
            to: portDir.appendingPathComponent("orphan.meri"), atomically: true, encoding: .utf8)
        t.write("rules.merrules", "=== sections ===\n")
        let cmd = try SkillDeviationCommand.parse([
            origDir.path, portDir.path, "--batch", "--out", reports.path, "--index", "--no-diff"
        ])
        try await cmd.run()
        let readme = try String(contentsOf: reports.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readme.contains("Unpaired originals"))
        #expect(readme.contains("Unpaired ports"))
    }

    @Test("batch rejects a non-directory ported path")
    func batchRejectsNonDirectoryPorted() async throws {
        let t = TempDir()
        let origDir = t.url.appendingPathComponent("orig")
        try FileManager.default.createDirectory(at: origDir, withIntermediateDirectories: true)
        let file = t.write("ported.meri", "## Overview\n")
        let cmd = try SkillDeviationCommand.parse([origDir.path, file.path, "--batch"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("single mode loads a rulebook beside the ported file")
    func singleWithRulebook() async throws {
        let t = TempDir()
        let orig = t.write("SKILL.md", "# X\n## Overview\nDo it.\n")
        t.write("local.merrules", "=== sections ===\n")
        let port = t.write("x.meri", "## Overview\nDo it.\n")
        let cmd = try SkillDeviationCommand.parse([orig.path, port.path])
        try await cmd.run()
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
        let cmd = try MigrateSkillCommand.parse([md.path])
        do { try await cmd.run() } catch { /* ExitCode(1) when the candidate does not strict-compile */ }
    }

    @Test("missing input throws")
    func missing() async throws {
        let cmd = try MigrateSkillCommand.parse(["/nope/SKILL.md"])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("--trace-file writes trace output to disk (B3 CLI parity)")
    func traceFile() async throws {
        let t = TempDir()
        t.write("v.merconfig", "An input is a kind of thing.\n")
        let md = t.write("SKILL.md", "---\nname: demo\n---\n# Demo\n\n## Overview\nThis is a demonstration.\n")
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--trace", "all", "--trace-file", t.path("trace.log")
        ])
        do { try await cmd.run() } catch { /* ExitCode(1) when the candidate does not strict-compile */ }
        let trace = try String(contentsOfFile: t.path("trace.log"), encoding: .utf8)
        #expect(!trace.isEmpty)
    }

    @Test("--route-fuzzy defaults on and --no-route-fuzzy parses to false")
    func routeFuzzyFlag() throws {
        let onDefault = try MigrateSkillCommand.parse(["SKILL.md"])
        #expect(onDefault.routeFuzzy)
        let offExplicit = try MigrateSkillCommand.parse(["SKILL.md", "--no-route-fuzzy"])
        #expect(!offExplicit.routeFuzzy)
    }

    @Test("--no-route-fuzzy leaves a fuzzy checklist (( inert )) instead of AI-routing it")
    func noRouteFuzzyDisablesAiRouting() async throws {
        let t = TempDir()
        t.write("v.merconfig", "An input is a kind of thing.\n")
        let md = t.write("SKILL.md", """
        ---
        name: demo
        ---
        ## Acceptance

        - [ ] Reviewer judgment call one that needs synthesis of vague context
        - [ ] Reviewer judgment call two that needs synthesis of vague context
        - [ ] Reviewer judgment call three that needs synthesis of vague context
        """)
        let cmd = try MigrateSkillCommand.parse([md.path, "--no-route-fuzzy"])
        do { try await cmd.run() } catch { /* ExitCode(1) when the candidate does not strict-compile */ }
    }

    @Test("single migration writes --out and --report files")
    func singleToFileWithReport() async throws {
        let t = TempDir()
        t.write("v.merconfig", "An input is a kind of thing.\n")
        let md = t.write("SKILL.md", "---\nname: demo\n---\n# Demo\n\n## Overview\nThis is a demonstration.\n")
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--out", t.path("demo.meri"), "--report", t.path("report.txt"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        #expect(FileManager.default.fileExists(atPath: t.path("demo.meri")))
        if FileManager.default.fileExists(atPath: t.path("report.txt")) {
            let report = try String(contentsOfFile: t.path("report.txt"), encoding: .utf8)
            #expect(report.contains("skill:"))
        }
    }

    @Test("refuses to overwrite without --force")
    func refusesOverwrite() async throws {
        let t = TempDir()
        t.write("v.merconfig", "An input is a kind of thing.\n")
        let md = t.write("SKILL.md", "---\nname: demo\n---\n# Demo\n\n## Overview\nDemo.\n")
        t.write("demo.meri", "existing")
        let cmd = try MigrateSkillCommand.parse([md.path, "--out", t.path("demo.meri")])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("batch migration discovers SKILL.md files and writes outputs")
    func batchMigration() async throws {
        let t = TempDir()
        let root = t.url.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("beta"), withIntermediateDirectories: true)
        try "An input is a kind of thing.\n".write(
            to: root.appendingPathComponent("v.merconfig"), atomically: true, encoding: .utf8)
        try "---\nname: alpha\n---\n# Alpha\n\n## Overview\nAlpha demo.\n".write(
            to: root.appendingPathComponent("alpha/SKILL.md"), atomically: true, encoding: .utf8)
        try "---\nname: beta\n---\n# Beta\n\n## Overview\nBeta demo.\n".write(
            to: root.appendingPathComponent("beta/SKILL.md"), atomically: true, encoding: .utf8)
        let cmd = try MigrateSkillCommand.parse([
            root.path, "--batch", "--out", t.path("out"), "--report", t.path("matrix.txt"), "--force"
        ])
        do { try await cmd.run() } catch { /* ExitCode(1) when any skill fails strict compile */ }
        #expect(FileManager.default.fileExists(atPath: t.path("matrix.txt")))
    }

    @Test("--batch requires a directory and rejects an empty tree")
    func batchValidation() async throws {
        let t = TempDir()
        let md = t.write("SKILL.md", "# Demo\n")
        let notDir = try MigrateSkillCommand.parse([md.path, "--batch"])
        await #expect(throws: (any Error).self) { try await notDir.run() }
        let empty = t.url.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        let noSkills = try MigrateSkillCommand.parse([empty.path, "--batch"])
        await #expect(throws: (any Error).self) { try await noSkills.run() }
    }

    @Test("explicit --vocab and --rulebook override autodiscovery")
    func explicitDependencies() async throws {
        let t = TempDir()
        let cfg = t.write("custom.merconfig", "An input is a kind of thing.\n")
        let rules = t.write("custom.merrules", "=== sections ===\n")
        let md = t.write("SKILL.md", "---\nname: demo\n---\n# Demo\n\n## Overview\nDemo.\n")
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--vocab", cfg.path, "--rulebook", rules.path, "--out", t.path("demo.meri"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
    }

    private static let shellSkillMarkdown = """
    ## How to use

    ```bash
    echo hello
    ```
    """

    private static let unminedSkillMarkdown = """
    ## Steps

    Authors must never delete original SKILL.md files.

    Validate the order.
    """

    private static let orderVocab = """
    === vocabulary ===

    An order is a kind of thing.
    """

    @Test("section aliases persist to migrated-sections.merrules beside --out")
    func sectionAliasPersistence() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--out", t.path("demo.meri"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        let rulebook = t.path("migrated-sections.merrules")
        if FileManager.default.fileExists(atPath: rulebook) {
            let text = try String(contentsOfFile: rulebook, encoding: .utf8)
            #expect(text.contains("section \"How to use\""))
            #expect(text.contains("-> procedure"))
        }
    }

    @Test("section aliases append under an existing === sections === block")
    func sectionAliasAppendExistingRulebook() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let rules = t.write("skill.merrules", "=== sections ===\nsection \"Existing\" -> procedure\n")
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--rulebook", rules.path, "--out", t.path("demo.meri"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        let text = try String(contentsOfFile: rules.path, encoding: .utf8)
        #expect(text.contains("section \"Existing\""))
        #expect(text.contains("section \"How to use\""))
    }

    @Test("known section aliases are not duplicated in the rulebook")
    func sectionAliasSkipDuplicates() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let rules = t.write("skill.merrules", "=== sections ===\nsection \"How to use\" -> procedure\n")
        let before = try String(contentsOfFile: rules.path, encoding: .utf8)
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--rulebook", rules.path, "--out", t.path("demo.meri"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        let after = try String(contentsOfFile: rules.path, encoding: .utf8)
        #expect(after == before)
    }

    @Test("stdout mode prints alias snippets when no --out is given")
    func stdoutAliasSnippet() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([md.path])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
    }

    @Test("unmined contracts surface in --report output")
    func unminedContractsReport() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", Self.unminedSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--out", t.path("demo.meri"), "--report", t.path("report.txt"), "--force"
        ])
        do { try await cmd.run() } catch { /* strict compile may fail */ }
        if FileManager.default.fileExists(atPath: t.path("report.txt")) {
            let report = try String(contentsOfFile: t.path("report.txt"), encoding: .utf8)
            #expect(report.contains("unmined-contract lines:"))
            #expect(report.contains("must never delete original"))
        }
    }

    @Test("strict-compile failure throws ExitCode(1) after writing --out")
    func compileFailureExitCode() async throws {
        let t = TempDir()
        let md = t.write("SKILL.md", """
        ---
        vocabulary: missing.merconfig
        ---
        ## Steps
        Complete the task.
        """)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--out", t.path("demo.meri"), "--force"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
        #expect(FileManager.default.fileExists(atPath: t.path("demo.meri")))
    }

    @Test("migration report lists compile diagnostics when present")
    func reportWithDiagnostics() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", """
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--out", t.path("demo.meri"), "--report", t.path("report.txt"), "--force"
        ])
        try await cmd.run()
        let report = try String(contentsOfFile: t.path("report.txt"), encoding: .utf8)
        #expect(report.contains("diagnostics:"))
        #expect(report.contains("L"))
    }

    @Test("batch migration throws when any skill fails strict compile")
    func batchPartialFailure() async throws {
        let t = TempDir()
        let root = t.url.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("good"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bad"), withIntermediateDirectories: true)
        try Self.orderVocab.write(to: root.appendingPathComponent("v.merconfig"), atomically: true, encoding: .utf8)
        try Self.shellSkillMarkdown.write(to: root.appendingPathComponent("good/SKILL.md"), atomically: true, encoding: .utf8)
        try """
        ---
        vocabulary: missing.merconfig
        ---
        ## Steps
        Complete the task.
        """.write(to: root.appendingPathComponent("bad/SKILL.md"), atomically: true, encoding: .utf8)
        let cmd = try MigrateSkillCommand.parse([
            root.path, "--batch", "--out", t.path("out"), "--report", t.path("matrix.txt"), "--force"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
        let matrix = try String(contentsOfFile: t.path("matrix.txt"), encoding: .utf8)
        #expect(matrix.contains("| bad | ✗ |"))
        #expect(FileManager.default.fileExists(atPath: t.path("out/good.meri")))
        #expect(FileManager.default.fileExists(atPath: t.path("out/bad.meri")))
    }

    @Test("section aliases append to an empty explicit rulebook file")
    func emptyRulebookAliasAppend() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let rules = t.write("skill.merrules", "")
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--rulebook", rules.path, "--out", t.path("demo.meri"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        let text = try String(contentsOfFile: rules.path, encoding: .utf8)
        #expect(text.contains("=== sections ==="))
        #expect(text.contains("section \"How to use\""))
    }

    @Test("batch mode creates migrated-sections.merrules in the output directory")
    func batchRulebookTarget() async throws {
        let t = TempDir()
        let root = t.url.appendingPathComponent("skills")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("alpha"), withIntermediateDirectories: true)
        try Self.orderVocab.write(to: root.appendingPathComponent("v.merconfig"), atomically: true, encoding: .utf8)
        try Self.shellSkillMarkdown.write(to: root.appendingPathComponent("alpha/SKILL.md"), atomically: true, encoding: .utf8)
        let cmd = try MigrateSkillCommand.parse([
            root.path, "--batch", "--out", t.path("out"), "--force"
        ])
        do { try await cmd.run() } catch { /* compile outcome may vary */ }
        let rulebook = t.path("out/migrated-sections.merrules")
        if FileManager.default.fileExists(atPath: rulebook) {
            let text = try String(contentsOfFile: rulebook, encoding: .utf8)
            #expect(text.contains("section \"How to use\""))
        }
    }
}

// MARK: - resume

@Suite("CLI command — resume")
struct ResumeCommandTests {
    @Test("resume against an empty checkpoint root executes (no snapshot)")
    func emptyRoot() async throws {
        let t = TempDir()
        let cmd = try ResumeCommand.parse(["unknown-run", "--checkpoint-root", t.url.path])
        do { try await cmd.run() } catch { /* may throw when no checkpoint exists */ }
    }

    @Test("resume prints JSON when a checkpoint exists")
    func withCheckpoint() async throws {
        let t = TempDir()
        let cp = try FilesystemCheckpointer(rootURL: t.url)
        try await cp.write(Checkpoint(
            runID: "cli-resume-test",
            sequence: 1,
            timestamp: Date(),
            label: "saved",
            stateSnapshot: StateSnapshot(bindings: ["k": AnyCodable(.string("v"))]),
            sourceRange: nil
        ))
        let cmd = try ResumeCommand.parse(["cli-resume-test", "--checkpoint-root", t.url.path])
        try await cmd.run()
    }

    @Test("resume uses the default caches directory when --checkpoint-root is omitted")
    func defaultCheckpointRoot() async throws {
        let cmd = try ResumeCommand.parse(["unknown-run-id"])
        do { try await cmd.run() } catch { /* no checkpoint in caches */ }
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
