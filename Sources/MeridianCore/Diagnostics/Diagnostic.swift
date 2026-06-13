import Foundation
import MeridianRuntime

/// Severity of a diagnostic. `error` stops a successful compile; `warning` and
/// `note` are advisory (collected and rendered, but do not by themselves fail).
public enum DiagnosticSeverity: String, Sendable, Hashable, Comparable {
    case note
    case warning
    case error

    private var rank: Int {
        switch self { case .note: return 0; case .warning: return 1; case .error: return 2 }
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// A concrete, mechanically-applicable fix. Powers `did you mean "<x>"?` and is
/// the payload `--fix` applies. A suggestion with a non-nil `range` and a
/// concrete `replacement` is auto-applicable; range-less suggestions are
/// advisory only.
public struct Suggestion: Sendable, Hashable {
    public let replacement: String
    public let range: SourceRange?
    public let rationale: String
    public init(replacement: String, range: SourceRange? = nil, rationale: String) {
        self.replacement = replacement
        self.range = range
        self.rationale = rationale
    }
}

/// A secondary, related message attached to a diagnostic (e.g. a candidate
/// list, or a pointer to where something was first declared).
public struct DiagnosticNote: Sendable, Hashable {
    public let message: String
    public let range: SourceRange?
    public init(_ message: String, range: SourceRange? = nil) {
        self.message = message
        self.range = range
    }
}

/// A structured compiler diagnostic: a stable code, a severity, a human
/// message, the primary source span, plus the remediation surface
/// (suggestions / notes / help) and the governing design decision.
public struct Diagnostic: Sendable, Hashable {
    public let code: DiagnosticCode
    public let severity: DiagnosticSeverity
    public let message: String
    public let primaryRange: SourceRange
    public let suggestions: [Suggestion]
    public let notes: [DiagnosticNote]
    public let help: String?

    /// The governing decision (if any) is carried by the code so it can never
    /// drift from the code's documentation.
    public var decision: DecisionRef? { code.decision }

    public init(code: DiagnosticCode,
                severity: DiagnosticSeverity = .error,
                message: String,
                primaryRange: SourceRange,
                suggestions: [Suggestion] = [],
                notes: [DiagnosticNote] = [],
                help: String? = nil) {
        self.code = code
        self.severity = severity
        self.message = message
        self.primaryRange = primaryRange
        self.suggestions = suggestions
        self.notes = notes
        self.help = help
    }
}

// MARK: - The always-on remediation guarantee (Pillar 3)

extension Diagnostic {

    /// The ONLY way to build a name-resolution diagnostic. Every unknown
    /// identifier/phrase/tool/kind/property/etc. funnels through here so a hint
    /// is *always* surfaced:
    ///   - within edit-distance budget → a `did you mean "<closest>"?`
    ///     suggestion (auto-applicable when `range` is given).
    ///   - nothing within budget → a candidate-list note enumerating the
    ///     available set (never a bare "unknown X").
    ///
    /// `code.kind` must be `.nameResolution` (enforced) so the guard test can
    /// rely on this funnel.
    public static func unresolved(_ code: DiagnosticCode,
                                  target: String,
                                  among candidates: [String],
                                  range: SourceRange,
                                  noun: String? = nil,
                                  help: String? = nil) -> Diagnostic {
        precondition(code.kind == .nameResolution,
                     "Diagnostic.unresolved requires a .nameResolution code, got \(code.id) (\(code.kind))")
        let what = noun ?? code.title
        let suggester = Suggester()
        let uniqueCandidates = Array(Set(candidates.filter { !$0.isEmpty })).sorted()

        if let closest = suggester.closest(target, among: uniqueCandidates) {
            return Diagnostic(
                code: code, severity: .error,
                message: "unknown \(what) \"\(target)\"",
                primaryRange: range,
                suggestions: [Suggestion(replacement: closest, range: range,
                                         rationale: "did you mean \"\(closest)\"?")],
                notes: [],
                help: help)
        }

        // Nothing close enough — never a bare "unknown X". Enumerate the set.
        let note: DiagnosticNote
        if uniqueCandidates.isEmpty {
            note = DiagnosticNote("no \(what)s are available in this scope")
        } else if uniqueCandidates.count <= 12 {
            note = DiagnosticNote("available \(what)s: \(uniqueCandidates.joined(separator: ", "))")
        } else {
            let top = suggester.ranked(target, among: uniqueCandidates, limit: 8)
            note = DiagnosticNote("closest \(what)s: \(top.joined(separator: ", ")) (\(uniqueCandidates.count) total)")
        }
        return Diagnostic(
            code: code, severity: .error,
            message: "unknown \(what) \"\(target)\"",
            primaryRange: range,
            suggestions: [],
            notes: [note],
            help: help)
    }

    /// Build a structural diagnostic. `help` is mandatory (the concrete fix) so
    /// every `.structural` code always tells the user how to resolve it.
    public static func structural(_ code: DiagnosticCode,
                                  message: String,
                                  range: SourceRange,
                                  help: String,
                                  suggestions: [Suggestion] = [],
                                  notes: [DiagnosticNote] = []) -> Diagnostic {
        precondition(code.kind == .structural,
                     "Diagnostic.structural requires a .structural code, got \(code.id) (\(code.kind))")
        precondition(!help.isEmpty, "structural diagnostic \(code.id) requires non-empty help")
        return Diagnostic(code: code, severity: .error, message: message,
                          primaryRange: range, suggestions: suggestions,
                          notes: notes, help: help)
    }

    /// Build a general (`.other`) diagnostic.
    public static func error(_ code: DiagnosticCode,
                             message: String,
                             range: SourceRange,
                             notes: [DiagnosticNote] = [],
                             help: String? = nil) -> Diagnostic {
        Diagnostic(code: code, severity: .error, message: message,
                   primaryRange: range, suggestions: [], notes: notes, help: help)
    }

    /// Build a warning (advisory; does not by itself fail a compile).
    public static func warning(_ code: DiagnosticCode,
                               message: String,
                               range: SourceRange,
                               notes: [DiagnosticNote] = [],
                               help: String? = nil) -> Diagnostic {
        Diagnostic(code: code, severity: .warning, message: message,
                   primaryRange: range, suggestions: [], notes: notes, help: help)
    }
}
