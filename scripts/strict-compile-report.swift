#!/usr/bin/env swift

import Foundation

struct CorpusRecord: Decodable {
    let id: String
    let root: String
    let originals: String
    let vocab: String
    let rulebook: String
    let skillsOut: String
    let resolverOriginal: String
    let resolverOut: String
    let migrationDeviations: String
    let modulePath: String?
}

struct CorpusCatalogFile: Decodable {
    let corpora: [CorpusRecord]
}

func loadCorpusCatalog() throws -> CorpusCatalogFile {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("corpus-catalog.json")
    return try JSONDecoder().decode(CorpusCatalogFile.self, from: Data(contentsOf: url))
}

func selectCorpus(id: String, catalog: CorpusCatalogFile) throws -> CorpusRecord {
    let matches = catalog.corpora.filter { $0.id == id }
    guard let record = matches.first else {
        let available = catalog.corpora.map(\.id).sorted().joined(separator: ", ")
        throw NSError(domain: "CorpusCatalog", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "unknown corpus: \(id) (available: \(available))"])
    }
    return record
}

struct Options {
    var corpus = "gbrain"
    var root: String?
    var vocab: String?
    var rulebook: String?
    var output = "/tmp/meridian-strict-compile-check"
}

func usage(catalog: CorpusCatalogFile) -> String {
    let ids = catalog.corpora.map(\.id).sorted().joined(separator: "|")
    return """
    usage: swift scripts/strict-compile-report.swift [--corpus \(ids)] [--root DIR] [--vocab FILE] [--rulebook FILE] [--output DIR]

    Defaults to gbrain from scripts/corpus-catalog.json when --corpus is omitted.
    Explicit --root/--vocab/--rulebook override catalog defaults.

    Compiles <root>/skills/*.meri plus <root>/RESOLVER.meri and prints each failing
    file with three blank lines before its header for readability.
    """
}

func parseArgs() -> Options {
    var options = Options()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--corpus":
            if let value = iterator.next() { options.corpus = value }
        case "--root":
            options.root = iterator.next()
        case "--vocab":
            options.vocab = iterator.next()
        case "--rulebook":
            options.rulebook = iterator.next()
        case "--output":
            if let value = iterator.next() { options.output = value }
        case "-h", "--help":
            return options
        default:
            FileHandle.standardError.write(Data("unknown argument: \(arg)\n".utf8))
            exit(2)
        }
    }
    return options
}

func run(_ executable: String, _ arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
    } catch {
        return (127, "failed to launch \(executable): \(error)")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

func meriFiles(root: String) -> [String] {
    let fileManager = FileManager.default
    let skillsDir = URL(fileURLWithPath: root).appendingPathComponent("skills")
    let skills = (try? fileManager.contentsOfDirectory(
        at: skillsDir,
        includingPropertiesForKeys: nil
    )) ?? []
    let skillFiles = skills
        .filter { $0.pathExtension == "meri" }
        .map(\.path)
        .sorted()
    let resolver = URL(fileURLWithPath: root).appendingPathComponent("RESOLVER.meri").path
    if fileManager.fileExists(atPath: resolver) {
        return skillFiles + [resolver]
    }
    return skillFiles
}

let catalog: CorpusCatalogFile
do {
    catalog = try loadCorpusCatalog()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

let options = parseArgs()
if CommandLine.arguments.contains("-h") || CommandLine.arguments.contains("--help") {
    print(usage(catalog: catalog))
    exit(0)
}

let record: CorpusRecord
do {
    record = try selectCorpus(id: options.corpus, catalog: catalog)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n\(usage(catalog: catalog))\n".utf8))
    exit(2)
}

let root = options.root ?? record.root
let vocab = options.vocab ?? record.vocab
let rulebook = options.rulebook ?? record.rulebook
let files = meriFiles(root: root)

if files.isEmpty {
    FileHandle.standardError.write(Data("no .meri files found under \(root)/skills\n".utf8))
    exit(1)
}

var failures = 0
for file in files {
    var args = [
        "swift", "run", "meridian", "compile", file,
        "--no-format", "--namespace", "auto",
        "--output", options.output,
    ]
    if FileManager.default.fileExists(atPath: vocab) {
        args += ["--merconfig", vocab]
    }
    if FileManager.default.fileExists(atPath: rulebook) {
        args += ["--rulebook", rulebook]
    }
    if let modulePath = record.modulePath, options.root == nil {
        args += ["--module-path", modulePath]
    }
    let result = run("/usr/bin/env", args)
    if result.status != 0 {
        failures += 1
        print("\n\n\n=== \(file) ===")
        print(result.output.trimmingCharacters(in: .newlines))
    }
}

print("\n\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
