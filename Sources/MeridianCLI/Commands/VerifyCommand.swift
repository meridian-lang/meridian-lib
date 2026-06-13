import ArgumentParser
import Foundation
import MeridianCore

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Alias for check: parse, lower, and report diagnostics without writing output."
    )

    @Argument(help: "Path to the .meridian file to verify.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: phrase, phrase.match, lowering, all.")
    var trace: String?

    @Option(name: .long,
            help: "Diagnostics output format: human (snippet + caret) or json (stable schema for editors/CI).")
    var diagnosticsFormat: DiagnosticsFormat = .human

    @Flag(name: .long, help: "Preview unambiguous quick-fixes (did-you-mean replacements). Dry-run unless --write.")
    var fix: Bool = false

    @Flag(name: .long, help: "With --fix, apply the fixes to the source files in place.")
    var write: Bool = false

    func run() async throws {
        try await runDiagnosticsCheck(input: input, merconfig: merconfig, trace: trace,
                                      format: diagnosticsFormat, fix: fix, write: write)
    }
}
