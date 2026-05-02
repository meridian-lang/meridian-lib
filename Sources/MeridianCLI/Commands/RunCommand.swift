import ArgumentParser
import Foundation
import MeridianCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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

    func run() async throws {
        let meridianURL = URL(fileURLWithPath: input).standardized
        guard FileManager.default.fileExists(atPath: meridianURL.path) else {
            throw ValidationError("File not found: \(input)")
        }
        let outputURL = URL(fileURLWithPath: output ?? FileManager.default.currentDirectoryPath).standardizedFileURL
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
        let merconfigURLs = try resolveMerconfigs(beside: meridianURL)
        let vocabularies = try merconfigURLs.map { url -> Compiler.VocabularyInput in
            .init(
                name: url.deletingPathExtension().lastPathComponent,
                file: url.lastPathComponent,
                source: try String(contentsOf: url, encoding: .utf8)
            )
        }

        let compiler = Compiler()
        let swift = try compiler.compile(
            meridianSource: meridianSource,
            meridianFile: meridianURL.lastPathComponent,
            vocabularies: vocabularies
        )
        let workflows = try lowerWorkflows(
            meridianSource: meridianSource,
            meridianFile: meridianURL.lastPathComponent,
            vocabularies: vocabularies
        )
        let targetWorkflow = try selectWorkflow(from: workflows)
        let stem = meridianURL.deletingPathExtension().lastPathComponent
        let swiftURL = outputURL.appendingPathComponent(stem + ".swift")
        try swift.write(to: swiftURL, atomically: true, encoding: .utf8)
        let manifest = try ManifestEmitter().emit(.init(
            sourceFiles: [meridianURL.lastPathComponent] + merconfigURLs.map(\.lastPathComponent),
            workflows: workflows
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

    private func resolveMerconfigs(beside meridianURL: URL) throws -> [URL] {
        if !merconfig.isEmpty {
            return try merconfig.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("merconfig not found: \(path)")
                }
                return url
            }
        }
        let dir = meridianURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let here = files.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !here.isEmpty { return here }
        let parent = dir.deletingLastPathComponent()
        let parentFiles = (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        return parentFiles.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func lowerWorkflows(
        meridianSource: String,
        meridianFile: String,
        vocabularies: [Compiler.VocabularyInput]
    ) throws -> [IRWorkflow] {
        var config = MerConfigFile()
        for input in vocabularies {
            let parsed = try MerConfigParser(trace: .silent()).parse(input.source, file: input.file)
            config = config.merging(parsed)
        }
        let symbols = SymbolTable.build(from: config, sourceFile: vocabularies.first?.file ?? "config.merconfig", trace: .silent())
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(meridianSource, file: meridianFile)
        return try ASTToIR(symbols: symbols, sourceFile: meridianFile, trace: .silent()).lower(ast)
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
