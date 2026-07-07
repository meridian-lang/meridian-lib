#!/usr/bin/env swift

import Foundation

struct Corpus {
    let id: String
    let root: String
    let vocab: String
    let rulebook: String
}

let corpora = [
    Corpus(
        id: "gbrain",
        root: "sample-gbrain",
        vocab: "sample-gbrain/brain.merconfig",
        rulebook: "sample-gbrain/brain.merrules"
    ),
    Corpus(
        id: "erp",
        root: "corpora/erp",
        vocab: "corpora/erp/erp.merconfig",
        rulebook: "corpora/erp/erp.merrules"
    ),
    Corpus(
        id: "procedures",
        root: "corpora/procedures",
        vocab: "corpora/procedures/procedures.merconfig",
        rulebook: "corpora/procedures/procedures.merrules"
    ),
    Corpus(
        id: "incident",
        root: "corpora/incident",
        vocab: "corpora/incident/incident.merconfig",
        rulebook: "corpora/incident/incident.merrules"
    ),
    Corpus(
        id: "etl",
        root: "corpora/etl",
        vocab: "corpora/etl/etl.merconfig",
        rulebook: "corpora/etl/etl.merrules"
    ),
    Corpus(
        id: "governance",
        root: "corpora/governance",
        vocab: "corpora/governance/governance.merconfig",
        rulebook: "corpora/governance/governance.merrules"
    ),
    Corpus(
        id: "clinical",
        root: "corpora/clinical",
        vocab: "corpora/clinical/clinical.merconfig",
        rulebook: "corpora/clinical/clinical.merrules"
    ),
]

struct Options {
    var corpus = "all"
}

func usage() -> String {
    """
    usage: swift scripts/generate-compile-outputs.swift [--corpus gbrain|erp|procedures|incident|etl|governance|clinical|all]

    Cleans and regenerates <root>/compile-outputs from <root>/skills/*.meri,
    <root>/RESOLVER.meri, and any hand-authored flat <root>/rules/*.meridian
    fixtures (flat-path regression coverage), using:
      swift run meridian compile <file> --merconfig <vocab> --rulebook <rulebook> --no-format --namespace auto --output <root>/compile-outputs

    Defaults to all corpora.
    """
}

func parseArgs() -> Options {
    var options = Options()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--corpus":
            if let value = iterator.next() { options.corpus = value }
        case "-h", "--help":
            print(usage())
            exit(0)
        default:
            FileHandle.standardError.write(Data("unknown argument: \(arg)\n\(usage())\n".utf8))
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
    let rootURL = URL(fileURLWithPath: root)
    let skillsDir = rootURL.appendingPathComponent("skills")
    let skills = (try? fileManager.contentsOfDirectory(
        at: skillsDir,
        includingPropertiesForKeys: nil
    )) ?? []
    let skillFiles = skills
        .filter { $0.pathExtension == "meri" }
        .map(\.path)
        .sorted()
    let resolver = rootURL.appendingPathComponent("RESOLVER.meri").path
    var files = skillFiles
    if fileManager.fileExists(atPath: resolver) {
        files += [resolver]
    }
    // Flat rules/*.meridian fixtures (hand-authored, not migrated) are
    // flat-path regression coverage for the top-of-file Phase-8 rule desugar
    // — compile them alongside the migrated skills so they land in
    // compile-outputs/ too.
    let rulesDir = rootURL.appendingPathComponent("rules")
    let rulesFiles = ((try? fileManager.contentsOfDirectory(
        at: rulesDir,
        includingPropertiesForKeys: nil
    )) ?? [])
        .filter { $0.pathExtension == "meridian" }
        .map(\.path)
        .sorted()
    files += rulesFiles
    return files
}

func cleanOutput(_ path: String) throws {
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: path)
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    let files = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    for file in files where file.pathExtension == "swift" || file.pathExtension == "json" {
        try fileManager.removeItem(at: file)
    }
}

let options = parseArgs()
let selected: [Corpus]
if options.corpus == "all" {
    selected = corpora
} else {
    selected = corpora.filter { $0.id == options.corpus }
    if selected.isEmpty {
        FileHandle.standardError.write(Data("unknown corpus: \(options.corpus)\n\(usage())\n".utf8))
        exit(2)
    }
}

var failures = 0
for corpus in selected {
    print("=== \(corpus.id) ===")
    let output = "\(corpus.root)/compile-outputs"
    do {
        try cleanOutput(output)
    } catch {
        failures += 1
        print("failed to clean \(output): \(error)")
        continue
    }

    let files = meriFiles(root: corpus.root)
    if files.isEmpty {
        failures += 1
        print("no .meri files found under \(corpus.root)/skills")
        continue
    }

    var compiled = 0
    for file in files {
        let args = [
            "swift", "run", "meridian", "compile", file,
            "--merconfig", corpus.vocab,
            "--rulebook", corpus.rulebook,
            "--no-format", "--namespace", "auto",
            "--output", output,
        ]
        let result = run("/usr/bin/env", args)
        if result.status == 0 {
            compiled += 1
        } else {
            failures += 1
            print("\n=== \(file) ===")
            print(result.output.trimmingCharacters(in: .newlines))
        }
    }
    print("compiled \(compiled)/\(files.count) files into \(output)")
}

print("\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
