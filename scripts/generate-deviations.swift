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
]

struct Options {
    var corpus = "all"
}

func usage() -> String {
    """
    usage: swift scripts/generate-deviations.swift [--corpus gbrain|erp|procedures|all]

    Regenerates migration deviation reports with:
      swift run meridian skill-deviation <original-skills> <ported-root> --batch --index --out <migration-deviations>

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
    } else {
        failures += 1
        print(result.output.trimmingCharacters(in: .newlines))
    }
}

print("\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
