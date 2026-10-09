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

public struct CheckCommand: AsyncParsableCommand, ModulePathSupporting {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Parse + lower a .meridian file and report diagnostics. No output is written."
    )

    @Argument(help: "Path to the .meridian file to check.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Directory searched for shared module packages. Repeatable.")
    var modulePath: [String] = []

    @OptionGroup var cliTrace: CLITraceOptions

    @Option(name: .long,
            help: "Diagnostics output format: human (snippet + caret) or json (stable schema for editors/CI).")
    var diagnosticsFormat: DiagnosticsFormat = .human

    @Flag(name: .long, help: "Preview unambiguous quick-fixes (did-you-mean replacements). Dry-run unless --write.")
    var fix: Bool = false

    @Flag(name: .long, help: "With --fix, apply the fixes to the source files in place.")
    var write: Bool = false

    public func run() async throws {
        try await runDiagnosticsCheck(input: input, merconfig: merconfig, modulePath: modulePath,
                                      trace: cliTrace.trace, traceFile: cliTrace.traceFile,
                                      traceFormat: cliTrace.traceFormat,
                                      format: diagnosticsFormat, fix: fix, write: write)
    }
}
