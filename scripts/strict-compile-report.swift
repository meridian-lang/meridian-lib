#!/usr/bin/env swift

import Foundation

struct Options {
    var root = "sample-gbrain"
    var vocab: String?
    var rulebook: String?
    var output = "/tmp/meridian-strict-compile-check"
}

func usage() -> String {
    """
    usage: swift scripts/strict-compile-report.swift [--root DIR] [--vocab FILE] [--rulebook FILE] [--output DIR]

    Defaults to sample-gbrain:
      --root sample-gbrain
      --vocab sample-gbrain/brain.merconfig
      --rulebook sample-gbrain/brain.merrules

    The script compiles <root>/skills/*.meri plus <root>/RESOLVER.meri and prints
    each failing file with three blank lines before its header for readability.
    """
}

func parseArgs() -> Options {
    var options = Options()
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--root":
            if let value = iterator.next() { options.root = value }
        case "--vocab":
            options.vocab = iterator.next()
        case "--rulebook":
            options.rulebook = iterator.next()
        case "--output":
            if let value = iterator.next() { options.output = value }
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

let options = parseArgs()
let vocab = options.vocab ?? "\(options.root)/brain.merconfig"
let rulebook = options.rulebook ?? "\(options.root)/brain.merrules"
let files = meriFiles(root: options.root)

if files.isEmpty {
    FileHandle.standardError.write(Data("no .meri files found under \(options.root)/skills\n".utf8))
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
    let result = run("/usr/bin/env", args)
    if result.status != 0 {
        failures += 1
        print("\n\n\n=== \(file) ===")
        print(result.output.trimmingCharacters(in: .newlines))
    }
}

print("\n\nFAILURES=\(failures)")
exit(failures == 0 ? 0 : 1)
