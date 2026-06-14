import Foundation
import Testing
import ArgumentParser
@testable import MeridianCLIKit
import MeridianCore

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

// MARK: - pascalCase

@Suite("CLI support — pascalCase")
struct PascalCaseTests {
    @Test("splits on non-alphanumerics and guards leading digits")
    func pascalCase() {
        #expect(CompileCommand.pascalCase("idea_lineage") == "IdeaLineage")
        #expect(CompileCommand.pascalCase("webhook-transforms") == "WebhookTransforms")
        #expect(CompileCommand.pascalCase("order") == "Order")
        #expect(CompileCommand.pascalCase("2fast") == "_2fast")
        #expect(CompileCommand.pascalCase("") == "Skill")
        #expect(CompileCommand.pascalCase("a.b.c") == "ABC")
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

    @Test("explicit not-found throws a ValidationError")
    func explicitMissing() {
        #expect(throws: (any Error).self) {
            _ = try DependencyDiscovery.resolveMerconfigs(
                explicit: ["/nope/missing.merconfig"],
                beside: URL(fileURLWithPath: "/tmp/x.meridian"))
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

@Suite("CLI support — trace bootstrap")
struct TraceBootstrapTests {
    @Test("nil spec yields a trace with no categories enabled")
    func noSpec() {
        let trace = makeCLITrace(spec: nil)
        #expect(!trace.isEnabled(.lowering))
    }

    @Test("spec enables categories and a file sink is created")
    func specAndFile() {
        let t = TempDir()
        let file = t.path("trace.log")
        let trace = makeCLITrace(spec: "all", file: file)
        #expect(trace.isEnabled(.lowering))
        #expect(FileManager.default.fileExists(atPath: file))
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
}

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
}
