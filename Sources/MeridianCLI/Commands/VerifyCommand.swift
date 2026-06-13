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

    func run() async throws {
        try await runDiagnosticsCheck(input: input, merconfig: merconfig, trace: trace)
    }
}
