#!/usr/bin/env swift

import Foundation

struct Corpus {
    let id: String
    let originals: String
    let portedRoot: String
    let output: String
}

let corpora = [
    Corpus(
        id: "gbrain",
        originals: "sample-gbrain/original-skills",
        portedRoot: "sample-gbrain",
        output: "sample-gbrain/migration-deviations"
    ),
    Corpus(
        id: "erp",
        originals: "corpora/erp/original-skills",
        portedRoot: "corpora/erp",
        output: "corpora/erp/migration-deviations"
    ),
    Corpus(
        id: "procedures",
        originals: "corpora/procedures/original-skills",
        portedRoot: "corpora/procedures",
        output: "corpora/procedures/migration-deviations"
    ),
    Corpus(
        id: "incident",
        originals: "corpora/incident/original-skills",
        portedRoot: "corpora/incident",
        output: "corpora/incident/migration-deviations"
    ),
    Corpus(
        id: "etl",
        originals: "corpora/etl/original-skills",
        portedRoot: "corpora/etl",
        output: "corpora/etl/migration-deviations"
    ),
    Corpus(
        id: "governance",
        originals: "corpora/governance/original-skills",
        portedRoot: "corpora/governance",
        output: "corpora/governance/migration-deviations"
    ),
    Corpus(
        id: "clinical",
        originals: "corpora/clinical/original-skills",
        portedRoot: "corpora/clinical",
        output: "corpora/clinical/migration-deviations"
    ),
]

struct Options {
    var corpus = "all"
}

func usage() -> String {
    """
    usage: swift scripts/generate-deviations.swift [--corpus gbrain|erp|procedures|incident|etl|governance|clinical|all]

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

/// The `## Summary` block is the deviation index proper (tiers, similarity,
/// inert/operational-inert/unclassified counts) — print it inline so a run of
/// this script is itself the thing to measure against, not just a confirmation
/// that some file got written.
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

/// One row of the generated `## Per-skill` table, keyed to the columns:
/// `skill | tier | similarity | lines | generated_loc | inert deviations |
/// inert | operational inert | judgment | canonical_drift | frontmatter added |
/// categories`.
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
        // `| skill | tier | ... |` splits into [<empty>, skill, tier, ..., <empty>].
        guard cells.count >= 13 else { continue }
        guard cells[2].allSatisfy(\.isNumber) else { continue }  // skip the `---|---|...` separator row
        // `[skill](skill.md)` -> `skill`.
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

var failures = 0
for corpus in selected {
    print("=== \(corpus.id) ===")
    let args = [
        "swift", "run", "meridian", "skill-deviation",
        corpus.originals, corpus.portedRoot,
        "--batch", "--index",
        "--out", corpus.output,
    ]
    let result = run("/usr/bin/env", args)
    if result.status == 0 {
        print("generated \(corpus.output)")
        printSummary(of: "\(corpus.output)/README.md")
        print("")
        printOperationalInertBreakdown(of: "\(corpus.output)/README.md")
    } else {
        failures += 1
        print(result.output.trimmingCharacters(in: .newlines))
    }
    print("")
}

print("\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
