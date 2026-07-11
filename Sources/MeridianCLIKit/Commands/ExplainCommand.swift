import ArgumentParser
import Foundation
import MeridianCore

public struct ExplainCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "explain",
        abstract: "Print the canonical verbalized form of a .meridian/.meri skill."
    )

    @Argument(help: "Path to the .meridian or .meri file to explain.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. May be supplied multiple times; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules rulebook. May be supplied multiple times; auto-discovers when omitted.")
    var rulebook: [String] = []

    @Option(name: .long, help: "Comma-separated ParserTrace categories (or `all`). Also reads MERIDIAN_TRACE.")
    var trace: String?

    @Option(name: .long, help: "Write ParserTrace output to this file instead of stderr.")
    var traceFile: String?

    public func run() async throws {
        let loaded = try loadCLIModelInput(input: input, merconfig: merconfig, rulebook: rulebook)
        let traceInstance = try makeCLITrace(spec: trace, file: traceFile)
        let compiler = Compiler(options: .init(trace: traceInstance))
        do {
            let model = try compiler.compileToModel(
                meridianSource: loaded.meridianSource,
                meridianFile: loaded.meridianURL.lastPathComponent,
                vocabularies: loaded.vocabularies,
                rulebooks: loaded.rulebooks
            )
            let canonical = try traceInstance.phase("verbalize") {
                try Verbalizer(model: model, trace: traceInstance).verbalize()
            }
            // Wave 8/9 hook: attach future [OBL-...] annotations to canonical lines once obligation IDs exist.
            print(canonical)
        } catch {
            throw reportCompilerError(error, sources: loaded.diagnosticSources)
        }
    }
}
