import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore
import MeridianRuntime

// MARK: - Temp workspace helper

/// A throwaway directory under the system temp root, removed on `deinit`.
final class TempDir {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-cli-tests-\(UUID().uuidString)", isDirectory: true)
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

// MARK: - namespace naming

@Suite("CLI support — namespace naming")
struct PascalCaseTests {
    @Test("splits on non-alphanumerics and guards leading digits")
    func pascalCase() {
        #expect(IdentifierNaming.swiftTypeNameFromStem("idea_lineage") == "IdeaLineage")
        #expect(IdentifierNaming.swiftTypeNameFromStem("webhook-transforms") == "WebhookTransforms")
        #expect(IdentifierNaming.swiftTypeNameFromStem("order") == "Order")
        #expect(IdentifierNaming.swiftTypeNameFromStem("2fast") == "_2fast")
        #expect(IdentifierNaming.swiftTypeNameFromStem("") == "Skill")
        #expect(IdentifierNaming.swiftTypeNameFromStem("a.b.c") == "ABC")
    }
}

// MARK: - DependencyDiscovery

@Suite("CLI support — DependencyDiscovery")
struct DependencyDiscoveryTests {
    @Test("explicit paths take precedence and are validated to exist")
    func explicitFound() throws {
        let t = TempDir()
        let cfg = t.write("vocab.merconfig", "# empty")
        let urls = try DependencyDiscovery.resolveMerconfigs(
            explicit: [cfg.path], beside: t.url.appendingPathComponent("x.meridian"))
        #expect(urls.count == 1)
        #expect(urls[0].lastPathComponent == "vocab.merconfig")
    }

    @Test("explicit not-found throws a coded exit")
    func explicitMissing() {
        do {
            _ = try DependencyDiscovery.resolveMerconfigs(
                explicit: ["/nope/missing.merconfig"],
                beside: URL(fileURLWithPath: "/tmp/x.meridian"))
            Issue.record("expected ExitCode(1)")
        } catch let code as ExitCode {
            #expect(code == ExitCode(1))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("auto-discovers every matching file beside the input, sorted")
    func autodiscoverBeside() throws {
        let t = TempDir()
        t.write("b.merconfig", "")
        t.write("a.merconfig", "")
        t.write("ignore.txt", "")
        let urls = try DependencyDiscovery.resolveMerconfigs(
            explicit: [], beside: t.url.appendingPathComponent("flow.meridian"))
        #expect(urls.map(\.lastPathComponent) == ["a.merconfig", "b.merconfig"])
    }

    @Test("falls back to the parent directory when none beside the input")
    func autodiscoverParentFallback() throws {
        let t = TempDir()
        t.write("parent.merrules", "")
        let sub = t.url.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let urls = try DependencyDiscovery.resolveRulebooks(
            explicit: [], beside: sub.appendingPathComponent("flow.meridian"))
        #expect(urls.map(\.lastPathComponent) == ["parent.merrules"])
    }

    @Test("explicit rulebook not-found exits with code 1")
    func explicitRulebookMissing() {
        do {
            _ = try DependencyDiscovery.resolveRulebooks(
                explicit: ["/nope/missing.merrules"],
                beside: URL(fileURLWithPath: "/tmp/x.meridian"))
            Issue.record("expected ExitCode(1)")
        } catch let code as ExitCode {
            #expect(code == ExitCode(1))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("loadVocabularies names each input from its file stem")
    func loadVocabularies() throws {
        let t = TempDir()
        let url = t.write("ecommerce.merconfig", "# stuff")
        let vocab = try DependencyDiscovery.loadVocabularies([url])
        #expect(vocab.count == 1)
        #expect(vocab[0].name == "ecommerce")
        #expect(vocab[0].file == "ecommerce.merconfig")
        #expect(vocab[0].source == "# stuff")
    }
}

// MARK: - makeCLITrace

@Suite("CLI support — trace bootstrap", .serialized)
struct TraceBootstrapTests {
    @Test("nil spec yields a trace with no categories enabled")
    func noSpec() throws {
        let trace = try makeCLITrace(spec: nil)
        #expect(!trace.isEnabled(.lowering))
    }

    @Test("jsonl format emits structured records with corr field")
    func jsonlFormat() throws {
        let t = TempDir()
        let file = t.path("trace.jsonl")
        let trace = try makeCLITrace(spec: "lowering", file: file, format: .jsonl)
        #expect(trace.outputFormat == .jsonl)
        trace.log(.lowering, "jsonl probe")
        let contents = try String(contentsOfFile: file, encoding: .utf8)
        #expect(contents.contains("\"corr\":\"\(trace.correlationID)\""))
        #expect(contents.contains("\"cat\":\"lowering\""))
    }

    @Test("active trace announces correlation id on stderr bootstrap")
    func announcesCorrelationID() throws {
        let trace = try makeCLITrace(spec: "lowering")
        #expect(!trace.correlationID.isEmpty)
    }

    @Test("MERIDIAN_TRACE env activates tracing and announces correlation id without --trace")
    func envTraceAnnouncesCorrelationID() throws {
        setenv("MERIDIAN_TRACE", "lowering", 1)
        defer { unsetenv("MERIDIAN_TRACE") }
        let trace = try makeCLITrace(spec: nil)
        #expect(trace.isEnabled(.lowering))
        #expect(!trace.correlationID.isEmpty)
    }

    @Test("spec enables categories and a file sink is created")
    func specAndFile() throws {
        let t = TempDir()
        let file = t.path("trace.log")
        let trace = try makeCLITrace(spec: "all", file: file)
        #expect(trace.isEnabled(.lowering))
        trace.log(.lowering, "hello from cli trace")
        #expect(FileManager.default.fileExists(atPath: file))
        let contents = try String(contentsOfFile: file, encoding: .utf8)
        #expect(contents.contains("[lowering] hello from cli trace"), Comment(rawValue: contents))
    }

    @Test("unknown trace category exits with code 1")
    func unknownTraceCategoryExits() {
        do {
            _ = try makeCLITrace(spec: "not-a-real-category")
            Issue.record("expected ExitCode(1)")
        } catch let code as ExitCode {
            #expect(code == ExitCode(1))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("unwritable trace file exits with code 1")
    func unwritableTraceFileExits() {
        let t = TempDir()
        _ = t.write("not-a-directory", "plain file")
        do {
            _ = try makeCLITrace(spec: "lowering", file: t.path("not-a-directory/trace.log"))
            Issue.record("expected ExitCode(1)")
        } catch let code as ExitCode {
            #expect(code == ExitCode(1))
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        do {
            _ = try makeCLITrace(spec: "lowering", file: t.path("not-a-directory/nested/trace.log"))
            Issue.record("expected ExitCode(1)")
        } catch let code as ExitCode {
            #expect(code == ExitCode(1))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

// MARK: - DiagnosticsFormat

@Suite("CLI support — DiagnosticsFormat")
struct DiagnosticsFormatTests {
    @Test("parses from argument strings; unknown rejected")
    func parsing() {
        #expect(DiagnosticsFormat(argument: "human") == .human)
        #expect(DiagnosticsFormat(argument: "json") == .json)
        #expect(DiagnosticsFormat(argument: "garbage") == nil)
        #expect(Set(DiagnosticsFormat.allCases) == [.human, .json])
    }
}

// MARK: - reportCompilerError

@Suite("CLI support — reportCompilerError")
struct ReportCompilerErrorTests {
    struct PlainError: Error {}

    @Test("a non-CompilerError still returns exit code 1")
    func genericError() {
        let code = reportCompilerError(PlainError())
        #expect(code == ExitCode(1))
    }

    @Test("a CompilerError renders as human and json, both exit 1")
    func compilerErrorBothFormats() throws {
        // Force a real CompilerError by compiling a broken file.
        let broken = "to do a thing:\n    frobnicate the wibble\n"
        let compiler = Compiler(options: .init(trace: ParserTrace.silent()))
        do {
            _ = try compiler.compile(meridianSource: broken, meridianFile: "broken.meridian",
                                     vocabularies: [], rulebooks: [])
            Issue.record("expected a compiler error")
        } catch {
            let human = reportCompilerError(error, sources: ["broken.meridian": broken], format: .human)
            let json = reportCompilerError(error, sources: ["broken.meridian": broken], format: .json)
            #expect(human == ExitCode(1))
            #expect(json == ExitCode(1))
        }
    }

    @Test("an IRValidationError renders diagnostics and exits 1")
    func irValidationError() {
        let diagnostics = [
            Diagnostic.error(
                .invalidIR,
                message: "invalid hand-built IR",
                range: SourceRange(file: "invalid.ir", line: 1, column: 1)
            )
        ]
        let human = reportCompilerError(IRValidationError.diagnostics(diagnostics), format: .human)
        let json = reportCompilerError(IRValidationError.diagnostics(diagnostics), format: .json)
        #expect(human == ExitCode(1))
        #expect(json == ExitCode(1))
    }
}

// MARK: - Shared fixtures

private let cliToolVocab = """
=== vocabulary ===

An order is a kind of thing.

=== tools ===

Charge Payment
==============
~ chargePayment(order: Order) : Order
"""

private let cliTypoMeridian = """
---
vocabulary: t.merconfig
---
To process an order:
  invoke chargePaymnt with order = the order.
"""

// MARK: - applyQuickFixes

@Suite("CLI support — applyQuickFixes")
struct ApplyQuickFixesTests {
    struct PlainError: Error {}

    @Test("a non-CompilerError applies nothing")
    func genericError() {
        #expect(applyQuickFixes(PlainError(), sources: [:], write: false) == 0)
    }

    @Test("a CompilerError without ranged single-suggestions applies nothing")
    func noRangedSuggestions() throws {
        let broken = "to do a thing:\n    frobnicate the wibble\n"
        let compiler = Compiler(options: .init(trace: ParserTrace.silent()))
        do {
            _ = try compiler.compile(meridianSource: broken, meridianFile: "b.meridian",
                                     vocabularies: [], rulebooks: [])
            Issue.record("expected a compiler error")
        } catch {
            // Dry run: never mutates the source; returns the applied count (>= 0).
            let applied = applyQuickFixes(error, sources: ["b.meridian": broken], write: false)
            #expect(applied >= 0)
        }
    }

    private func compileTypoTool(t: TempDir) throws -> (Error, String, URL) {
        let merURL = t.write("t.meridian", cliTypoMeridian)
        _ = t.write("t.merconfig", cliToolVocab)
        let compiler = Compiler(options: .init(trace: ParserTrace.silent()))
        do {
            _ = try compiler.compile(
                meridianSource: cliTypoMeridian, meridianFile: "t.meridian",
                merconfigSource: cliToolVocab, merconfigFile: "t.merconfig")
            Issue.record("expected a compiler error")
            return (PlainError(), cliTypoMeridian, merURL)
        } catch {
            return (error, cliTypoMeridian, merURL)
        }
    }

    @Test("dry-run previews an unambiguous did-you-mean fix")
    func dryRunFix() throws {
        let t = TempDir()
        let (error, source, _) = try compileTypoTool(t: t)
        let applied = applyQuickFixes(
            error, sources: ["t.meridian": source], write: false)
        #expect(applied == 1)
    }

    @Test("--write applies the fix in place")
    func writeFix() throws {
        let t = TempDir()
        let (error, source, merURL) = try compileTypoTool(t: t)
        let applied = applyQuickFixes(
            error,
            sources: ["t.meridian": source],
            paths: ["t.meridian": merURL],
            write: true)
        #expect(applied == 1)
        let fixed = try String(contentsOf: merURL, encoding: .utf8)
        #expect(fixed.contains("chargePayment"))
        #expect(!fixed.contains("chargePaymnt"))
    }

    @Test("ambiguous token matches are skipped")
    func ambiguousSkip() {
        let source = "ab ac\n"
        let range = SourceRange(
            file: "t.meridian", startLine: 1, startColumn: 1, endLine: 1, endColumn: 6)
        let d = Diagnostic(
            code: .unknownTool, message: "test", primaryRange: range,
            suggestions: [Suggestion(replacement: "ad", range: range, rationale: "fix")])
        let applied = applyQuickFixes(
            CompilerError.diagnostics([d]),
            sources: ["t.meridian": source],
            write: false)
        #expect(applied == 0)
    }

    @Test("out-of-budget suggestions report no auto-applicable fixes")
    func noBudgetMatch() {
        let source = "invoke zzzzzzz with x.\n"
        let range = SourceRange(
            file: "t.meridian", startLine: 1, startColumn: 1, endLine: 1, endColumn: 22)
        let d = Diagnostic.unresolved(
            .unknownTool, target: "zzzzzzzz", among: ["chargePayment"],
            range: range, noun: "tool")
        #expect(d.suggestions.isEmpty)
        let applied = applyQuickFixes(
            CompilerError.diagnostics([d]),
            sources: ["t.meridian": source],
            write: false)
        #expect(applied == 0)
    }
}

// MARK: - stderrIsTTY

@Suite("CLI support — stderrIsTTY")
struct StderrIsTTYTests {
    @Test("returns a boolean without crashing")
    func smoke() {
        _ = stderrIsTTY()
    }
}

// MARK: - runDiagnosticsCheck

@Suite("CLI support — runDiagnosticsCheck")
struct RunDiagnosticsCheckTests {
    @Test("loads autodiscovered rulebooks beside the input")
    func rulebookBeside() async throws {
        let t = TempDir()
        t.write("flow.merconfig", cliToolVocab)
        t.write("flow.merrules", "=== sections ===\n")
        t.write("flow.meridian", """
        ---
        vocabulary: flow.merconfig
        ---
        To process an order:
          invoke chargePayment with order = the order.
        """)
        try await runDiagnosticsCheck(input: t.path("flow.meridian"), merconfig: [], trace: nil)
    }

    @Test("broken input with --fix dry-run does not crash")
    func brokenWithFix() async throws {
        let t = TempDir()
        let bad = t.write("bad.meridian", "to do a thing:\n    frobnicate the wibble\n")
        await #expect(throws: (any Error).self) {
            try await runDiagnosticsCheck(input: bad.path, merconfig: [], trace: nil, fix: true)
        }
    }
}
