import ArgumentParser
import Foundation
import MeridianCore
import SwiftFormat

struct CompileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
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

    @Option(name: .long,
            help: "Wrap all generated declarations in `public enum <name> { … }` so independently-compiled files can share one Swift module without colliding. Defaults to `auto` (derive the name from the input file stem). Pass `none` to emit flat top-level declarations.")
    var namespace: String = "auto"

    @Flag(name: .long, help: "Include timestamp in generated file header.")
    var timestamp: Bool = false

    @Flag(name: .long, help: "Suppress source-line comments in generated code.")
    var noLineComments: Bool = false

    @Flag(name: .long, help: "Skip swift-format formatting of generated code.")
    var noFormat: Bool = false

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: phrase, phrase.match, lowering, all.")
    var trace: String?

    @Option(name: .long,
            help: "Write trace output to a file instead of stderr.")
    var traceFile: String?

    func run() async throws {
        let meridianURL  = URL(fileURLWithPath: input).standardized
        let outputURL    = URL(fileURLWithPath: output).standardized

        guard FileManager.default.fileExists(atPath: meridianURL.path) else {
            throw ValidationError("File not found: \(input)")
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

        let traceInstance = ParserTrace()
        if let spec = trace {
            traceInstance.enable(parsing: spec)
        }
        if let path = traceFile {
            let url = URL(fileURLWithPath: path).standardized
            FileManager.default.createFile(atPath: url.path, contents: nil)
            traceInstance.sink = .file(url)
        }

        let resolvedNamespace: String?
        switch namespace.lowercased() {
        case "none", "off", "false", "":
            resolvedNamespace = nil
        case "auto":
            resolvedNamespace = Self.pascalCase(meridianURL.deletingPathExtension().lastPathComponent)
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
            trace: traceInstance
        )
        let compiler = Compiler(options: compilerOpts)

        let compiled = try compiler.compileWithManifest(
            meridianSource: meridianSource,
            meridianFile:   meridianURL.lastPathComponent,
            vocabularies:   vocabularies,
            rulebooks:      rulebooks
        )
        var swift = compiled.swift

        // Optionally format with swift-format
        if !noFormat {
            swift = (try? format(swift)) ?? swift
        }

        // Write output
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let outFile = outputURL.appendingPathComponent(meridianURL.deletingPathExtension().lastPathComponent + ".swift")
        try swift.write(to: outFile, atomically: true, encoding: .utf8)

        // Write the COMPLETE manifest the compiler assembled (workflows,
        // metadata, outline, recorded sections), merging in the source map
        // derived from the generated Swift. No more thin `workflows: []` stub.
        let m = compiled.manifest
        let manifest = try ManifestEmitter().emit(.init(
            sourceFiles: [meridianURL.lastPathComponent] + merconfigURLs.map(\.lastPathComponent),
            workflows: m.workflows,
            constantsDecl: m.constantsDecl,
            toolsUsed: m.toolsUsed,
            kindsUsed: m.kindsUsed,
            instancesRequired: m.instancesRequired,
            sourceMap: sourceMapEntries(fromGeneratedSwift: swift),
            metadata: m.metadata,
            outline: m.outline,
            rules: m.rules,
            skillSections: m.skillSections
        ))
        let manifestFile = outputURL.appendingPathComponent(
            meridianURL.deletingPathExtension().lastPathComponent + ".meridian.manifest.json"
        )
        try manifest.write(to: manifestFile, atomically: true, encoding: .utf8)

        print("✓ \(outFile.path)")
        print("✓ \(manifestFile.path)")
    }

    // MARK: - Helpers

    private func resolveMerconfigs(beside meridianURL: URL) throws -> [URL] {
        // Explicit overrides (one or more --merconfig flags). Order matters:
        // the compiler concatenates declaration order, so leftmost wins for
        // anything that shares a stable iteration order downstream.
        if !merconfig.isEmpty {
            return try merconfig.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("merconfig not found: \(path)")
                }
                return url
            }
        }
        // Autodiscover every .merconfig in the input's directory (sorted by
        // name for deterministic order). If the directory has none, fall back
        // to the parent directory.
        let dir = meridianURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let here = files.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !here.isEmpty { return here }
        let parent = dir.deletingLastPathComponent()
        let parentFiles = (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        return parentFiles.filter { $0.pathExtension == "merconfig" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func resolveRulebooks(beside meridianURL: URL) throws -> [URL] {
        if !rulebook.isEmpty {
            return try rulebook.map { path in
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("rulebook not found: \(path)")
                }
                return url
            }
        }
        let dir = meridianURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let here = files.filter { $0.pathExtension == "merrules" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !here.isEmpty { return here }
        let parent = dir.deletingLastPathComponent()
        let parentFiles = (try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil)) ?? []
        return parentFiles.filter { $0.pathExtension == "merrules" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Derive a valid UpperCamelCase Swift identifier from a file stem,
    /// splitting on any non-alphanumeric boundary (so `idea_lineage` →
    /// `IdeaLineage`, `webhook-transforms` → `WebhookTransforms`).
    static func pascalCase(_ stem: String) -> String {
        let parts = stem.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        guard let first = joined.first else { return "Skill" }
        return first.isNumber ? "_" + joined : joined
    }

    private func format(_ source: String) throws -> String {
        var config = Configuration()
        config.indentation = .spaces(4)
        config.lineLength = 120
        var result = ""
        let formatter = SwiftFormatter(configuration: config)
        try formatter.format(source: source, assumingFileURL: nil, selection: .infinite, to: &result)
        return result
    }

    private func sourceMapEntries(fromGeneratedSwift swift: String) -> [ManifestEmitter.SourceMapEntry] {
        swift.components(separatedBy: "\n").enumerated().compactMap { idx, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("// L"),
                  let lineNumber = Int(trimmed.dropFirst(4).split(separator: " ").first ?? "")
            else { return nil }
            return ManifestEmitter.SourceMapEntry(
                meridianLine: lineNumber,
                swiftLine: idx + 1
            )
        }
    }
}
