import Foundation
import MeridianRuntime

/// Inform-style diagnostic wording: reading, problem, expectations, rewrite.
public struct ProblemMessage: Sendable, Equatable {
    public let read: String
    public let reading: String
    public let problem: String
    public let expectations: [String]
    public let rewrite: String

    public init(
        read: String,
        reading: String,
        problem: String,
        expectations: [String],
        rewrite: String
    ) {
        self.read = read
        self.reading = reading
        self.problem = problem
        self.expectations = expectations
        self.rewrite = rewrite
    }

    public var message: String {
        let expectationText = expectations.isEmpty
            ? "I expected a supported Meridian form"
            : "I expected " + expectations.joined(separator: ", ")
        return "I read '\(read)' as \(reading), but \(problem). \(expectationText)."
    }

    public var help: String {
        "Rewrite as: \(rewrite)"
    }
}

public extension Diagnostic {
    static func problem(
        _ code: DiagnosticCode,
        range: SourceRange,
        read: String,
        as reading: String,
        but problem: String,
        expected expectations: [String],
        rewrite: String,
        notes: [DiagnosticNote] = []
    ) -> Diagnostic {
        let template = ProblemMessage(
            read: read,
            reading: reading,
            problem: problem,
            expectations: expectations,
            rewrite: rewrite
        )
        return Diagnostic(
            code: code,
            severity: .error,
            message: template.message,
            primaryRange: range,
            notes: notes,
            help: template.help
        )
    }
}

/// Generated reference for active problem-message codes.
public enum ProblemMessageCatalog {
    public static func renderMarkdown() -> String {
        var lines = [
            "# Meridian Problem Messages",
            "",
            "Generated from `DiagnosticCode.catalog`.",
            "",
            "| Code | Title | Kind | Help Required |",
            "|---|---|---|---|",
        ]
        for entry in DiagnosticCode.catalog where entry.status == .active {
            let help = entry.code.kind == .structural ? "yes" : "recommended"
            lines.append("| `\(entry.code.id)` | \(entry.code.title) | \(entry.code.kind.rawValue) | \(help) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
