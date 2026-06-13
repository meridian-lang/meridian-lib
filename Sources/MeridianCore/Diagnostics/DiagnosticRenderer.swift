import Foundation
import MeridianRuntime

/// Renders `Diagnostic`s for humans (source snippet + caret + suggestions +
/// notes + help + `see: meridian explain`) and for machines (stable JSON).
public struct DiagnosticRenderer {

    public struct Options: Sendable {
        /// Emit ANSI color. The CLI passes `true` only when stderr is a TTY and
        /// `NO_COLOR` is unset.
        public var color: Bool
        public init(color: Bool = false) { self.color = color }
    }

    /// Full source text keyed by file name, used to draw the offending line and
    /// caret. When a file is missing the renderer degrades to a header-only form.
    private let sources: [String: String]
    private let options: Options

    public init(sources: [String: String] = [:], options: Options = .init()) {
        self.sources = sources
        self.options = options
    }

    // MARK: - Human

    public func render(_ diagnostics: [Diagnostic]) -> String {
        diagnostics.map { render($0) }.joined(separator: "\n\n")
    }

    public func render(_ d: Diagnostic) -> String {
        var out: [String] = []
        let label = severityLabel(d.severity)
        out.append("\(label)[\(d.code.id)]: \(bold(d.message))")
        out.append("  \(dim("-->")) \(d.primaryRange.file):\(d.primaryRange.startLine):\(d.primaryRange.startColumn)")

        if let snippet = snippet(for: d) {
            out.append(contentsOf: snippet)
        }

        for s in d.suggestions {
            out.append("  \(dim("=")) \(green("suggestion")): \(s.rationale)")
        }
        for n in d.notes {
            out.append("  \(dim("=")) \(cyan("note")): \(n.message)")
        }
        if let help = d.help, !help.isEmpty {
            out.append("  \(dim("=")) \(yellow("help")): \(help)")
        }
        if let decision = d.decision, let record = DecisionCatalog.lookup(decision.id) {
            out.append("  \(dim("=")) \(yellow("why")): \(firstSentence(record.rationale)) (\(decision.id))")
        }
        var see = "see: meridian explain \(d.code.id)"
        if let decision = d.decision {
            see += " · meridian explain \(decision.id)"
        }
        out.append("  \(dim("=")) \(dim(see))")
        return out.joined(separator: "\n")
    }

    /// The offending source line + a caret underline spanning the primary range.
    private func snippet(for d: Diagnostic) -> [String]? {
        guard let source = sources[d.primaryRange.file] else { return nil }
        let lines = source.components(separatedBy: "\n")
        let lineNo = d.primaryRange.startLine
        guard lineNo >= 1, lineNo <= lines.count else { return nil }
        let text = lines[lineNo - 1]
        let gutterWidth = String(lineNo).count
        let gutter = String(repeating: " ", count: gutterWidth)

        // Columns are 1-based. Clamp into range; default to whole-line caret.
        let startCol = Swift.max(1, d.primaryRange.startColumn)
        let endCol: Int = {
            if d.primaryRange.endLine == lineNo, d.primaryRange.endColumn > startCol {
                return d.primaryRange.endColumn
            }
            return text.count + 1
        }()
        let caretCount = Swift.max(1, endCol - startCol)
        let pad = String(repeating: " ", count: Swift.max(0, startCol - 1))
        let carets = String(repeating: "^", count: caretCount)
        let hint = d.suggestions.first.map { " \($0.rationale)" } ?? ""

        return [
            "  \(dim("\(gutter) |"))",
            "  \(dim("\(lineNo) |")) \(text)",
            "  \(dim("\(gutter) |")) \(pad)\(red(carets))\(red(hint))",
        ]
    }

    // MARK: - JSON

    /// Stable JSON array for editors / CI. Keys are sorted for determinism.
    public func renderJSON(_ diagnostics: [Diagnostic]) -> String {
        let array: [[String: Any]] = diagnostics.map { d in
            var obj: [String: Any] = [
                "code": d.code.id,
                "severity": d.severity.rawValue,
                "message": d.message,
                "range": rangeDict(d.primaryRange),
                "suggestions": d.suggestions.map { s -> [String: Any] in
                    var o: [String: Any] = ["replacement": s.replacement, "rationale": s.rationale]
                    if let r = s.range { o["range"] = rangeDict(r) }
                    return o
                },
                "notes": d.notes.map { n -> [String: Any] in
                    var o: [String: Any] = ["message": n.message]
                    if let r = n.range { o["range"] = rangeDict(r) }
                    return o
                },
            ]
            if let help = d.help { obj["help"] = help }
            if let decision = d.decision { obj["decision"] = decision.id }
            return obj
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: array,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ), let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func rangeDict(_ r: SourceRange) -> [String: Any] {
        [
            "file": r.file,
            "startLine": r.startLine, "startColumn": r.startColumn,
            "endLine": r.endLine, "endColumn": r.endColumn,
        ]
    }

    /// The first sentence of a rationale (for the one-line `why:` hint).
    private func firstSentence(_ s: String) -> String {
        if let dot = s.firstIndex(of: ".") {
            return String(s[..<dot]) + "."
        }
        return s
    }

    // MARK: - Color helpers

    private func severityLabel(_ s: DiagnosticSeverity) -> String {
        switch s {
        case .error: return red("error")
        case .warning: return yellow("warning")
        case .note: return cyan("note")
        }
    }

    private func wrap(_ s: String, _ code: String) -> String {
        options.color ? "\u{001B}[\(code)m\(s)\u{001B}[0m" : s
    }
    private func red(_ s: String) -> String { wrap(s, "31") }
    private func green(_ s: String) -> String { wrap(s, "32") }
    private func yellow(_ s: String) -> String { wrap(s, "33") }
    private func cyan(_ s: String) -> String { wrap(s, "36") }
    private func dim(_ s: String) -> String { wrap(s, "2") }
    private func bold(_ s: String) -> String { wrap(s, "1") }
}
