#!/usr/bin/env swift

import Foundation

// Corpus catalog — data in corpus-catalog.json; loader aligned with CorpusCatalog.swift.
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
    var routeFuzzy = true
}

func usage(catalog: CorpusCatalogFile) -> String {
    let ids = catalog.corpora.map(\.id).sorted().joined(separator: "|")
    return """
    usage: swift scripts/generate-migration.swift [--corpus \(ids)|all] [--no-route-fuzzy]

    Batch re-migrates <root>/original-skills/**/SKILL.md into <root>/skills/*.meri
    (AGENTS.md Phase 3, "batch re-migrate the remaining skills") using:

      swift run meridian migrate-skill <originals> --out <skills> --batch --force \\
        --vocab <vocab> --rulebook <rulebook> --report <root>/migration-report.md

    Also migrates <root>/original-skills/RESOLVER.md into <root>/RESOLVER.meri
    with a separate single-file `migrate-skill` call — `RESOLVER.md` is never
    named `SKILL.md`, so `--batch` never discovers it on its own.

    New section-role aliases the migrator derives (unrecognized-but-executable
    headings, below-threshold judgment-wrap targets) are appended straight to
    <root>'s primary `.merrules`, matching `migrate-skill`'s own persistence
    behavior — re-running this script is idempotent.

    After migrating, regenerate compile-outputs and deviation reports:
      swift scripts/generate-compile-outputs.swift --corpus <id>
      swift scripts/generate-deviations.swift --corpus <id>

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
        case "--no-route-fuzzy":
            options.routeFuzzy = false
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
        "swift", "run", "meridian", "migrate-skill",
        corpus.originals,
        "--out", corpus.skillsOut,
        "--batch", "--force",
        "--vocab", corpus.vocab,
        "--rulebook", corpus.rulebook,
        "--report", "\(corpus.skillsOut)/../migration-report.md",
    ]
    args.append(options.routeFuzzy ? "--route-fuzzy" : "--no-route-fuzzy")
    let result = run("/usr/bin/env", args)
    print(result.output.trimmingCharacters(in: .newlines))
    if result.status != 0 {
        failures += 1
    }

    guard FileManager.default.fileExists(atPath: corpus.resolverOriginal) else { continue }
    var resolverArgs = [
        "swift", "run", "meridian", "migrate-skill",
        corpus.resolverOriginal,
        "--out", corpus.resolverOut,
        "--force",
        "--vocab", corpus.vocab,
        "--rulebook", corpus.rulebook,
    ]
    resolverArgs.append(options.routeFuzzy ? "--route-fuzzy" : "--no-route-fuzzy")
    let resolverResult = run("/usr/bin/env", resolverArgs)
    print(resolverResult.output.trimmingCharacters(in: .newlines))
    if resolverResult.status != 0 {
        failures += 1
    }
}

print("\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
