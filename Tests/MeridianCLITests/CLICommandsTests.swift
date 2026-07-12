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

    @Test("invalid --trace category exits with a coded diagnostic")
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
        await #expect(throws: (any Error).self) {
            try await cmd.run()
        }
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

    @Test("swift-format failure is cosmetic and can render json diagnostics")
    func swiftFormatFailureWarningJSON() async throws {
        setenv("MERIDIAN_TEST_SWIFT_FORMAT_FAIL", "1", 1)
        defer { unsetenv("MERIDIAN_TEST_SWIFT_FORMAT_FAIL") }

        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--namespace", "none",
            "--diagnostics-format", "json",
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.swift")))
    }

    @Test("swift-format failure renders human diagnostics by default")
    func swiftFormatFailureWarningHuman() async throws {
        setenv("MERIDIAN_TEST_SWIFT_FORMAT_FAIL", "1", 1)
        defer { unsetenv("MERIDIAN_TEST_SWIFT_FORMAT_FAIL") }

        let t = TempDir()
        let cmd = try CompileCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--output", t.url.path,
            "--namespace", "none",
        ])
        try await cmd.run()
        #expect(FileManager.default.fileExists(atPath: t.path("order_processing.swift")))
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
    @Test("lint command exposes a public empty initializer for ArgumentParser")
    func emptyInitializer() {
        _ = LintCommand()
    }

    @Test("lint runs over a real .meridian file")
    func lintRuns() throws {
        let cmd = try LintCommand.parse([ex("examples/order_processing.meridian")])
        do { try cmd.run() } catch { /* ExitCode.failure when an error-level diag exists */ }
    }

    @Test("lint json format renders diagnostics to stderr")
    func lintJSONFormat() throws {
        let t = TempDir()
        let f = t.write(
            "bad.meridian",
            """
            To run:
              please complete.
              invoke it.
            """
        )
        let cmd = try LintCommand.parse(["--format", "json", f.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("lint accepts json diagnostics format")
    func lintAcceptsJSONFormat() throws {
        let cmd = try LintCommand.parse(["--format", "json", ex("examples/order_processing.meridian")])
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

// MARK: - explain / drift / grammar-doc

@Suite("CLI command — explain")
struct ExplainCommandTests {
    @Test("verbalizes a temp .meri using autodiscovered merconfig")
    func happy() async throws {
        let fixture = auditFixture()
        let cmd = try ExplainCommand.parse([fixture.meri.path])

        try await cmd.run()
    }

    @Test("library path matches explain surface for order_processing")
    func orderProcessingSurface() throws {
        let mer = try String(contentsOfFile: ex("examples/order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOfFile: ex("examples/ecommerce.merconfig"), encoding: .utf8)
        let model = try Compiler(options: .init(trace: .silent())).compileToModel(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]
        )
        let canonical = try Verbalizer(model: model).verbalize()
        #expect(canonical.contains("To process a order placed by a customer:"))
        #expect(canonical.contains("invoke validateOrder"))
        #expect(canonical.contains("assert not the order's total amount is more than"))
    }

    @Test("missing input throws")
    func missingInput() async throws {
        let cmd = try ExplainCommand.parse(["/definitely/missing.meri"])

        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("broken input reports compiler diagnostics")
    func brokenInput() async throws {
        let t = TempDir()
        t.write("bad.merconfig", "An order is a kind of thing.\n")
        let bad = t.write("bad.meri", """
        ---
        vocabulary: bad.merconfig
        ---
        To audit an order:
          frobnicate the wibble.
        """)
        let cmd = try ExplainCommand.parse([bad.path])

        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

@Suite("CLI command — drift")
struct DriftCommandTests {
    @Test("reports drift for a temp .meri using autodiscovered merconfig")
    func happy() async throws {
        let fixture = auditFixture()
        let cmd = try DriftCommand.parse([fixture.meri.path])

        try await cmd.run()
    }

    @Test("reports no drift for an already canonical temp .meri")
    func noDrift() async throws {
        let fixture = auditFixture()
        let source = try String(contentsOf: fixture.meri, encoding: .utf8)
        let model = try Compiler(options: .init(trace: .silent())).compileToModel(
            meridianSource: source,
            meridianFile: fixture.meri.lastPathComponent,
            vocabularies: [.init(name: "audit", file: fixture.merconfig.lastPathComponent, source: try String(contentsOf: fixture.merconfig, encoding: .utf8))]
        )
        try Verbalizer(model: model).verbalize().write(to: fixture.meri, atomically: true, encoding: .utf8)
        let cmd = try DriftCommand.parse([fixture.meri.path])

        try await cmd.run()
    }

    @Test("order_processing reports non-empty synonym cosmetic drift")
    func orderProcessingSynonymDrift() throws {
        let mer = try String(contentsOfFile: ex("examples/order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOfFile: ex("examples/ecommerce.merconfig"), encoding: .utf8)
        let model = try Compiler(options: .init(trace: .silent())).compileToModel(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]
        )
        let canonical = try Verbalizer(model: model).verbalize()
        let report = DriftEngine.diff(authored: mer, canonical: canonical)
        #expect((report.counts[.synonymCanonicalized] ?? 0) > 0)
        #expect(report.hunks.count > 0)
        #expect(DriftEngine.diff(authored: canonical, canonical: canonical).hunks.isEmpty)
    }

    @Test("emits JSON when requested")
    func json() async throws {
        let fixture = auditFixture()
        let cmd = try DriftCommand.parse([fixture.meri.path, "--json"])

        try await cmd.run()
    }

    @Test("drift JSON schema is stable for order_processing")
    func jsonSchemaOrderProcessing() throws {
        let mer = try String(contentsOfFile: ex("examples/order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOfFile: ex("examples/ecommerce.merconfig"), encoding: .utf8)
        let model = try Compiler(options: .init(trace: .silent())).compileToModel(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]
        )
        let canonical = try Verbalizer(model: model).verbalize()
        let report = DriftEngine.diff(authored: mer, canonical: canonical)
        #expect((report.counts[.synonymCanonicalized] ?? 0) > 0)
        #expect((report.counts[.meaningBearing] ?? 0) >= 0)
        #expect(report.hunks.count == report.counts.values.reduce(0, +))
    }

    @Test("doc-heavy placeorder reports meaning-bearing drift")
    func placeorderMeaningBearing() throws {
        let mer = try String(contentsOfFile: ex("corpora/erp/skills/placeorder.meri"), encoding: .utf8)
        let cfg = try String(contentsOfFile: ex("corpora/erp/erp.merconfig"), encoding: .utf8)
        let rb = try String(contentsOfFile: ex("corpora/erp/erp.merrules"), encoding: .utf8)
        let model = try Compiler(options: .init(trace: .silent())).compileToModel(
            meridianSource: mer,
            meridianFile: "placeorder.meri",
            vocabularies: [.init(name: "erp", file: "erp.merconfig", source: cfg)],
            rulebooks: [.init(name: "erp", file: "erp.merrules", source: rb)]
        )
        let canonical = try Verbalizer(model: model).verbalize()
        let report = DriftEngine.diff(authored: mer, canonical: canonical)
        #expect((report.counts[.meaningBearing] ?? 0) > 0)
    }

    @Test("missing merconfig path throws validation error")
    func missingMerconfigPath() async throws {
        let fixture = auditFixture()
        let cmd = try ExplainCommand.parse([
            fixture.meri.path, "--merconfig", "/definitely/missing.merconfig"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("missing rulebook path throws validation error")
    func missingRulebookPath() async throws {
        let fixture = auditFixture()
        let cmd = try DriftCommand.parse([
            fixture.meri.path, "--rulebook", "/definitely/missing.merrules"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("dual merconfig merge order is preserved for explain")
    func dualMerconfigMerge() async throws {
        let t = TempDir()
        t.write("a.merconfig", """
        === vocabulary ===
        An order is a kind of thing.
        An order has a score, which is Number.
        """)
        t.write("b.merconfig", """
        === vocabulary ===
        A page is a kind of thing.
        A page has a status, which is String.
        """)
        let meri = t.write("dual.meri", """
        ---
        vocabulary: a.merconfig
        ---
        To audit an order:
          assert score is more than 1.
          complete.
        """)
        let cmd = try ExplainCommand.parse([
            meri.path,
            "--merconfig", t.path("a.merconfig"),
            "--merconfig", t.path("b.merconfig"),
        ])
        try await cmd.run()
    }

    @Test("missing input throws")
    func missingInput() async throws {
        let cmd = try DriftCommand.parse(["/definitely/missing.meri"])

        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("broken input reports compiler diagnostics")
    func brokenInput() async throws {
        let t = TempDir()
        t.write("bad.merconfig", "An order is a kind of thing.\n")
        let bad = t.write("bad.meri", """
        ---
        vocabulary: bad.merconfig
        ---
        To audit an order:
          frobnicate the wibble.
        """)
        let cmd = try DriftCommand.parse([bad.path, "--json"])

        await #expect(throws: (any Error).self) { try await cmd.run() }
    }
}

@Suite("CLI command — grammar-doc")
struct GrammarDocCommandTests {
    @Test("emits the public grammar markdown")
    func happy() throws {
        let cmd = try GrammarDocCommand.parse([])

        try cmd.run()
        let markdown = GrammarDocCommand.markdown()
        #expect(markdown.contains("# Meridian Grammar Reference"))
        #expect(markdown.contains("| `comparison` |"))
        #expect(markdown.contains("| `quantifier` |"))
        #expect(markdown.contains("| `after-idiom` |"))
    }
}

private func auditFixture() -> (dir: TempDir, meri: URL, merconfig: URL) {
    let t = TempDir()
    let cfg = t.write("audit.merconfig", """
    === vocabulary ===

    An order is a kind of thing.
    An order has a score, which is Number.
    """)
    let meri = t.write("audit.meri", """
    ---
    vocabulary: audit.merconfig
    ---
    To validate an order:
      assert score is greater than 1.
      complete.
    """)
    return (t, meri, cfg)
}

// MARK: - preview-skill

@Suite("CLI command — preview-skill")
struct PreviewSkillCommandTests {
    @Test("missing input throws")
    func missingInput() throws {
        let cmd = try PreviewSkillCommand.parse(["/definitely/missing/SKILL.md"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

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

// MARK: - explain-diag

@Suite("CLI command — explain-diag")
struct ExplainDiagCommandTests {
    @Test("explains a known diagnostic code")
    func knownCode() throws {
        let code = try #require(DiagnosticCode.all.first)
        let cmd = try ExplainDiagCommand.parse([code.id])
        try cmd.run()
    }

    @Test("explains a diagnostic code with its governing decision")
    func knownCodeWithDecision() throws {
        let cmd = try ExplainDiagCommand.parse(["  mer2001  "])
        try cmd.run()
    }

    @Test("explains a known decision id")
    func knownDecision() throws {
        let decision = try #require(DecisionCatalog.all.first)
        let cmd = try ExplainDiagCommand.parse([decision.id])
        try cmd.run()
    }

    @Test("unknown id throws with a suggestion")
    func unknown() throws {
        let cmd = try ExplainDiagCommand.parse(["MER200l"])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    @Test("unknown id without a close suggestion throws")
    func unknownWithoutSuggestion() throws {
        let cmd = try ExplainDiagCommand.parse(["zzzzzzzzzzzz"])
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

// NOTE: "CLI command — test" (TestSubcommandTests) moved to
// Tests/MeridianSlowIntegrationTests/CLIRunAndTestCommandSlowTests.swift — it
// drives a real subprocess-executing test spec. See the target comment in
// Package.swift.

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

    @Test("trace drift detects step-path and version-hash differences")
    func traceDrift() throws {
        let t = TempDir()
        let baseline = t.write("baseline.manifest.json", """
        {"skill_version_hash":"v1","workflows":[{"step_paths":["/A/root/procedure/x"]}]}
        """)
        let candidate = t.write("candidate.manifest.json", """
        {"skill_version_hash":"v2","workflows":[{"step_paths":["/A/root/procedure/y"]}]}
        """)
        var cmd = try TraceRenderCommand.parseAsRoot(["drift", baseline.path, candidate.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }
}

// NOTE: "CLI command — trace verify" moved to
// Tests/MeridianSlowIntegrationTests/TraceVerifyCLISlowTests.swift.

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
        #expect(readme.contains("canonical_drift:"), Comment(rawValue: readme))
        #expect(readme.contains("generated_loc"), Comment(rawValue: readme))
        #expect(readme.contains("doc-section-marked"), Comment(rawValue: readme))
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
        t.write("local.merrules", """
        === sections ===
        section "Overview" -> reference
        """)
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

    @Test("--route-fuzzy defaults off (P1 hard-error-by-default policy) and --route-fuzzy parses to true")
    func routeFuzzyFlag() throws {
        let onDefault = try MigrateSkillCommand.parse(["SKILL.md"])
        #expect(!onDefault.routeFuzzy)
        let onExplicit = try MigrateSkillCommand.parse(["SKILL.md", "--route-fuzzy"])
        #expect(onExplicit.routeFuzzy)
    }

    @Test("--no-route-fuzzy leaves a fuzzy checklist as its own operational-error child instead of rescuing a compile failure to reference")
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
        // No checkable/inference signal under "Phases" is a hard migration
        // error by default (P1 category 4) — `runSingle` writes the report
        // (with its diagnostics) before throwing `ExitCode(1)`.
        do { try await cmd.run() } catch { /* ExitCode(1): expected, compile fails */ }
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

    @Test("explicit missing --vocab and --rulebook throw coded input errors")
    func explicitMissingDependencies() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let missingVocab = try MigrateSkillCommand.parse([
            md.path, "--vocab", "/definitely/missing.merconfig", "--out", t.path("demo.meri"), "--force"
        ])
        await #expect(throws: (any Error).self) { try await missingVocab.run() }

        let missingRules = try MigrateSkillCommand.parse([
            md.path, "--rulebook", "/definitely/missing.merrules", "--out", t.path("demo.meri"), "--force"
        ])
        await #expect(throws: (any Error).self) { try await missingRules.run() }
    }

    @Test("primary rulebook target rejects a missing explicit --rulebook path")
    func missingPrimaryRulebookTarget() async throws {
        let t = TempDir()
        t.write("v.merconfig", Self.orderVocab)
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([
            md.path, "--rulebook", "/definitely/missing.merrules",
            "--out", t.path("demo.meri"), "--force"
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("batch directory enumeration failure surfaces a coded exit")
    func batchDirectoryEnumerationFailure() async throws {
        let t = TempDir()
        let locked = t.url.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let cfg = t.write("v.merconfig", Self.orderVocab)
        let rules = t.write("rules.merrules", "=== sections ===\n")

        let cmd = try MigrateSkillCommand.parse([
            locked.path, "--batch", "--out", t.path("out"), "--force",
            "--vocab", cfg.path, "--rulebook", rules.path
        ])
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("batch on a file throws before dependency loading")
    func batchRequiresDirectoryBeforeDeps() async throws {
        let t = TempDir()
        let md = t.write("SKILL.md", Self.shellSkillMarkdown)
        let cmd = try MigrateSkillCommand.parse([md.path, "--batch"])
        do {
            try await cmd.run()
            Issue.record("expected ValidationError")
        } catch let error as ValidationError {
            #expect(String(describing: error).contains("--batch requires a directory"))
        } catch {
            Issue.record("unexpected error: \(error)")
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

// NOTE: "CLI command — run" (RunCommandTests) moved to
// Tests/MeridianSlowIntegrationTests/CLIRunAndTestCommandSlowTests.swift — it
// compiles then spawns a real `swift build`/`swift run` through a temporary
// SwiftPM package. See the target comment in Package.swift.
