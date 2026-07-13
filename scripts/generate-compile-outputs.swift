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

func selectCorpora(id: String, catalog: CorpusCatalogFile) throws -> [CorpusRecord] {
    if id == "all" { return catalog.corpora }
    let matches = catalog.corpora.filter { $0.id == id }
    guard !matches.isEmpty else {
        let available = catalog.corpora.map(\.id).sorted().joined(separator: ", ")
        throw NSError(domain: "CorpusCatalog", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "unknown corpus: \(id) (available: \(available))"])
    }
    return matches
}

struct Options {
    var corpus = "all"
}

func usage(catalog: CorpusCatalogFile) -> String {
    let ids = catalog.corpora.map(\.id).sorted().joined(separator: "|")
    return """
    usage: swift scripts/generate-compile-outputs.swift [--corpus \(ids)|all]

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

func frontmatterVocabulary(for meriPath: String, corpusRoot: String) -> String? {
    guard let text = try? String(contentsOfFile: meriPath, encoding: .utf8) else { return nil }
    guard text.hasPrefix("---") else { return nil }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard lines.count > 2 else { return nil }
    var end = 1
    while end < lines.count, lines[end] != "---" { end += 1 }
    guard end < lines.count else { return nil }
    for line in lines[1..<end] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("vocabulary:") else { continue }
        let name = trimmed.dropFirst("vocabulary:".count).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        let skillDir = URL(fileURLWithPath: meriPath).deletingLastPathComponent()
        let besideSkill = skillDir.appendingPathComponent(String(name)).path
        if FileManager.default.fileExists(atPath: besideSkill) { return besideSkill }
        let besideRoot = URL(fileURLWithPath: corpusRoot).appendingPathComponent(String(name)).path
        if FileManager.default.fileExists(atPath: besideRoot) { return besideRoot }
        return besideSkill
    }
    return nil
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

let selected: [CorpusRecord]
do {
    selected = try selectCorpora(id: options.corpus, catalog: catalog)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n\(usage(catalog: catalog))\n".utf8))
    exit(2)
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
        let vocab = frontmatterVocabulary(for: file, corpusRoot: corpus.root) ?? corpus.vocab
        var args = [
            "swift", "run", "meridian", "compile", file,
            "--merconfig", vocab,
            "--rulebook", corpus.rulebook,
            "--no-format", "--namespace", "auto",
            "--output", output,
        ]
        if let modulePath = corpus.modulePath {
            args += ["--module-path", modulePath]
        }
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
