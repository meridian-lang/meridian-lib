import ArgumentParser
import Foundation
import MeridianCore

public struct ObligationsCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "obligations",
        abstract: "Emit the prover-ready obligation artifact JSON for a skill."
    )

    @Argument(help: "Path to the .meridian or .meri file.")
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

    @Option(name: .long, help: "Write JSON to this file instead of stdout.")
    var output: String?

    @Flag(name: .long, help: "Print the obligation artifact schema and exit.")
    var schema: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Omit condition/action proof IR JSON from each obligation.")
    var includeProofIR: Bool = true

    @Flag(name: .long, help: "Print a one-line obligation summary instead of full JSON.")
    var summary: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        if schema {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(ObligationSchemaDocument.current)
            print(String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        let loaded = try loadCLIModelInput(
            input: input, merconfig: merconfig, rulebook: rulebook, modulePath: modulePath)
        let traceInstance = try cliTrace.makeTrace()
        let compiler = Compiler(options: compilerOptions(for: loaded, trace: traceInstance))
        do {
            let model = try compiler.compileToModel(
                meridianSource: loaded.meridianSource,
                meridianFile: loaded.meridianURL.lastPathComponent,
                vocabularies: loaded.vocabularies,
                rulebooks: loaded.rulebooks
            )
            let document = try traceInstance.phase("obligations") {
                try ObligationDocumentBuilder.build(
                    from: model,
                    options: .init(includeProofIR: includeProofIR)
                )
            }
            if summary {
                print(ObligationDocumentBuilder.summary(document))
                return
            }
            let json = try ObligationDocumentBuilder.emitJSON(document)
            if let output {
                try json.write(to: URL(fileURLWithPath: output), atomically: true, encoding: .utf8)
            } else {
                print(json)
            }
        } catch {
            throw reportCompilerError(error, sources: loaded.diagnosticSources)
        }
    }
}
