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
        let rendered = format == .json
            ? renderer.renderJSON(compilerError.diagnostics)
            : renderer.render(compilerError.diagnostics)
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
            try? source.write(to: dest, atomically: true, encoding: .utf8)
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
func runDiagnosticsCheck(input: String, merconfig: [String], trace: String?,
                         format: DiagnosticsFormat = .human,
                         fix: Bool = false, write: Bool = false) async throws {
    let meridianURL = URL(fileURLWithPath: input).standardized
    guard FileManager.default.fileExists(atPath: meridianURL.path) else {
        throw ValidationError("File not found: \(input)")
    }
    let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
    let merconfigURLs = try DependencyDiscovery.resolveMerconfigs(explicit: merconfig, beside: meridianURL)
    let vocabularies = try DependencyDiscovery.loadVocabularies(merconfigURLs)
    let rulebookURLs = try DependencyDiscovery.resolveRulebooks(explicit: [], beside: meridianURL)
    let rulebooks: [RulebookInput] = try rulebookURLs.map {
        .init(name: $0.deletingPathExtension().lastPathComponent,
              file: $0.lastPathComponent, source: try String(contentsOf: $0, encoding: .utf8))
    }

    var diagSources: [String: String] = [meridianURL.lastPathComponent: meridianSource]
    var diagPaths: [String: URL] = [meridianURL.lastPathComponent: meridianURL]
    for (i, url) in merconfigURLs.enumerated() {
        diagSources[url.lastPathComponent] = vocabularies[i].source
        diagPaths[url.lastPathComponent] = url
    }
    for (i, url) in rulebookURLs.enumerated() {
        diagSources[url.lastPathComponent] = rulebooks[i].source
        diagPaths[url.lastPathComponent] = url
    }

    let compiler = Compiler(options: .init(trace: makeCLITrace(spec: trace)))
    do {
        _ = try compiler.compileWithManifest(
            meridianSource: meridianSource,
            meridianFile: meridianURL.lastPathComponent,
            vocabularies: vocabularies,
            rulebooks: rulebooks
        )
        print("✓ \(meridianURL.lastPathComponent): no errors (\(vocabularies.count) vocab\(vocabularies.count == 1 ? "" : "s") loaded)")
    } catch {
        if fix { applyQuickFixes(error, sources: diagSources, paths: diagPaths, write: write) }
        throw reportCompilerError(error, sources: diagSources, format: format)
    }
}
