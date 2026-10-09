import ArgumentParser
import Foundation
import MeridianCore

public struct ExplainCommand: AsyncParsableCommand, ModulePathSupporting {
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

    @Option(name: .long, parsing: .singleValue,
            help: "Directory searched for shared module packages. Repeatable.")
    var modulePath: [String] = []

    @Flag(name: .long, help: "Omit [OBL-…] norm id annotations from canonical output.")
    var noNormIDs: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        let loaded = try loadCLIModelInput(
            input: input, merconfig: merconfig, rulebook: rulebook, modulePath: modulePath)
        let traceInstance = try cliTrace.makeTrace()
        let compiler = Compiler(options: compilerOptions(for: loaded, trace: traceInstance))
        do {
            let model = try compiledModel(compiler, loaded)
            let canonical = try traceInstance.phase("verbalize") {
                try traceInstance.run {
                    try Verbalizer(model: model)
                        .verbalize(annotateNormIDs: !noNormIDs)
                }
            }
            print(canonical)
        } catch {
            throw reportCompilerError(error, sources: loaded.diagnosticSources)
        }
    }
}
