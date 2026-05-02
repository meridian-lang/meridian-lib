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

        let traceInstance = ParserTrace()
        if let spec = trace {
            traceInstance.enable(parsing: spec)
        }
        if let path = traceFile {
            let url = URL(fileURLWithPath: path).standardized
            FileManager.default.createFile(atPath: url.path, contents: nil)
            traceInstance.sink = .file(url)
        }

        let compilerOpts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: timestamp,
                sourceFileName: meridianURL.lastPathComponent,
                emitSourceLineComments: !noLineComments
            ),
            trace: traceInstance
        )
        let compiler = Compiler(options: compilerOpts)

        var swift = try compiler.compile(
            meridianSource: meridianSource,
            meridianFile:   meridianURL.lastPathComponent,
            vocabularies:   vocabularies
        )

        // Optionally format with swift-format
        if !noFormat {
            swift = (try? format(swift)) ?? swift
        }

        // Write output
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let outFile = outputURL.appendingPathComponent(meridianURL.deletingPathExtension().lastPathComponent + ".swift")
        try swift.write(to: outFile, atomically: true, encoding: .utf8)

        let manifest = try ManifestEmitter().emit(.init(
            sourceFiles: [meridianURL.lastPathComponent] + merconfigURLs.map(\.lastPathComponent),
            workflows: [],
            sourceMap: sourceMapEntries(fromGeneratedSwift: swift)
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
