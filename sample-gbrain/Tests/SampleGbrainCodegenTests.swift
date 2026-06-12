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
//   2. `everySkillTypechecks` (opt-in via MERIDIAN_GBRAIN_TYPECHECK=1): shells
//      out to `swiftc -typecheck` against the built MeridianRuntime module, the
//      same mechanism SkillCorpusGoldenTests uses. Gated because it needs a
//      working toolchain and is much slower than the in-process check.

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
            let swift = try Compiler(options: opts).compile(
                meridianSource: source,
                meridianFile: file.lastPathComponent,
                vocabularies: [vocab],
                rulebooks: [rulebook]
            )
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

    // MARK: - Opt-in toolchain type-check

    @Test("every emitted Swift file type-checks against MeridianRuntime",
          .enabled(if: ProcessInfo.processInfo.environment["MERIDIAN_GBRAIN_TYPECHECK"] != nil))
    func everySkillTypechecks() throws {
        let artifacts = try locateRuntimeArtifacts()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-gbrain-typecheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var failures: [String] = []
        for (name, swift) in try compileAll() {
            let file = tmp.appendingPathComponent((name as NSString).deletingPathExtension + ".swift")
            try swift.write(to: file, atomically: true, encoding: .utf8)
            let result = runSwiftTypecheck(file: file, artifacts: artifacts)
            if !result.ok { failures.append("\(name):\n\(result.message)") }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "type-check failures:\n" + failures.joined(separator: "\n\n")))
    }

    private struct RuntimeArtifacts { let modulesDir: URL; let buildPath: URL }

    private func locateRuntimeArtifacts() throws -> RuntimeArtifacts {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["swift", "build", "--show-bin-path"]
        proc.currentDirectoryURL = SampleGbrainConformanceTests.sampleRoot().deletingLastPathComponent()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let bin = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let buildPath = URL(fileURLWithPath: bin)
        return RuntimeArtifacts(
            modulesDir: buildPath.appendingPathComponent("Modules"),
            buildPath: buildPath
        )
    }

    private func runSwiftTypecheck(file: URL, artifacts: RuntimeArtifacts) -> (ok: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [
            "swiftc", "-typecheck",
            "-I", artifacts.modulesDir.path,
            "-I", artifacts.buildPath.path,
            "-L", artifacts.buildPath.path,
            "-lMeridianRuntime",
            file.path,
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do { try proc.run() } catch { return (false, "failed to spawn swift: \(error)") }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (proc.terminationStatus == 0, output)
    }
}
