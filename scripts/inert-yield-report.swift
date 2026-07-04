#!/usr/bin/env swift

import Foundation

struct Options {
    var root = "sample-gbrain"
    var skills = "sample-gbrain/skills"
    var vocab: String?
    var rulebook: String?
    var out = "/tmp/inert-yield-report.md"
}

func usage() -> String {
    """
    usage: swift scripts/inert-yield-report.swift [--root DIR] [--skills DIR] [--vocab FILE] [--rulebook FILE] [--out FILE]

    Defaults to sample-gbrain:
      --root sample-gbrain
      --skills sample-gbrain/skills
      --vocab sample-gbrain/brain.merconfig
      --rulebook sample-gbrain/brain.merrules
      --out /tmp/inert-yield-report.md

    Phase 0 measurement spike (see the "Deterministic lowering for gbrain"
    plan): runs `meridian inert-yield --batch` over every ported .meri in
    <skills> and prints the corpus-wide yield summary + ranked needs-phrase
    worklist to stdout, writing the full per-line report to <out>.
    """
}

func parseArgs() -> Options {
    var options = Options()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--root":
            if let value = iterator.next() { options.root = value }
        case "--skills":
            if let value = iterator.next() { options.skills = value }
        case "--vocab":
            options.vocab = iterator.next()
        case "--rulebook":
            options.rulebook = iterator.next()
        case "--out":
            if let value = iterator.next() { options.out = value }
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
let vocab = options.vocab ?? "\(options.root)/brain.merconfig"
let rulebook = options.rulebook ?? "\(options.root)/brain.merrules"

var args = [
    "swift", "run", "meridian", "inert-yield", options.skills,
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
