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
    usage: swift scripts/generate-deviations.swift [--corpus \(ids)|all]

    Regenerates migration deviation reports with:
      swift run meridian skill-deviation <original-skills> <ported-root> --batch --index --out <migration-deviations>

    Then prints, per corpus:
      1. the generated `## Summary` block (tiers, similarity, total inert
         sections, operational-inert/unclassified counts; total inert includes
         intentional docs/templates/tools metadata, while operational inert is
         the migration-fix worklist)
      2. a per-file operational-inert breakdown, worst offenders first, parsed
         from the `## Per-skill` table — this is the actionable list: it's
         what you work down to drive the aggregate `Operational inert` count
         in (1) toward zero, without having to open each corpus's README.md
         by hand.

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

func printSummary(of readmePath: String) {
    guard let text = try? String(contentsOfFile: readmePath, encoding: .utf8) else {
        print("(no README.md at \(readmePath) to summarize)")
        return
    }
    let lines = text.components(separatedBy: "\n")
    guard let start = lines.firstIndex(where: { $0.hasPrefix("## Summary") }) else {
        print(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return
    }
    let rest = lines[(start + 1)...]
    let end = rest.firstIndex(where: { $0.hasPrefix("## ") }) ?? lines.endIndex
    for line in lines[start..<end] where !line.isEmpty {
        print(line)
    }
}

struct SkillRow {
    let name: String
    let operationalInert: Int
    let categories: String
}

func parsePerSkillTable(of readmePath: String) -> [SkillRow] {
    guard let text = try? String(contentsOfFile: readmePath, encoding: .utf8) else { return [] }
    let lines = text.components(separatedBy: "\n")
    guard let start = lines.firstIndex(where: { $0.hasPrefix("## Per-skill") }) else { return [] }
    var rows: [SkillRow] = []
    for line in lines[(start + 1)...] {
        guard line.hasPrefix("|") else { continue }
        let cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 13 else { continue }
        guard cells[2].allSatisfy(\.isNumber) else { continue }
        var name = cells[1]
        if let close = name.firstIndex(of: "]"), name.hasPrefix("[") {
            name = String(name[name.index(after: name.startIndex)..<close])
        }
        guard let operationalInert = Int(cells[8]) else { continue }
        rows.append(SkillRow(name: name, operationalInert: operationalInert, categories: cells[12]))
    }
    return rows
}

func printOperationalInertBreakdown(of readmePath: String) {
    let rows = parsePerSkillTable(of: readmePath).filter { $0.operationalInert > 0 }
        .sorted { $0.operationalInert != $1.operationalInert ? $0.operationalInert > $1.operationalInert : $0.name < $1.name }
    guard !rows.isEmpty else {
        print("Per-file operational-inert breakdown: none — 0 files with operational-inert sections.")
        return
    }
    print("Per-file operational-inert breakdown (\(rows.count) file(s), worst first):")
    for row in rows {
        print("  \(row.operationalInert)\t\(row.name)")
    }
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
    var args = [
        "swift", "run", "meridian", "skill-deviation",
        corpus.originals, corpus.root,
        "--batch", "--index",
        "--out", corpus.migrationDeviations,
    ]
    if let modulePath = corpus.modulePath {
        args += ["--module-path", modulePath]
    }
    let result = run("/usr/bin/env", args)
    if result.status == 0 {
        print("generated \(corpus.migrationDeviations)")
        printSummary(of: "\(corpus.migrationDeviations)/README.md")
        print("")
        printOperationalInertBreakdown(of: "\(corpus.migrationDeviations)/README.md")
    } else {
        failures += 1
        print(result.output.trimmingCharacters(in: .newlines))
    }
    print("")
}

print("\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
