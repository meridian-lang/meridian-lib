import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian check`
//
// Type-check + lower a `.meridian` file without writing any Swift output.
// Surfaces parser / lowerer diagnostics with file:line:col anchors and exits
// non-zero on the first error so a CI pipeline can gate merges.
//
// Multi-vocabulary inputs use the same auto-discovery rules as `compile`:
// `--merconfig` is repeatable; if omitted, every `.merconfig` next to the
// .meridian file (or in the parent directory) is loaded.

struct CheckCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Parse + lower a .meridian file and report diagnostics. No output is written."
    )

    @Argument(help: "Path to the .meridian file to check.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: phrase, phrase.match, lowering, all.")
    var trace: String?

    func run() async throws {
        try await runDiagnosticsCheck(input: input, merconfig: merconfig, trace: trace)
    }
}
