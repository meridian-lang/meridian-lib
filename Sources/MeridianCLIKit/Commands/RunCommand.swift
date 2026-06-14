import ArgumentParser
import Foundation
import MeridianCore

public struct RunCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Compile and execute a .meridian workflow in a temporary Swift package."
    )

    @Argument(help: "Path to the .meridian file to run.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. Repeatable; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long, help: "Directory where the generated Swift and manifest should be written.")
    var output: String?

    @Option(name: .long, help: "Workflow struct name to run. Defaults to the first workflow.")
    var workflow: String?

    @Option(name: .long, parsing: .singleValue,
            help: "Workflow parameter as name=JSON. Repeatable.")
    var inputJSON: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Tool stub as toolID=JSON result. Repeatable.")
    var toolStub: [String] = []

    @Option(name: .long, help: "Run ID for the temporary runtime.")
    var runID: String = "cli-run"

    @Option(name: .long, help: "Checkpoint root directory for the temporary runtime.")
    var checkpointRoot: String?

    @Flag(name: .long, help: "Keep the temporary SwiftPM package and print its path.")
    var keepTemp: Bool = false

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: phrase, lowering, all.")
    var trace: String?

    @Option(name: .long,
            help: "Diagnostics output format: human (snippet + caret) or json (stable schema for editors/CI).")
    var diagnosticsFormat: DiagnosticsFormat = .human

    public func run() async throws {
        let meridianURL = URL(fileURLWithPath: input).standardized
        guard FileManager.default.fileExists(atPath: meridianURL.path) else {
            throw ValidationError("File not found: \(input)")
        }
        let outputURL = URL(fileURLWithPath: output ?? FileManager.default.currentDirectoryPath).standardizedFileURL
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
        let merconfigURLs = try DependencyDiscovery.resolveMerconfigs(explicit: merconfig, beside: meridianURL)
        let vocabularies = try DependencyDiscovery.loadVocabularies(merconfigURLs)
        let rulebookURLs = try DependencyDiscovery.resolveRulebooks(explicit: [], beside: meridianURL)
        let rulebooks: [RulebookInput] = try rulebookURLs.map {
            .init(name: $0.deletingPathExtension().lastPathComponent,
                  file: $0.lastPathComponent, source: try String(contentsOf: $0, encoding: .utf8))
        }

        var diagSources: [String: String] = [meridianURL.lastPathComponent: meridianSource]
        for (i, url) in merconfigURLs.enumerated() { diagSources[url.lastPathComponent] = vocabularies[i].source }

        // Compile ONCE through the canonical path (engine + fallback policy +
        // rulebooks). Reuse the manifest's lowered workflows for target
        // selection — no second `.silent()` re-lower that dropped rulebooks.
        let compiler = Compiler(options: .init(trace: makeCLITrace(spec: trace)))
        let compiled: (swift: String, manifest: ManifestEmitter.Input)
        do {
            compiled = try compiler.compileWithManifest(
                meridianSource: meridianSource,
                meridianFile: meridianURL.lastPathComponent,
                vocabularies: vocabularies,
                rulebooks: rulebooks
            )
        } catch {
            throw reportCompilerError(error, sources: diagSources, format: diagnosticsFormat)
        }
        let swift = compiled.swift
        let targetWorkflow = try selectWorkflow(from: compiled.manifest.workflows)
        let stem = meridianURL.deletingPathExtension().lastPathComponent
        let swiftURL = outputURL.appendingPathComponent(stem + ".swift")
        try swift.write(to: swiftURL, atomically: true, encoding: .utf8)
        let m = compiled.manifest
        let manifest = try ManifestEmitter().emit(.init(
            sourceFiles: [meridianURL.lastPathComponent] + merconfigURLs.map(\.lastPathComponent),
            workflows: m.workflows,
            constantsDecl: m.constantsDecl,
            toolsUsed: m.toolsUsed,
            kindsUsed: m.kindsUsed,
            instancesRequired: m.instancesRequired,
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift),
            metadata: m.metadata,
            outline: m.outline,
            rules: m.rules,
            skillSections: m.skillSections,
            definitions: m.definitions,
            relations: m.relations,
            verbs: m.verbs
        ))
        try manifest.write(
            to: outputURL.appendingPathComponent(stem + ".meridian.manifest.json"),
            atomically: true,
            encoding: .utf8
        )

        let package = try SwiftPMPackageRunner.temporary(prefix: "meridian-run")
        defer { if !keepTemp { try? package.remove() } }
        try package.writeMeridianRunDriverPackage(
            repoRoot: try findRepoRoot(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)),
            generatedSource: swift,
            workflow: targetWorkflow,
            options: .init(
                inputJSON: inputJSON,
                toolStubs: toolStub,
                runID: runID,
                checkpointRoot: checkpointRoot
            )
        )

        try package.build()
        let result = try package.run(executable: "Driver")
        if keepTemp {
            FileHandle.standardError.write(Data("temporary package: \(package.packageURL.path)\n".utf8))
        }
        print(result.stdout, terminator: result.stdout.hasSuffix("\n") ? "" : "\n")
    }

    private func selectWorkflow(from workflows: [IRWorkflow]) throws -> IRWorkflow {
        if let workflow {
            guard let match = workflows.first(where: { $0.structName == workflow || $0.name == workflow }) else {
                throw ValidationError("workflow not found: \(workflow). Available: \(workflows.map(\.structName).joined(separator: ", "))")
            }
            return match
        }
        guard let first = workflows.first else {
            throw ValidationError("no workflows found")
        }
        return first
    }

    private func findRepoRoot(from start: URL) throws -> URL {
        var url = start.standardizedFileURL
        for _ in 0..<12 {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        throw ValidationError("could not locate Meridian Package.swift from \(start.path)")
    }
}
