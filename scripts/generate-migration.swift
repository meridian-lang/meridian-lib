#!/usr/bin/env swift

import Foundation

struct Corpus {
    let id: String
    let originals: String
    let vocab: String
    let rulebook: String
    let skillsOut: String
    /// `RESOLVER.md` lives beside `originals` (not named `SKILL.md`, so
    /// `--batch` never discovers it) and ports to `<root>/RESOLVER.meri`, not
    /// under `skillsOut` — migrated separately via single-file mode.
    let resolverOriginal: String
    let resolverOut: String
}

let corpora = [
    Corpus(
        id: "gbrain",
        originals: "sample-gbrain/original-skills",
        vocab: "sample-gbrain/brain.merconfig",
        rulebook: "sample-gbrain/brain.merrules",
        skillsOut: "sample-gbrain/skills",
        resolverOriginal: "sample-gbrain/original-skills/RESOLVER.md",
        resolverOut: "sample-gbrain/RESOLVER.meri"
    ),
    Corpus(
        id: "erp",
        originals: "corpora/erp/original-skills",
        vocab: "corpora/erp/erp.merconfig",
        rulebook: "corpora/erp/erp.merrules",
        skillsOut: "corpora/erp/skills",
        resolverOriginal: "corpora/erp/original-skills/RESOLVER.md",
        resolverOut: "corpora/erp/RESOLVER.meri"
    ),
    Corpus(
        id: "procedures",
        originals: "corpora/procedures/original-skills",
        vocab: "corpora/procedures/procedures.merconfig",
        rulebook: "corpora/procedures/procedures.merrules",
        skillsOut: "corpora/procedures/skills",
        resolverOriginal: "corpora/procedures/original-skills/RESOLVER.md",
        resolverOut: "corpora/procedures/RESOLVER.meri"
    ),
    Corpus(
        id: "incident",
        originals: "corpora/incident/original-skills",
        vocab: "corpora/incident/incident.merconfig",
        rulebook: "corpora/incident/incident.merrules",
        skillsOut: "corpora/incident/skills",
        resolverOriginal: "corpora/incident/original-skills/RESOLVER.md",
        resolverOut: "corpora/incident/RESOLVER.meri"
    ),
    Corpus(
        id: "etl",
        originals: "corpora/etl/original-skills",
        vocab: "corpora/etl/etl.merconfig",
        rulebook: "corpora/etl/etl.merrules",
        skillsOut: "corpora/etl/skills",
        resolverOriginal: "corpora/etl/original-skills/RESOLVER.md",
        resolverOut: "corpora/etl/RESOLVER.meri"
    ),
    Corpus(
        id: "governance",
        originals: "corpora/governance/original-skills",
        vocab: "corpora/governance/governance.merconfig",
        rulebook: "corpora/governance/governance.merrules",
        skillsOut: "corpora/governance/skills",
        resolverOriginal: "corpora/governance/original-skills/RESOLVER.md",
        resolverOut: "corpora/governance/RESOLVER.meri"
    ),
    Corpus(
        id: "clinical",
        originals: "corpora/clinical/original-skills",
        vocab: "corpora/clinical/clinical.merconfig",
        rulebook: "corpora/clinical/clinical.merrules",
        skillsOut: "corpora/clinical/skills",
        resolverOriginal: "corpora/clinical/original-skills/RESOLVER.md",
        resolverOut: "corpora/clinical/RESOLVER.meri"
    ),
]

struct Options {
    var corpus = "all"
    var routeFuzzy = true
}

func usage() -> String {
    """
    usage: swift scripts/generate-migration.swift [--corpus gbrain|erp|procedures|incident|etl|governance|clinical|all] [--no-route-fuzzy]

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
