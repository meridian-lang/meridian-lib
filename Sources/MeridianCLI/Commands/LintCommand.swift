import ArgumentParser
import Foundation
import MeridianCore

struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Report Meridian authoring diagnostics without compiling."
    )

    @Argument(help: "Path to a .meridian file.")
    var input: String

    func run() throws {
        let source = try String(contentsOfFile: input, encoding: .utf8)
        let diagnostics = MeridianLinter().lint(source: source, file: input)
        for diag in diagnostics {
            let hint = diag.hint.map { " hint: \($0)" } ?? ""
            print("\(input):\(diag.line): \(diag.severity): \(diag.message)\(hint)")
        }
        if diagnostics.contains(where: { $0.severity == "error" }) {
            throw ExitCode.failure
        }
    }
}
