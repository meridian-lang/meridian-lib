import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Codegen-validity tests for the ported gbrain corpus.
//
// `everySkillCompiles` (in SampleGbrainConformanceTests) only proves the
// Meridian pipeline produced Swift *source* without throwing — it never feeds
// that source to a Swift parser. This suite closes that gap:
//
//   1. `emittedSwiftIsWellFormed` (always on, in-process, no toolchain): a
//      tiny string-literal lexer asserts that no single-line `"…"` literal
//      contains a raw newline. That is exactly the class of bug where a
//      multi-line frontmatter value (e.g. a YAML block-scalar `triggers:`) was
//      emitted into a one-line Swift string literal — invalid Swift that
//      sailed through `compile()` and only blew up later inside swift-format.
//
//   2. `everySkillTypechecks` lives in
//      `Tests/MeridianSlowIntegrationTests/GeneratedSwiftTypecheckSlowTests.swift`
//      and shells out to `swiftc -typecheck` against the built MeridianRuntime module.

@Suite("sample-gbrain codegen validity")
struct SampleGbrainCodegenTests {

    /// Derive a namespace enum name from a file stem, mirroring the CLI's
    /// `--namespace auto` behaviour so the tests validate the shipped form.
    static func namespace(for file: URL) -> String {
        let stem = file.deletingPathExtension().lastPathComponent
        let parts = stem.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        guard let first = joined.first else { return "Skill" }
        return first.isNumber ? "_" + joined : joined
    }

    private func compileAll() throws -> [(name: String, swift: String)] {
        let vocab = try SampleGbrainConformanceTests.vocab()
        let rulebook = try SampleGbrainConformanceTests.rulebook()
        return try SampleGbrainConformanceTests.skillFiles().map { file in
            let source = try String(contentsOf: file, encoding: .utf8)
            // Namespaced emission is the default shipped form (matches the CLI
            // `--namespace auto`); validate that exact output.
            let opts = Compiler.Options(
                emitterOptions: SwiftEmitter.Options(namespaceEnum: Self.namespace(for: file)),
                trace: .silent()
            )
            let swift = try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file.lastPathComponent)], vocabularies: [vocab], rulebooks: [rulebook]))[file.lastPathComponent]!.swift
            return (file.lastPathComponent, swift)
        }
    }

    // MARK: - In-process syntactic guard

    @Test("every emitted Swift file has no raw newline inside a single-line string literal")
    func emittedSwiftIsWellFormed() throws {
        var failures: [String] = []
        for (name, swift) in try compileAll() {
            let bad = Self.unterminatedStringLiteralLines(in: swift)
            if !bad.isEmpty {
                failures.append("\(name): single-line string literal spans a newline at line(s) \(bad.map(String.init).joined(separator: ", "))")
            }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "Malformed generated Swift:\n" + failures.joined(separator: "\n")))
    }

    @Test("webhook_transforms committed output matches fresh namespaced emission")
    func webhookTransformsCommittedOutputIsFresh() throws {
        let root = SampleGbrainConformanceTests.sampleRoot()
        let skill = root.appendingPathComponent("skills/webhook_transforms.meri")
        let committed = try String(
            contentsOf: root.appendingPathComponent("compile-outputs/webhook_transforms.swift"),
            encoding: .utf8
        )
        let source = try String(contentsOf: skill, encoding: .utf8)
        let fresh = try Compiler(options: .init(
            emitterOptions: .init(namespaceEnum: Self.namespace(for: skill)),
            trace: .silent()
        )).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: skill.lastPathComponent)], vocabularies: [SampleGbrainConformanceTests.vocab()], rulebooks: [SampleGbrainConformanceTests.rulebook()]))[skill.lastPathComponent]!.swift

        #expect(committed == fresh, Comment(rawValue: "webhook_transforms.swift is stale"))
        #expect(fresh.contains("enum WebhookTransforms"), Comment(rawValue: fresh))
        #expect(fresh.contains("struct WebhookTransformsInput"), Comment(rawValue: fresh))
        #expect(!fresh.contains("Webhook-transforms"), Comment(rawValue: fresh))
    }

    /// A minimal Swift string-literal lexer. Returns the 1-based line numbers on
    /// which a single-line `"…"` literal opened but the physical line ended
    /// before its closing quote. Triple-quoted (`"""`) literals, line comments
    /// (`//`), and block comments (`/* */`) are skipped so they don't false-flag.
    static func unterminatedStringLiteralLines(in source: String) -> [Int] {
        enum Mode { case normal, string, multiline, lineComment, blockComment }
        var mode: Mode = .normal
        var line = 1
        var stringStartLine = 0
        var flagged: [Int] = []

        let chars = Array(source)
        var i = 0
        func peek(_ ahead: Int) -> Character? {
            let j = i + ahead
            return j < chars.count ? chars[j] : nil
        }

        while i < chars.count {
            let c = chars[i]
            switch mode {
            case .normal:
                if c == "\n" { line += 1; i += 1 }
                else if c == "\"", peek(1) == "\"", peek(2) == "\"" {
                    mode = .multiline; i += 3
                } else if c == "\"" {
                    mode = .string; stringStartLine = line; i += 1
                } else if c == "/", peek(1) == "/" {
                    mode = .lineComment; i += 2
                } else if c == "/", peek(1) == "*" {
                    mode = .blockComment; i += 2
                } else { i += 1 }

            case .string:
                if c == "\\" { i += 2 }          // escaped char (incl. \" and \\)
                else if c == "\"" { mode = .normal; i += 1 }
                else if c == "\n" {              // bug: newline inside "…"
                    flagged.append(stringStartLine)
                    mode = .normal; line += 1; i += 1
                } else { i += 1 }

            case .multiline:
                if c == "\"", peek(1) == "\"", peek(2) == "\"" {
                    mode = .normal; i += 3
                } else if c == "\n" { line += 1; i += 1 }
                else if c == "\\" { i += 2 }
                else { i += 1 }

            case .lineComment:
                if c == "\n" { mode = .normal; line += 1; i += 1 } else { i += 1 }

            case .blockComment:
                if c == "*", peek(1) == "/" { mode = .normal; i += 2 }
                else if c == "\n" { line += 1; i += 1 }
                else { i += 1 }
            }
        }
        return flagged
    }
}
