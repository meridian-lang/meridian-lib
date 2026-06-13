import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian explain <code|decision-id>`
//
// Prints the long-form explanation for a diagnostic code (cause + fix) and the
// rationale behind the governing design decision, so "why is this an error?" is
// one command away. Also accepts a decision id directly (`meridian explain
// D-DX-5`).

struct ExplainCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Explain a diagnostic code (MERxxxx) or a design decision (D-DX-n)."
    )

    @Argument(help: "A diagnostic code (e.g. MER2002) or a decision id (e.g. D-DX-5).")
    var id: String

    func run() throws {
        let needle = id.trimmingCharacters(in: .whitespaces)

        if let code = DiagnosticCode.lookup(needle) {
            printCode(code)
            return
        }
        if let decision = DecisionCatalog.lookup(needle) {
            ExplainCommand.printDecision(decision)
            return
        }

        // Unknown id — guide the user, never a bare failure.
        var hint = ""
        let codeIDs = DiagnosticCode.all.map(\.id)
        let decisionIDs = DecisionCatalog.all.map(\.id)
        if let close = Suggester().closest(needle, among: codeIDs + decisionIDs) {
            hint = " Did you mean \(close)?"
        }
        FileHandle.standardError.write(Data(
            "unknown id '\(needle)'.\(hint)\nRun `meridian decisions` to list decisions; codes are MER0001–MER5003.\n".utf8))
        throw ExitCode(1)
    }

    private func printCode(_ code: DiagnosticCode) {
        print("\(code.id) — \(code.title)  [\(code.kind.rawValue)]\n")
        print(wrap(code.explanation))
        if let ref = code.decision, let decision = DecisionCatalog.lookup(ref.id) {
            print("\n── Why this rule exists ──\n")
            print("\(decision.id) — \(decision.title)\n")
            print(wrap(decision.rationale))
            if !decision.alternatives.isEmpty {
                print("\nAlternatives considered:")
                for a in decision.alternatives { print("  - \(a)") }
            }
            print("\nsee: meridian explain \(decision.id)")
        }
    }

    /// Soft-wrap prose to ~80 columns for terminal readability.
    private func wrap(_ text: String, width: Int = 80) -> String {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count <= width {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.joined(separator: "\n")
    }
}
