import ArgumentParser
import Foundation
import MeridianCore
import MeridianRuntime

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
                    throw cliInputNotFound(path, label: label)
                }
                return url
            }
        }
        func matches(in dir: URL) throws -> [URL] {
            try listDirectoryContents(at: dir, label: "dependency discovery directory")
                .filter { $0.pathExtension == ext }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        let dir = inputURL.deletingLastPathComponent()
        let here = try matches(in: dir)
        if !here.isEmpty { return here }
        return try matches(in: dir.deletingLastPathComponent())
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

    /// Load resolved rulebook URLs into `RulebookInput`s (name = file stem).
    static func loadRulebooks(_ urls: [URL]) throws -> [RulebookInput] {
        try urls.map { url in
            .init(name: url.deletingPathExtension().lastPathComponent,
                  file: url.lastPathComponent,
                  source: try String(contentsOf: url, encoding: .utf8))
        }
    }
}

// MARK: - Model command input loading

struct CLIModelInput {
    var meridianURL: URL
    var meridianSource: String
    var vocabularies: [Compiler.VocabularyInput]
    var rulebooks: [RulebookInput]
    var moduleSearchPaths: [URL]
    var diagnosticSources: [String: String]
}

func loadCLIModelInput(
    input: String,
    merconfig: [String],
    rulebook: [String] = [],
    modulePath: [String] = []
) throws -> CLIModelInput {
    let meridianURL = URL(fileURLWithPath: input).standardized
    guard FileManager.default.fileExists(atPath: meridianURL.path) else {
        throw cliInputNotFound(input)
    }

    let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
    let merconfigURLs = try DependencyDiscovery.resolveMerconfigs(explicit: merconfig, beside: meridianURL)
    let vocabularies = try DependencyDiscovery.loadVocabularies(merconfigURLs)
    let rulebookURLs = try DependencyDiscovery.resolveRulebooks(explicit: rulebook, beside: meridianURL)
    let rulebooks = try DependencyDiscovery.loadRulebooks(rulebookURLs)
    let moduleSearchPaths = try modulePath.map { path in
        let url = URL(fileURLWithPath: path).standardized
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw cliInputNotFound(path, label: "module-path")
        }
        return url
    }

    var diagnosticSources: [String: String] = [meridianURL.lastPathComponent: meridianSource]
    for vocabulary in vocabularies {
        diagnosticSources[vocabulary.file] = vocabulary.source
    }
    for rulebook in rulebooks {
        diagnosticSources[rulebook.file] = rulebook.source
    }

    return CLIModelInput(
        meridianURL: meridianURL,
        meridianSource: meridianSource,
        vocabularies: vocabularies,
        rulebooks: rulebooks,
        moduleSearchPaths: moduleSearchPaths,
        diagnosticSources: diagnosticSources
    )
}

/// Compile one source through the unified pipeline and return its verbalizer
/// model (the shared entry point for `explain` / `drift` / `canonicalize` /
/// `skill-deviation` / `mcp explain`).
func compiledModel(
    _ compiler: Compiler,
    _ source: String,
    _ file: String,
    _ vocabularies: [Compiler.VocabularyInput],
    _ rulebooks: [RulebookInput]
) throws -> VerbalizerModel {
    guard let compiled = try compiler.compile(Compiler.CompilationUnit(
        sources: [Compiler.SourceInput(source: source, file: file)],
        vocabularies: vocabularies,
        rulebooks: rulebooks
    ))[file] else {
        throw CompilerError.codegenError(message: "no compiled output for \(file)")
    }
    return compiled.model
}

func compiledModel(_ compiler: Compiler, _ loaded: CLIModelInput) throws -> VerbalizerModel {
    try compiledModel(compiler, loaded.meridianSource, loaded.meridianURL.lastPathComponent,
                      loaded.vocabularies, loaded.rulebooks)
}

func compilerOptions(
    for loaded: CLIModelInput,
    trace: ParserTrace,
    emitterOptions: SwiftEmitter.Options = .init()
) -> Compiler.Options {
    Compiler.Options(
        emitterOptions: emitterOptions,
        trace: trace,
        moduleSearchPaths: loaded.moduleSearchPaths,
        anchorDirectory: loaded.meridianURL.deletingLastPathComponent()
    )
}

// MARK: - Trace bootstrap

/// Output format for `ParserTrace` records on the CLI.
enum TraceFormat: String, ExpressibleByArgument, CaseIterable {
    case text
    case jsonl
}

/// Shared `--trace` / `--trace-file` / `--trace-format` options for commands
/// that bootstrap a fresh `ParserTrace` per invocation.
struct CLITraceOptions: ParsableArguments {
    init() {}

    @Option(name: .long,
            help: "Comma-separated ParserTrace categories (or `all`). Also reads MERIDIAN_TRACE.")
    var trace: String?

    @Option(name: .long, help: "Write ParserTrace output to this file instead of stderr.")
    var traceFile: String?

    @Option(name: .long,
            help: "Trace output format: text (human lines) or jsonl (one JSON object per record; each includes `corr`).")
    var traceFormat: TraceFormat = .text

    func makeTrace() throws -> ParserTrace {
        try makeCLITrace(spec: trace, file: traceFile, format: traceFormat)
    }
}

/// Build a `ParserTrace` from the CLI's `--trace` spec and optional
/// `--trace-file` sink. Single source for the bootstrap every diagnostic command
/// repeated inline.
///
/// Unknown categories and unwritable sink paths throw `ExitCode(1)` after
/// rendering a coded diagnostic (MER2010 / MER5011).
func makeCLITrace(spec: String?, file: String? = nil, format: TraceFormat = .text) throws -> ParserTrace {
    if let spec {
        let unknown = ParserTrace.validateTraceSpec(spec)
        if !unknown.isEmpty {
            let rendered = DiagnosticRenderer(sources: [:], options: .init(color: stderrIsTTY())).render(unknown)
            FileHandle.standardError.write(Data((rendered + "\n").utf8))
            throw ExitCode(1)
        }
    }
    let trace = ParserTrace()
    trace.outputFormat = format == .jsonl ? .jsonl : .text
    if let spec { trace.enable(parsing: spec) }
    if spec != nil || ParserTrace.Category.allCases.contains(where: { trace.isEnabled($0) }) {
        announceCLITrace(trace)
    }
    if let file {
        let url = URL(fileURLWithPath: file).standardized
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw reportTraceFileError(url, underlying: error)
            }
        }
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw reportTraceFileError(url, underlying: nil)
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.close()
        } catch {
            throw reportTraceFileError(url, underlying: error)
        }
        trace.sink = .file(url)
    }
    return trace
}

/// Print the trace correlation id once when tracing is active. JSONL records
/// also carry the same value in their `corr` field.
func announceCLITrace(_ trace: ParserTrace) {
    FileHandle.standardError.write(
        Data("trace correlation id: \(trace.correlationID) (JSONL records include \"corr\")\n".utf8))
}

private func reportTraceFileError(_ url: URL, underlying: Error?) -> ExitCode {
    let detail = underlying.map { ": \($0.localizedDescription)" } ?? ""
    let d = Diagnostic.error(
        .unwritableTraceFile,
        message: "cannot write trace file \(url.path)\(detail)",
        range: SourceRange(file: "<cli>", line: 1, column: 1),
        help: "Choose a writable --trace-file path, or omit --trace-file to use stderr."
    )
    let rendered = DiagnosticRenderer(sources: [:], options: .init(color: stderrIsTTY())).render([d])
    FileHandle.standardError.write(Data((rendered + "\n").utf8))
    return ExitCode(1)
}

// MARK: - CLI I/O helpers

/// List a directory's contents, failing closed with MER5014 on unexpected I/O.
func listDirectoryContents(at dir: URL, label: String = "directory") throws -> [URL] {
    do {
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    } catch {
        throw reportDirectoryReadFailed(dir, label: label, underlying: error)
    }
}

/// Autodiscover files with the given extension beside `dir`, searching up to
/// `parentLevels` ancestor directories (inclusive of `dir`).
func autodiscoverFiles(extension ext: String, from dir: URL, parentLevels: Int = 2) throws -> [URL] {
    var candidates: [URL] = []
    var candidate = dir
    for _ in 0...parentLevels {
        candidates.append(candidate)
        candidate = candidate.deletingLastPathComponent()
    }
    for url in candidates {
        let files = try listDirectoryContents(at: url, label: "autodiscovery directory")
        let matches = files
            .filter { $0.pathExtension == ext }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !matches.isEmpty { return matches }
    }
    return []
}

/// MER5014 — a directory enumerator could not be created.
func cliDirectoryEnumerationFailed(_ path: String) -> ExitCode {
    reportCLIError(Diagnostic.error(
        .directoryReadFailed,
        message: "cannot enumerate directory at \(path)",
        range: SourceRange(file: "<cli>", line: 1, column: 1),
        help: "Check directory permissions and path correctness."
    ))
}

/// Render a coded CLI diagnostic to stderr and return exit code 1.
func reportCLIError(_ diagnostic: Diagnostic) -> ExitCode {
    let rendered = DiagnosticRenderer(sources: [:], options: .init(color: stderrIsTTY())).render([diagnostic])
    FileHandle.standardError.write(Data((rendered + "\n").utf8))
    return ExitCode(1)
}

/// MER5013 — a CLI input or explicit dependency path does not exist.
func cliInputNotFound(_ path: String, label: String = "file") -> ExitCode {
    reportCLIError(Diagnostic.error(
        .inputFileNotFound,
        message: "\(label) not found: \(path)",
        range: SourceRange(file: "<cli>", line: 1, column: 1),
        help: "Check the path and try again."
    ))
}

private func reportDirectoryReadFailed(_ dir: URL, label: String, underlying: Error) -> ExitCode {
    reportCLIError(Diagnostic.error(
        .directoryReadFailed,
        message: "cannot read \(label) at \(dir.path): \(underlying.localizedDescription)",
        range: SourceRange(file: "<cli>", line: 1, column: 1),
        help: "Check directory permissions and path correctness."
    ))
}

// MARK: - Diagnostics

/// Output format for rendered diagnostics. `human` is the snippet+caret form;
/// `json` is the stable machine schema for editors / CI.
enum DiagnosticsFormat: String, ExpressibleByArgument, CaseIterable {
    case human
    case json
}

/// Print a `CompilerError` to stderr with its source anchor. Returns the exit
/// code to throw. Shared by `compile`, `check`, `verify` (and any future
/// diagnostic command) so the catch ladders never drift.
func reportCompilerError(_ error: Error, sources: [String: String] = [:],
                         format: DiagnosticsFormat = .human) -> ExitCode {
    if let compilerError = error as? CompilerError {
        let renderer = DiagnosticRenderer(sources: sources, options: .init(color: stderrIsTTY()))
        let rendered: String
        if format == .json {
            do {
                rendered = try renderer.renderJSON(compilerError.diagnostics)
            } catch {
                FileHandle.standardError.write(Data("{\"error\":\"failed to serialize diagnostics\"}\n".utf8))
                return ExitCode(1)
            }
        } else {
            rendered = renderer.render(compilerError.diagnostics)
        }
        FileHandle.standardError.write(Data((rendered + "\n").utf8))
        return ExitCode(1)
    }
    if case IRValidationError.diagnostics(let diagnostics) = error {
        let renderer = DiagnosticRenderer(sources: sources, options: .init(color: stderrIsTTY()))
        let rendered: String
        if format == .json {
            do {
                rendered = try renderer.renderJSON(diagnostics)
            } catch {
                FileHandle.standardError.write(Data("{\"error\":\"failed to serialize diagnostics\"}\n".utf8))
                return ExitCode(1)
            }
        } else {
            rendered = renderer.render(diagnostics)
        }
        FileHandle.standardError.write(Data((rendered + "\n").utf8))
        return ExitCode(1)
    }
    FileHandle.standardError.write(Data("✗ \(error)\n".utf8))
    return ExitCode(1)
}

/// Apply unambiguous quick-fixes from a `CompilerError`'s diagnostics.
///
/// SAFETY: name-resolution suggestion ranges are line/construct-level (they
/// point at the whole `invoke …` or rule line, not the misspelled token), so we
/// never blindly overwrite the range. Instead, within the suggestion's range we
/// locate the SINGLE word-token closest to the replacement (Levenshtein) and
/// replace only that token — and only when it is an unambiguous best match
/// within the edit-distance budget. This makes `--fix` incapable of corrupting
/// a line. A fix needs exactly one ranged suggestion per diagnostic. Dry-run by
/// default; pass `write: true` to mutate the files. Returns the count applied.
@discardableResult
func applyQuickFixes(_ error: Error, sources: [String: String],
                     paths: [String: URL] = [:], write: Bool) -> Int {
    guard let compilerError = error as? CompilerError else { return 0 }
    struct Edit { let line: Int; let startCol: Int; let endCol: Int; let replacement: String; let rationale: String }
    var byFile: [String: [Edit]] = [:]
    for d in compilerError.diagnostics {
        guard d.suggestions.count == 1, let s = d.suggestions.first, let r = s.range else { continue }
        byFile[r.file, default: []].append(
            Edit(line: r.startLine, startCol: r.startColumn,
                 endCol: r.endColumn > r.startColumn ? r.endColumn : r.startColumn,
                 replacement: s.replacement, rationale: s.rationale))
    }
    guard !byFile.isEmpty else {
        FileHandle.standardError.write(Data("no auto-applicable fixes (need exactly one ranged suggestion per diagnostic)\n".utf8))
        return 0
    }

    /// Within `slice` (a substring of a line), find the word-token closest to
    /// `replacement` and return its (offset, length) if it is an unambiguous
    /// best match within budget; else nil (so we skip rather than guess).
    func bestToken(in slice: [Character], replacement: String) -> (offset: Int, length: Int)? {
        var tokens: [(offset: Int, text: String)] = []
        var i = 0
        while i < slice.count {
            if slice[i].isLetter || slice[i].isNumber {
                let start = i
                while i < slice.count, slice[i].isLetter || slice[i].isNumber { i += 1 }
                tokens.append((start, String(slice[start..<i])))
            } else { i += 1 }
        }
        guard !tokens.isEmpty else { return nil }
        let budget = Suggester.defaultBudget(for: replacement)
        let scored = tokens
            .map { (tok: $0, dist: Suggester.levenshtein($0.text.lowercased(), replacement.lowercased())) }
            .sorted { $0.dist < $1.dist }
        guard let best = scored.first, best.dist <= budget else { return nil }
        // Require an unambiguous winner: either the only token, or strictly
        // closer than the runner-up.
        if scored.count > 1, scored[1].dist == best.dist { return nil }
        // Don't "fix" something already correct.
        if best.tok.text == replacement { return nil }
        return (best.tok.offset, best.tok.text.count)
    }

    var applied = 0
    var skipped = 0
    for (file, edits) in byFile.sorted(by: { $0.key < $1.key }) {
        guard var source = sources[file] else { continue }
        var lines = source.components(separatedBy: "\n")
        let sorted = edits.sorted { ($0.line, $0.startCol) > ($1.line, $1.startCol) }
        for e in sorted {
            guard e.line >= 1, e.line <= lines.count else { continue }
            var text = Array(lines[e.line - 1])
            let lo = Swift.max(0, Swift.min(e.startCol - 1, text.count))
            let hi = Swift.min(text.count, Swift.max(lo, e.endCol - 1))
            let sliceEnd = hi > lo ? hi : text.count
            let slice = Array(text[lo..<Swift.min(sliceEnd, text.count)])
            guard let tok = bestToken(in: slice, replacement: e.replacement) else { skipped += 1; continue }
            let tokLo = lo + tok.offset
            let tokHi = tokLo + tok.length
            guard tokHi <= text.count else { skipped += 1; continue }
            let before = String(text[tokLo..<tokHi])
            text.replaceSubrange(tokLo..<tokHi, with: Array(e.replacement))
            lines[e.line - 1] = String(text)
            applied += 1
            let verb = write ? "fix" : "would fix"
            FileHandle.standardError.write(Data(
                "\(verb) \(file):\(e.line):\(tokLo + 1) — \(e.rationale) (\"\(before)\" → \"\(e.replacement)\")\n".utf8))
        }
        if write {
            source = lines.joined(separator: "\n")
            let dest = paths[file] ?? URL(fileURLWithPath: file)
            do {
                try source.write(to: dest, atomically: true, encoding: .utf8)
            } catch {
                FileHandle.standardError.write(Data(
                    "failed to write fix to \(dest.path): \(error)\n".utf8))
            }
        }
    }
    if applied == 0 {
        FileHandle.standardError.write(Data("no auto-applicable fixes (\(skipped) suggestion\(skipped == 1 ? "" : "s") were ambiguous or out of budget)\n".utf8))
    } else if !write {
        FileHandle.standardError.write(Data("dry-run: re-run with --write to apply \(applied) fix\(applied == 1 ? "" : "es")\n".utf8))
    }
    return applied
}

/// True when stderr is an interactive terminal and `NO_COLOR` is unset, so the
/// renderer can safely emit ANSI color.
func stderrIsTTY() -> Bool {
    if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
    return isatty(FileHandle.standardError.fileDescriptor) != 0
}

/// Run the shared parse + lower diagnostics pass used by both `check` and
/// `verify`: load vocab + rulebooks, compile (discarding emitted Swift), and
/// report with source snippets. Throws `ExitCode(1)` on a compiler error.
func runDiagnosticsCheck(input: String, merconfig: [String], modulePath: [String] = [],
                         trace: String?,
                         traceFile: String? = nil,
                         traceFormat: TraceFormat = .text,
                         format: DiagnosticsFormat = .human,
                         fix: Bool = false, write: Bool = false) async throws {
    let loaded = try loadCLIModelInput(
        input: input, merconfig: merconfig, rulebook: [], modulePath: modulePath)
    let meridianURL = loaded.meridianURL
    let meridianSource = loaded.meridianSource
    let vocabularies = loaded.vocabularies
    let rulebookURLs = try DependencyDiscovery.resolveRulebooks(explicit: [], beside: meridianURL)
    let rulebooks: [RulebookInput] = try rulebookURLs.map {
        .init(name: $0.deletingPathExtension().lastPathComponent,
              file: $0.lastPathComponent, source: try String(contentsOf: $0, encoding: .utf8))
    }

    var diagSources = loaded.diagnosticSources
    var diagPaths: [String: URL] = [meridianURL.lastPathComponent: meridianURL]
    for vocabulary in vocabularies {
        diagPaths[vocabulary.file] = meridianURL.deletingLastPathComponent().appendingPathComponent(vocabulary.file)
    }
    for rulebook in rulebooks {
        diagSources[rulebook.file] = rulebook.source
    }

    let compiler = Compiler(options: compilerOptions(
        for: loaded, trace: try makeCLITrace(spec: trace, file: traceFile, format: traceFormat)))
    do {
        _ = try compiler.compile(Compiler.CompilationUnit(
            sources: [Compiler.SourceInput(source: meridianSource, file: meridianURL.lastPathComponent)],
            vocabularies: vocabularies,
            rulebooks: rulebooks
        ))
        print("✓ \(meridianURL.lastPathComponent): no errors (\(vocabularies.count) vocab\(vocabularies.count == 1 ? "" : "s") loaded)")
    } catch {
        if fix { applyQuickFixes(error, sources: diagSources, paths: diagPaths, write: write) }
        throw reportCompilerError(error, sources: diagSources, format: format)
    }
}
