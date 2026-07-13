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
    var skills: String?
    var vocab: String?
    var rulebook: String?
    var out = "/tmp/inert-yield-report.md"
}

func usage(catalog: CorpusCatalogFile) -> String {
    let ids = catalog.corpora.map(\.id).sorted().joined(separator: "|")
    return """
    usage: swift scripts/inert-yield-report.swift [--corpus \(ids)] [--root DIR] [--skills DIR] [--vocab FILE] [--rulebook FILE] [--out FILE]

    Defaults to gbrain from scripts/corpus-catalog.json when --corpus is omitted.
    Explicit --root/--vocab/--rulebook override catalog defaults.

    Runs `meridian inert-yield --batch` over every ported .meri in <skills> and
    prints the corpus-wide yield summary + ranked needs-phrase worklist to stdout,
    writing the full per-line report to <out>.
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
        case "--skills":
            options.skills = iterator.next()
        case "--vocab":
            options.vocab = iterator.next()
        case "--rulebook":
            options.rulebook = iterator.next()
        case "--out":
            if let value = iterator.next() { options.out = value }
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
let skills = options.skills ?? record.skillsOut
let vocab = options.vocab ?? record.vocab
let rulebook = options.rulebook ?? record.rulebook

var args = [
    "swift", "run", "meridian", "inert-yield", skills,
    "--batch", "--out", options.out,
]
if FileManager.default.fileExists(atPath: vocab) {
    args += ["--vocab", vocab]
}
if FileManager.default.fileExists(atPath: rulebook) {
    args += ["--rulebook", rulebook]
}

let result = run("/usr/bin/env", args)
print(result.output.trimmingCharacters(in: .newlines))
exit(result.status)
