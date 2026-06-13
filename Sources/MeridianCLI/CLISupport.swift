import ArgumentParser
import Foundation
import MeridianCore

// MARK: - Dependency discovery

/// Resolve `.merconfig` / `.merrules` dependency files for a `.meridian` input.
/// Explicit `--flag` paths (validated to exist) take precedence; otherwise every
/// matching file beside the input is auto-discovered (sorted by name for a
/// deterministic order), falling back to the parent directory. Single source for
/// what `compile`, `check`, `verify`, and `run` each used to copy.
enum DependencyDiscovery {

    static func resolve(explicit: [String], extension ext: String, label: String, beside inputURL: URL) throws -> [URL] {
        if !explicit.isEmpty {
            return try explicit.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("\(label) not found: \(path)")
                }
                return url
            }
        }
        func matches(in dir: URL) -> [URL] {
            ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
                .filter { $0.pathExtension == ext }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        let dir = inputURL.deletingLastPathComponent()
        let here = matches(in: dir)
        if !here.isEmpty { return here }
        return matches(in: dir.deletingLastPathComponent())
    }

    static func resolveMerconfigs(explicit: [String], beside inputURL: URL) throws -> [URL] {
        try resolve(explicit: explicit, extension: "merconfig", label: "merconfig", beside: inputURL)
    }

    static func resolveRulebooks(explicit: [String], beside inputURL: URL) throws -> [URL] {
        try resolve(explicit: explicit, extension: "merrules", label: "rulebook", beside: inputURL)
    }

    /// Load resolved merconfig URLs into `VocabularyInput`s (name = file stem).
    static func loadVocabularies(_ urls: [URL]) throws -> [Compiler.VocabularyInput] {
        try urls.map { url in
            .init(name: url.deletingPathExtension().lastPathComponent,
                  file: url.lastPathComponent,
                  source: try String(contentsOf: url, encoding: .utf8))
        }
    }
}

// MARK: - Trace bootstrap

/// Build a `ParserTrace` from the CLI's `--trace` spec and optional
/// `--trace-file` sink. Single source for the bootstrap every diagnostic command
/// repeated inline.
func makeCLITrace(spec: String?, file: String? = nil) -> ParserTrace {
    let trace = ParserTrace()
    if let spec { trace.enable(parsing: spec) }
    if let file {
        let url = URL(fileURLWithPath: file).standardized
        FileManager.default.createFile(atPath: url.path, contents: nil)
        trace.sink = .file(url)
    }
    return trace
}

// MARK: - Diagnostics

/// Print a `CompilerError` to stderr with its source anchor. Returns the exit
/// code to throw. Shared by `check` and `verify` (and any future diagnostic
/// command) so the catch ladders never drift.
func reportCompilerError(_ error: Error) -> ExitCode {
    switch error {
    case let CompilerError.syntaxError(message, range):
        FileHandle.standardError.write(Data("✗ \(range): syntax error — \(message)\n".utf8))
    case let CompilerError.semanticError(message, range):
        FileHandle.standardError.write(Data("✗ \(range): semantic error — \(message)\n".utf8))
    case let CompilerError.codegenError(message):
        FileHandle.standardError.write(Data("✗ codegen error — \(message)\n".utf8))
    default:
        FileHandle.standardError.write(Data("✗ \(error)\n".utf8))
    }
    return ExitCode(1)
}

/// Run the shared parse + lower diagnostics pass used by both `check` and
/// `verify`: load vocab, compile (discarding emitted Swift), and report. Throws
/// `ExitCode(1)` on the first compiler error.
func runDiagnosticsCheck(input: String, merconfig: [String], trace: String?) async throws {
    let meridianURL = URL(fileURLWithPath: input).standardized
    guard FileManager.default.fileExists(atPath: meridianURL.path) else {
        throw ValidationError("File not found: \(input)")
    }
    let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
    let merconfigURLs = try DependencyDiscovery.resolveMerconfigs(explicit: merconfig, beside: meridianURL)
    let vocabularies = try DependencyDiscovery.loadVocabularies(merconfigURLs)

    let compiler = Compiler(options: .init(trace: makeCLITrace(spec: trace)))
    do {
        _ = try compiler.compile(
            meridianSource: meridianSource,
            meridianFile: meridianURL.lastPathComponent,
            vocabularies: vocabularies
        )
        print("✓ \(meridianURL.lastPathComponent): no errors (\(vocabularies.count) vocab\(vocabularies.count == 1 ? "" : "s") loaded)")
    } catch {
        throw reportCompilerError(error)
    }
}
