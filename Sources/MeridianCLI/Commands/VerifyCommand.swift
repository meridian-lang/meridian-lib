import ArgumentParser
import Foundation
import MeridianCore

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Alias for check: parse, lower, and report diagnostics without writing output."
    )

    @Argument(help: "Path to the .meridian file to verify.")
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
        let vocabularies = try merconfigURLs.map { url -> Compiler.VocabularyInput in
            .init(
                name: url.deletingPathExtension().lastPathComponent,
                file: url.lastPathComponent,
                source: try String(contentsOf: url, encoding: .utf8)
            )
        }
        let traceInstance = ParserTrace()
        if let spec = trace { traceInstance.enable(parsing: spec) }

        let compiler = Compiler(options: .init(trace: traceInstance))
        do {
            _ = try compiler.compile(
                meridianSource: meridianSource,
                meridianFile: meridianURL.lastPathComponent,
                vocabularies: vocabularies
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
