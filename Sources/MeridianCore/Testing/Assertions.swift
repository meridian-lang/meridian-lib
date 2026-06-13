import Foundation
import MeridianRuntime

// MARK: - IRPrimitiveKind

/// The 10 IR primitive kinds, used in `expect_primitive_count` assertions.
public enum IRPrimitiveKind: String, Sendable, CaseIterable {
    case invoke, bind, branch, emit, complete, wait, iterate, assert, commit, recover, simultaneously, proseStep
}

// MARK: - CompileErrorKind

/// The class of compile-time error a spec can assert on.
public enum CompileErrorKind: String, Sendable {
    case syntax, semantic, codegen
}

// MARK: - Assertion

/// Every assertion a `.meridian.test` spec can place on its compiler output.
/// Assertions are evaluated independently; a spec collects all failures.
public enum Assertion: Sendable {

    // MARK: Swift-output assertions
    case swiftContains(String)
    case swiftNotContains(String)
    /// Extended regex pattern matched against the full Swift output.
    case swiftMatches(String)
    /// Full byte-for-byte comparison against an on-disk golden file.
    case goldenSwift(path: String)
    case swiftLineCountMin(Int)
    case swiftLineCountMax(Int)

    // MARK: IR-level assertions
    case workflowCount(Int)
    case workflowNamed(String)
    case noUnresolved
    case invokeToolID(String)
    case emitEventID(String)
    case primitiveCount(IRPrimitiveKind, Int)
    case workflowMode(structName: String, mode: ExecutionMode)

    // MARK: Manifest
    case goldenManifest(path: String)

    // MARK: Formatter
    case formatterIdempotent

    // MARK: Trace
    case traceContains(String)

    // MARK: Error assertions (only evaluated when expect_compile: fail)
    case errorKind(CompileErrorKind)
    case errorContains(String)
    case errorLine(Int)
}

// MARK: - AssertionContext

/// Everything the evaluator needs to evaluate any assertion.
public struct AssertionContext: Sendable {
    public let swift: String?
    public let workflows: [IRWorkflow]?
    public let traceLines: [String]
    public let baseDir: URL
    /// The original .meridian source (used for formatter idempotence check).
    public let meridianSource: String
    public let verbose: Bool
    /// Set when `expect_compile: fail` and the compiler threw.
    public let compileError: CompilerError?
    /// When `updateGolden` is true, golden mismatches overwrite the golden file.
    public let updateGolden: Bool

    public init(
        swift: String?,
        workflows: [IRWorkflow]?,
        traceLines: [String],
        baseDir: URL,
        meridianSource: String,
        verbose: Bool,
        compileError: CompilerError?,
        updateGolden: Bool
    ) {
        self.swift = swift
        self.workflows = workflows
        self.traceLines = traceLines
        self.baseDir = baseDir
        self.meridianSource = meridianSource
        self.verbose = verbose
        self.compileError = compileError
        self.updateGolden = updateGolden
    }
}

// MARK: - Evaluator

/// Evaluate one assertion against its context.
/// Returns `nil` on success, or a human-readable failure reason string.
public func evaluate(_ assertion: Assertion, in ctx: AssertionContext) -> String? {
    switch assertion {

    // MARK: Swift-output

    case .swiftContains(let text):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        if swift.contains(text) { return nil }
        return "expected Swift to contain:\n  \(text)"

    case .swiftNotContains(let text):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        if !swift.contains(text) { return nil }
        return "expected Swift NOT to contain:\n  \(text)"

    case .swiftMatches(let pattern):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return "invalid regex pattern: \(pattern)"
        }
        let range = NSRange(swift.startIndex..., in: swift)
        if regex.firstMatch(in: swift, range: range) != nil { return nil }
        return "Swift output did not match regex: \(pattern)"

    case .goldenSwift(let relativePath):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        let url = resolve(relativePath, from: ctx.baseDir)
        return evaluateGolden(actual: swift, goldenURL: url, label: "Swift", verbose: ctx.verbose, update: ctx.updateGolden)

    case .swiftLineCountMin(let n):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        let count = swift.components(separatedBy: "\n").count
        if count >= n { return nil }
        return "Swift output has \(count) lines, expected at least \(n)"

    case .swiftLineCountMax(let n):
        guard let swift = ctx.swift else { return "no Swift output (compile failed?)" }
        let count = swift.components(separatedBy: "\n").count
        if count <= n { return nil }
        return "Swift output has \(count) lines, expected at most \(n)"

    // MARK: IR-level

    case .workflowCount(let expected):
        let workflows = ctx.workflows ?? []
        if workflows.count == expected { return nil }
        return "expected \(expected) workflow(s), found \(workflows.count)"

    case .workflowNamed(let structName):
        let workflows = ctx.workflows ?? []
        if workflows.contains(where: { $0.structName == structName }) { return nil }
        let found = workflows.map(\.structName).joined(separator: ", ")
        return "no workflow named '\(structName)' (found: \(found.isEmpty ? "none" : found))"

    case .noUnresolved:
        let workflows = ctx.workflows ?? []
        let prims = IRWalker.flatPrimitives(workflows: workflows)
        let bad = prims.compactMap { prim -> String? in
            if case .bind(let b) = prim, b.name == "_unresolved" { return b.name }
            return nil
        }
        if bad.isEmpty { return nil }
        return "found \(bad.count) _unresolved bind(s) in IR"

    case .invokeToolID(let toolID):
        let workflows = ctx.workflows ?? []
        let prims = IRWalker.flatPrimitives(workflows: workflows)
        let found = prims.contains { prim in
            if case .invoke(let inv) = prim { return inv.toolID == toolID }
            return false
        }
        if found { return nil }
        return "no InvokeIR with toolID '\(toolID)' found in IR"

    case .emitEventID(let eventID):
        let workflows = ctx.workflows ?? []
        let prims = IRWalker.flatPrimitives(workflows: workflows)
        let found = prims.contains { prim in
            if case .emit(let em) = prim { return em.eventID == eventID }
            return false
        }
        if found { return nil }
        return "no EmitIR with eventID '\(eventID)' found in IR"

    case .primitiveCount(let kind, let expected):
        let workflows = ctx.workflows ?? []
        let count = IRWalker.count(kind: kind, in: workflows)
        if count == expected { return nil }
        return "expected \(expected) '\(kind.rawValue)' primitive(s), found \(count)"

    case .workflowMode(let structName, let mode):
        let workflows = ctx.workflows ?? []
        guard let wf = workflows.first(where: { $0.structName == structName }) else {
            return "no workflow named '\(structName)' to check mode"
        }
        if wf.mode == mode { return nil }
        let got = wf.mode == .strict ? "strict" : "lenient"
        let want = mode == .strict ? "strict" : "lenient"
        return "workflow '\(structName)' has mode '\(got)', expected '\(want)'"

    // MARK: Manifest

    case .goldenManifest(let relativePath):
        guard let workflows = ctx.workflows else { return "no IR (compile failed?)" }
        let manifest: String
        do {
            let input = ManifestEmitter.Input(workflows: workflows)
            manifest = try ManifestEmitter().emit(input)
        } catch {
            return "manifest emit error: \(error)"
        }
        let url = resolve(relativePath, from: ctx.baseDir)
        return evaluateGolden(actual: manifest, goldenURL: url, label: "manifest", verbose: ctx.verbose, update: ctx.updateGolden)

    // MARK: Formatter

    case .formatterIdempotent:
        let fmt = MeridianFormatter()
        let once = fmt.format(ctx.meridianSource)
        let twice = fmt.format(once)
        if once != ctx.meridianSource {
            return "source is not already formatted (formatter changed it)"
        }
        if twice != once {
            return "formatter is not idempotent (format(format(s)) != format(s))"
        }
        return nil

    // MARK: Trace

    case .traceContains(let substr):
        if ctx.traceLines.contains(where: { $0.contains(substr) }) { return nil }
        return "trace did not contain: \(substr)"

    // MARK: Error assertions

    case .errorKind(let expected):
        switch ctx.compileError {
        case .syntaxError: return expected == .syntax ? nil : "expected \(expected.rawValue) error, got syntax"
        case .semanticError: return expected == .semantic ? nil : "expected \(expected.rawValue) error, got semantic"
        case .codegenError: return expected == .codegen ? nil : "expected \(expected.rawValue) error, got codegen"
        case .notImplemented: return expected == .codegen ? nil : "expected \(expected.rawValue) error, got notImplemented"
        case .diagnostics:
            let got = diagnosticErrorKind(ctx.compileError!)
            return got == expected ? nil : "expected \(expected.rawValue) error, got \(got.rawValue)"
        case nil: return "expected a compile error of kind '\(expected.rawValue)' but compile succeeded"
        }

    case .errorContains(let substr):
        guard let err = ctx.compileError else {
            return "expected a compile error containing '\(substr)' but compile succeeded"
        }
        let msg = errorMessage(err)
        if msg.contains(substr) { return nil }
        return "compile error message '\(msg)' does not contain '\(substr)'"

    case .errorLine(let expected):
        guard let err = ctx.compileError else {
            return "expected a compile error at line \(expected) but compile succeeded"
        }
        if let got = errorLine(err) {
            if got == expected { return nil }
            return "compile error is at line \(got), expected \(expected)"
        }
        return "compile error has no source line information (expected line \(expected))"
    }
}

// MARK: - Helpers

private func resolve(_ path: String, from baseDir: URL) -> URL {
    URL(fileURLWithPath: path, relativeTo: baseDir).standardized
}

private func errorMessage(_ err: CompilerError) -> String {
    switch err {
    case .syntaxError(let msg, _): return msg
    case .semanticError(let msg, _): return msg
    case .codegenError(let msg): return msg
    case .notImplemented(let msg): return msg
    case .diagnostics(let ds):
        // Include the message plus any note text so `errorContains` keeps
        // matching candidate-list hints (e.g. an available-set enumeration).
        return ds.map { d in
            ([d.message] + d.notes.map(\.message) + d.suggestions.map(\.rationale))
                .joined(separator: " ")
        }.joined(separator: " ")
    }
}

private func errorLine(_ err: CompilerError) -> Int? {
    switch err {
    case .syntaxError(_, let r): return r.startLine > 0 ? r.startLine : nil
    case .semanticError(_, let r): return r.startLine > 0 ? r.startLine : nil
    case .codegenError, .notImplemented: return nil
    case .diagnostics(let ds):
        guard let r = ds.first?.primaryRange else { return nil }
        return r.startLine > 0 ? r.startLine : nil
    }
}

/// Map a `.diagnostics` error to the legacy `CompileErrorKind` for
/// `expect_error_kind` assertions: codegen for `MER4xxx`, syntax for `MER1xxx`
/// / `MER0002`, semantic otherwise.
private func diagnosticErrorKind(_ err: CompilerError) -> CompileErrorKind {
    guard let code = err.diagnostics.first?.code.id else { return .semantic }
    if code.hasPrefix("MER4") { return .codegen }
    if code.hasPrefix("MER1") || code == "MER0002" { return .syntax }
    return .semantic
}

private func evaluateGolden(
    actual: String,
    goldenURL: URL,
    label: String,
    verbose: Bool,
    update: Bool
) -> String? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: goldenURL.path) else {
        if update {
            do {
                try actual.write(to: goldenURL, atomically: true, encoding: .utf8)
                return nil
            } catch {
                return "could not create golden \(label) file at \(goldenURL.lastPathComponent): \(error)"
            }
        }
        return "golden \(label) not found: \(goldenURL.path)"
    }
    let golden: String
    do { golden = try String(contentsOf: goldenURL, encoding: .utf8) }
    catch { return "failed to read golden \(label): \(error)" }

    if golden == actual { return nil }

    if update {
        do {
            try actual.write(to: goldenURL, atomically: true, encoding: .utf8)
            return nil
        } catch {
            return "golden mismatch and could not overwrite \(goldenURL.lastPathComponent): \(error)"
        }
    }

    if verbose {
        return MeridianTestRunner.shortDiff(actual: actual, expected: golden)
    }
    return "\(label) output differs from golden \(goldenURL.lastPathComponent); run with --verbose for diff"
}
