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
    private let trace: ParserTrace

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
            throw CompilerError.diagnostics(diagnostics)
        }
    }

    /// Run `body`, catching a thrown `CompilerError`, collecting its diagnostics,
    /// and returning `nil` so the caller can skip the failed construct and
    /// continue. Non-`CompilerError` throws are re-thrown (true bugs).
    @discardableResult
    public func recovering<T>(_ body: () throws -> T) throws -> T? {
        do {
            return try body()
        } catch let error as CompilerError {
            collect(error)
            return nil
        }
    }
}
