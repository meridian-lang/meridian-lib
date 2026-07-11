import ArgumentParser
import Foundation
import MeridianCore

public struct LintCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Report Meridian authoring diagnostics without compiling."
    )

    @Argument(help: "Path to a .meridian file.")
    var input: String

    @Option(name: [.customLong("format"), .customLong("diagnostics-format")],
            help: "Diagnostics output format: human (snippet + caret) or json (stable schema for editors/CI).")
    var diagnosticsFormat: DiagnosticsFormat = .human

    public func run() throws {
        let source = try String(contentsOfFile: input, encoding: .utf8)
        let diagnostics = MeridianLinter().lint(source: source, file: input)
        if !diagnostics.isEmpty {
            let renderer = DiagnosticRenderer(
                sources: [input: source],
                options: .init(color: stderrIsTTY())
            )
            let rendered = diagnosticsFormat == .json
                ? renderer.renderJSON(diagnostics)
                : renderer.render(diagnostics)
            FileHandle.standardError.write(Data((rendered + "\n").utf8))
        }
        if diagnostics.contains(where: { $0.severity == .error }) {
            throw ExitCode.failure
        }
    }
}
