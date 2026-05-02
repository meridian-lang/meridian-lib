import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian check`
//
// Type-check + lower a `.meridian` file without writing any Swift output.
// Surfaces parser / lowerer diagnostics with file:line:col anchors and exits
// non-zero on the first error so a CI pipeline can gate merges.
//
// Multi-vocabulary inputs use the same auto-discovery rules as `compile`:
// `--merconfig` is repeatable; if omitted, every `.merconfig` next to the
// .meridian file (or in the parent directory) is loaded.

struct CheckCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Parse + lower a .meridian file and report diagnostics. No output is written."
    )

    @Argument(help: "Path to the .meridian file to check.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: phrase, phrase.match, lowering, all.")
    var trace: String?

    func run() async throws {
        let meridianURL = URL(fileURLWithPath: input).standardized
        guard FileManager.default.fileExists(atPath: meridianURL.path) else {
            throw ValidationError("File not found: \(input)")
        }
        let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)

        let merconfigURLs = try resolveMerconfigs(beside: meridianURL)
        var vocabularies: [Compiler.VocabularyInput] = []
        for url in merconfigURLs {
            let src = try String(contentsOf: url, encoding: .utf8)
            let name = url.deletingPathExtension().lastPathComponent
            vocabularies.append(.init(name: name, file: url.lastPathComponent, source: src))
        }

        let traceInstance = ParserTrace()
        if let spec = trace { traceInstance.enable(parsing: spec) }

        let compiler = Compiler(options: .init(trace: traceInstance))

        do {
            // Re-use the full compile pipeline; we discard the emitted Swift
            // because the user only asked for diagnostics. Same code path as
            // `compile`, so a `check` pass and a `compile` pass agree on
            // what counts as a valid program.
            _ = try compiler.compile(
                meridianSource: meridianSource,
                meridianFile:   meridianURL.lastPathComponent,
                vocabularies:   vocabularies
            )
            print("✓ \(meridianURL.lastPathComponent): no errors (\(vocabularies.count) vocab\(vocabularies.count == 1 ? "" : "s") loaded)")
        } catch let CompilerError.syntaxError(message, range) {
            FileHandle.standardError.write(Data("✗ \(range): syntax error — \(message)\n".utf8))
            throw ExitCode(1)
        } catch let CompilerError.semanticError(message, range) {
            FileHandle.standardError.write(Data("✗ \(range): semantic error — \(message)\n".utf8))
            throw ExitCode(1)
        } catch let CompilerError.codegenError(message) {
            FileHandle.standardError.write(Data("✗ codegen error — \(message)\n".utf8))
            throw ExitCode(1)
        }
    }

    // MARK: - Helpers

    /// Mirror of `CompileCommand.resolveMerconfigs` — kept here as a copy so
    /// the two commands evolve independently if their resolution rules
    /// diverge. (Currently identical.)
    private func resolveMerconfigs(beside meridianURL: URL) throws -> [URL] {
        if !merconfig.isEmpty {
            return try merconfig.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("merconfig not found: \(path)")
                }
                return url
            }
        }
        let dir = meridianURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let here = files.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !here.isEmpty { return here }
        let parent = dir.deletingLastPathComponent()
        let parentFiles = (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        return parentFiles.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
