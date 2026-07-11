import Foundation

/// Collects diagnostics across a single file's compile so one run can report
/// *many* errors (rustc/Elm-style) instead of aborting on the first. Recovery
/// is coarse-grained — a pipeline loop skips the offending construct (workflow,
/// rule, statement) and continues — so cascades are structurally avoided rather
/// than resynced at the token level.
///
/// Lifetime: **per-compile (per-file)**. `Compiler.lowerAndEmit` creates one at
/// the top of each file's pipeline; `compileSkillpack` gives each file its own
/// engine. The engine is single-threaded within one file's pipeline, so no
/// locking is required. `Diagnostic` values are `Sendable`; the engine itself
/// is intentionally not shared across files.
public final class DiagnosticEngine {

    public private(set) var diagnostics: [Diagnostic] = []
    public private(set) var skippedConstructs: [String] = []
    private let trace: ParserTrace
    private var skipSummaryAppended = false

    public init(trace: ParserTrace = .shared) {
        self.trace = trace
    }

    /// Record a diagnostic and mirror it into the `.diagnostics` trace stream
    /// (also bumping the trace's diagnostic counter for the compile profile).
    public func report(_ d: Diagnostic) {
        diagnostics.append(d)
        trace.recordDiagnostic("\(d.severity.rawValue) \(d.code.id) @\(d.primaryRange): \(d.message)")
        for s in d.suggestions {
            trace.log(.diagnostics, "  suggestion: \(s.rationale)")
        }
        for n in d.notes {
            trace.log(.diagnostics, "  note: \(n.message)")
        }
    }

    public func report(_ ds: [Diagnostic]) { ds.forEach(report) }

    /// Project a thrown `CompilerError` into diagnostics and collect them. Used
    /// by recovery boundaries that wrap a still-throwing sub-pipeline.
    public func collect(_ error: CompilerError) { report(error.diagnostics) }

    public var errors: [Diagnostic] { diagnostics.filter { $0.severity == .error } }
    public var warnings: [Diagnostic] { diagnostics.filter { $0.severity == .warning } }
    public var hasErrors: Bool { diagnostics.contains { $0.severity == .error } }

    /// If any error-severity diagnostics were collected, throw them as a single
    /// aggregated `CompilerError.diagnostics` (preserving warnings/notes in the
    /// payload for rendering). Warnings alone never throw.
    public func throwIfErrors() throws {
        if hasErrors {
            if !skipSummaryAppended, let summary = skipSummaryNote() {
                report(summary)
                skipSummaryAppended = true
            }
            throw CompilerError.diagnostics(diagnostics)
        }
    }

    public func skipSummaryNote() -> Diagnostic? {
        guard !skippedConstructs.isEmpty else { return nil }
        let unique = Array(Set(skippedConstructs)).sorted()
        let noun = skippedConstructs.count == 1 ? "construct" : "constructs"
        let contexts = unique.joined(separator: ", ")
        return Diagnostic.warning(
            .diagnosticRecoverySummary,
            message: "\(skippedConstructs.count) \(noun) skipped while collecting errors",
            range: .unknown,
            notes: [DiagnosticNote("skipped contexts: \(contexts)")],
            help: "Fix the primary diagnostics first; skipped constructs are not emitted in this compile result.")
    }

    /// Run `body`, catching a thrown `CompilerError`, collecting its diagnostics,
    /// and returning `nil` so the caller can skip the failed construct and
    /// continue. Non-`CompilerError` throws are re-thrown (true bugs).
    @discardableResult
    public func recovering<T>(_ body: () throws -> T) throws -> T? {
        try recovering(context: "construct", body)
    }

    /// Run `body`, collecting a thrown `CompilerError` and recording the skipped
    /// construct context so the final diagnostic payload explains recovery.
    @discardableResult
    public func recovering<T>(context: String, _ body: () throws -> T) throws -> T? {
        do {
            return try body()
        } catch let error as CompilerError {
            let start = diagnostics.count
            collect(error)
            skippedConstructs.append(context)
            attachRecoveryNote(context: context, diagnosticsStart: start)
            return nil
        }
    }

    private func attachRecoveryNote(context: String, diagnosticsStart: Int) {
        guard diagnostics.count > diagnosticsStart else { return }
        let idx = diagnostics.index(before: diagnostics.endIndex)
        let existing = diagnostics[idx]
        let note = DiagnosticNote("skipped \(context) after this diagnostic so compilation could continue collecting errors")
        diagnostics[idx] = Diagnostic(
            code: existing.code,
            severity: existing.severity,
            message: existing.message,
            primaryRange: existing.primaryRange,
            suggestions: existing.suggestions,
            notes: existing.notes + [note],
            help: existing.help)
        trace.log(.diagnostics, "  note: \(note.message)")
    }
}
