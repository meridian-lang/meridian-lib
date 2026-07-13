import ArgumentParser
import Foundation
import MeridianCore
import MeridianRuntime
import SwiftFormat

public struct CompileCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "compile",
        abstract: "Compile a .meridian file to Swift source."
    )

    @Argument(help: "Path to the .meridian file to compile.")
    var input: String

    @Option(name: .shortAndLong, help: "Output directory for generated Swift.")
    var output: String = "build"

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. May be supplied multiple times for multi-vocabulary compilation. If omitted, every .merconfig in the input's directory (or its parent) is auto-loaded.")
    var merconfig: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules rulebook. Repeatable. If omitted, every .merrules in the input's directory (or its parent) is auto-loaded.")
    var rulebook: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Directory searched for shared module packages (`<path>/<name>/module.merconfig`). Repeatable.")
    var modulePath: [String] = []

    @Option(name: .long,
            help: "Wrap all generated declarations in `public enum <name> { … }` so independently-compiled files can share one Swift module without colliding. Defaults to `auto` (derive the name from the input file stem). Pass `none` to emit flat top-level declarations.")
    var namespace: String = "auto"

    @Flag(name: .long, help: "Include timestamp in generated file header.")
    var timestamp: Bool = false

    @Flag(name: .long, help: "Suppress source-line comments in generated code.")
    var noLineComments: Bool = false

    @Flag(name: .long, help: "Skip swift-format formatting of generated code.")
    var noFormat: Bool = false

    @Flag(name: .long, help: "Emit domain and workflow Swift as separate files (`Domain.swift`, `Workflows.swift`).")
    var multiFile: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    @Option(name: .long,
            help: "Diagnostics output format: human (snippet + caret) or json (stable schema for editors/CI).")
    var diagnosticsFormat: DiagnosticsFormat = .human

    @Flag(name: .long, help: "Preview unambiguous quick-fixes for diagnostics (did-you-mean replacements). Dry-run unless --write.")
    var fix: Bool = false

    @Flag(name: .long, help: "With --fix, apply the fixes to the source files in place.")
    var write: Bool = false

    public func run() async throws {
        let meridianURL  = URL(fileURLWithPath: input).standardized
        let outputURL    = URL(fileURLWithPath: output).standardized

        guard FileManager.default.fileExists(atPath: meridianURL.path) else {
            throw cliInputNotFound(input)
        }

        let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)

        // Multi-vocabulary: load every .merconfig the user listed (or, when
        // they listed none, autodiscover them next to the .meridian source).
        let merconfigURLs = try resolveMerconfigs(beside: meridianURL)
        var vocabularies: [Compiler.VocabularyInput] = []
        for url in merconfigURLs {
            let src = try String(contentsOf: url, encoding: .utf8)
            let name = url.deletingPathExtension().lastPathComponent
            vocabularies.append(.init(name: name, file: url.lastPathComponent, source: src))
        }

        // Rulebooks (.merrules): explicit list, else autodiscovered beside the
        // source. A skill file referencing `rulebook:` in frontmatter needs the
        // matching .merrules loaded here for its idioms/sections to lower.
        let rulebookURLs = try resolveRulebooks(beside: meridianURL)
        var rulebooks: [RulebookInput] = []
        for url in rulebookURLs {
            let src = try String(contentsOf: url, encoding: .utf8)
            rulebooks.append(.init(name: url.deletingPathExtension().lastPathComponent,
                                   file: url.lastPathComponent, source: src))
        }

        let moduleSearchPaths = try modulePath.map { path in
            let url = URL(fileURLWithPath: path).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw cliInputNotFound(path, label: "module-path")
            }
            return url
        }

        let traceInstance = try cliTrace.makeTrace()

        let resolvedNamespace: String?
        switch namespace.lowercased() {
        case "none", "off", "false", "":
            resolvedNamespace = nil
        case "auto":
            resolvedNamespace = IdentifierNaming.swiftTypeNameFromStem(meridianURL.deletingPathExtension().lastPathComponent)
        default:
            resolvedNamespace = namespace
        }
        let compilerOpts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: timestamp,
                sourceFileName: meridianURL.lastPathComponent,
                emitSourceLineComments: !noLineComments,
                namespaceEnum: resolvedNamespace
            ),
            trace: traceInstance,
            moduleSearchPaths: moduleSearchPaths,
            anchorDirectory: meridianURL.deletingLastPathComponent(),
            emitMultiFile: multiFile
        )
        let compiler = Compiler(options: compilerOpts)

        // Source map for rendering diagnostics with snippets/carets, keyed by the
        // basename the compiler stamps into each SourceRange.
        var diagSources: [String: String] = [meridianURL.lastPathComponent: meridianSource]
        var diagPaths: [String: URL] = [meridianURL.lastPathComponent: meridianURL]
        for (i, url) in merconfigURLs.enumerated() {
            diagSources[url.lastPathComponent] = vocabularies[i].source
            diagPaths[url.lastPathComponent] = url
        }
        for (i, url) in rulebookURLs.enumerated() {
            diagSources[url.lastPathComponent] = rulebooks[i].source
            diagPaths[url.lastPathComponent] = url
        }

        let compiled: (swift: String, multiFile: SwiftEmitter.MultiFileOutput?, manifest: ManifestEmitter.Input)
        do {
            compiled = try compiler.compileWithManifest(
                meridianSource: meridianSource,
                meridianFile:   meridianURL.lastPathComponent,
                vocabularies:   vocabularies,
                rulebooks:      rulebooks
            )
        } catch {
            if fix { applyQuickFixes(error, sources: diagSources, paths: diagPaths, write: write) }
            throw reportCompilerError(error, sources: diagSources, format: diagnosticsFormat)
        }
        var swift = compiled.swift

        // D-DX-3: swift-format failure is cosmetic — keep the valid unformatted
        // Swift and surface a warning, never fail the compile or drop it silently.
        if !noFormat {
            do {
                swift = try format(swift)
            } catch let formatError {
                let outName = meridianURL.deletingPathExtension().lastPathComponent + ".swift"
                let warn = Diagnostic.warning(
                    .swiftFormatFailed,
                    message: "swift-format failed; writing unformatted Swift (\(formatError))",
                    range: SourceRange(file: outName, line: 1, column: 1),
                    help: "Install swift-format or pass `--no-format`; the emitted Swift is still valid.")
                let renderer = DiagnosticRenderer(sources: diagSources, options: .init(color: stderrIsTTY()))
                let rendered: String
                if diagnosticsFormat == .json {
                    rendered = try renderer.renderJSON([warn])
                } else {
                    rendered = renderer.render([warn])
                }
                FileHandle.standardError.write(Data((rendered + "\n").utf8))
            }
        }

        // Write output
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let stem = meridianURL.deletingPathExtension().lastPathComponent
        if multiFile, let split = compiled.multiFile {
            let domainFile = outputURL.appendingPathComponent("Domain.swift")
            let workflowsFile = outputURL.appendingPathComponent("Workflows.swift")
            try split.domainSource.write(to: domainFile, atomically: true, encoding: .utf8)
            try split.workflowsSource.write(to: workflowsFile, atomically: true, encoding: .utf8)
            print("✓ \(domainFile.path)")
            print("✓ \(workflowsFile.path)")
        } else {
            let outFile = outputURL.appendingPathComponent(stem + ".swift")
            try swift.write(to: outFile, atomically: true, encoding: .utf8)
            print("✓ \(outFile.path)")
        }

        // Write the COMPLETE manifest the compiler assembled (workflows,
        // metadata, outline, recorded sections), merging in the source map
        // derived from the generated Swift. No more thin `workflows: []` stub.
        let m = compiled.manifest
        let manifest = try ManifestEmitter(trace: traceInstance).emit(.init(
            sourceFiles: [meridianURL.lastPathComponent] + merconfigURLs.map(\.lastPathComponent),
            workflows: m.workflows,
            constantsDecl: m.constantsDecl,
            toolsUsed: m.toolsUsed,
            kindsUsed: m.kindsUsed,
            instancesRequired: m.instancesRequired,
            // Recompute from the *written* (possibly formatted) Swift so the
            // swift_line numbers match the file on disk. Reuses the shared
            // Compiler helper (single source of truth for the `// L` parsing).
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift),
            metadata: m.metadata,
            outline: m.outline,
            rules: m.rules,
            skillSections: m.skillSections,
            definitions: m.definitions,
            relations: m.relations,
            verbs: m.verbs
        ))
        let manifestFile = outputURL.appendingPathComponent(stem + ".meridian.manifest.json")
        try manifest.write(to: manifestFile, atomically: true, encoding: .utf8)

        let model = try compiler.compileToModel(
            meridianSource: meridianSource,
            meridianFile: meridianURL.lastPathComponent,
            vocabularies: vocabularies,
            rulebooks: rulebooks
        )
        let sidecar = try IRSidecarEmitter(trace: traceInstance).emit(
            workflows: model.workflows,
            verbalizer: Verbalizer(model: model, trace: traceInstance),
            sourceFile: meridianURL.lastPathComponent,
            swiftFile: stem + ".swift",
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift)
        )
        let sidecarFile = outputURL.appendingPathComponent(stem + ".meridian.ir.json")
        try sidecar.write(to: sidecarFile, atomically: true, encoding: .utf8)

        print("✓ \(manifestFile.path)")
        print("✓ \(sidecarFile.path)")
    }

    // MARK: - Helpers

    private func resolveMerconfigs(beside meridianURL: URL) throws -> [URL] {
        try DependencyDiscovery.resolveMerconfigs(explicit: merconfig, beside: meridianURL)
    }

    private func resolveRulebooks(beside meridianURL: URL) throws -> [URL] {
        try DependencyDiscovery.resolveRulebooks(explicit: rulebook, beside: meridianURL)
    }

    private func format(_ source: String) throws -> String {
        if ProcessInfo.processInfo.environment["MERIDIAN_TEST_SWIFT_FORMAT_FAIL"] == "1" {
            throw NSError(domain: "MeridianTest", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "simulated swift-format failure",
            ])
        }
        var config = Configuration()
        config.indentation = .spaces(4)
        config.lineLength = 120
        var result = ""
        let formatter = SwiftFormatter(configuration: config)
        try formatter.format(source: source, assumingFileURL: nil, selection: .infinite, to: &result)
        return result
    }
}
