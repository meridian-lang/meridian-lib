#!/usr/bin/env swift

// Meridian coverage tool. Swift shebang script (no shell scripts in this repo).
//
// Pipeline:
//   1. (optionally) run `swift test --enable-code-coverage`
//   2. locate the instrumented test binary + merged .profdata under .build/
//   3. run `xcrun llvm-cov report`, scoped to the in-scope Sources/Meridian* modules
//      (always excluding .build/, /Tests/, /SampleDemoFlows/, /checkouts/)
//   4. parse the per-file table, apply coverage-exclusions.md, print a summary
//   5. optionally fail (--gate) when any non-excluded in-scope file is below its
//      required region coverage.
//
// Usage:
//   scripts/coverage.swift                 build+test, then report (report-only)
//   scripts/coverage.swift --no-test       reuse existing .profdata
//   scripts/coverage.swift --gate          fail if any non-excluded file < threshold
//   scripts/coverage.swift --threshold 95  override the global region threshold (default 100)
//   scripts/coverage.swift --baseline docs/coverage/coverage-baseline.md   write the report
//   scripts/coverage.swift --html .coverage-html            emit an HTML drill-down
//
// The exclusions file (docs/coverage/coverage-exclusions.md) is the single,
// reviewed source of truth for what is allowed to be uncovered. See that file
// (and docs/coverage/README.md) for the format.

import Foundation

// MARK: - Process helper

@discardableResult
func run(_ launchPath: String, _ args: [String], capture: Bool = true) -> (status: Int32, out: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: launchPath)
    p.arguments = args
    let pipe = Pipe()
    if capture {
        p.standardOutput = pipe
        p.standardError = pipe
    }
    do {
        try p.run()
    } catch {
        FileHandle.standardError.write(Data("failed to launch \(launchPath): \(error)\n".utf8))
        return (127, "")
    }
    var data = Data()
    if capture {
        data = pipe.fileHandleForReading.readDataToEndOfFile()
    }
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}

func which(_ tool: String) -> String {
    let r = run("/usr/bin/xcrun", ["--find", tool])
    let path = r.out.trimmingCharacters(in: .whitespacesAndNewlines)
    return path.isEmpty ? "/usr/bin/\(tool)" : path
}

// MARK: - Arguments

var doTest = true
var gate = false
var globalThreshold = 100.0
var baselinePath: String? = nil
var htmlDir: String? = nil

var it = CommandLine.arguments.dropFirst().makeIterator()
while let a = it.next() {
    switch a {
    case "--no-test": doTest = false
    case "--gate": gate = true
    case "--threshold": if let v = it.next(), let d = Double(v) { globalThreshold = d }
    case "--baseline": baselinePath = it.next()
    case "--html": htmlDir = it.next()
    case "-h", "--help":
        print("usage: scripts/coverage.swift [--no-test] [--gate] [--threshold N] [--baseline FILE] [--html DIR]")
        exit(0)
    default:
        FileHandle.standardError.write(Data("unknown argument: \(a)\n".utf8))
        exit(2)
    }
}

let fm = FileManager.default
let repoRoot = fm.currentDirectoryPath

// MARK: - Exclusions (coverage-exclusions.md)

struct Exclusions {
    var excludedFileSubstrings: [String] = []   // removed from the denominator entirely
    var fileThresholds: [(substr: String, minPercent: Double)] = []  // per-file override
}

func loadExclusions() -> Exclusions {
    var ex = Exclusions()
    let path = repoRoot + "/docs/coverage/coverage-exclusions.md"
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return ex }
    // Parse fenced blocks: ```exclude-files ... ``` and ```file-thresholds ... ```
    var mode = ""   // "", "exclude-files", "file-thresholds"
    for raw in text.components(separatedBy: "\n") {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("```") {
            let tag = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            mode = (mode.isEmpty && (tag == "exclude-files" || tag == "file-thresholds")) ? tag : ""
            continue
        }
        if mode.isEmpty { continue }
        // strip trailing "# comment"
        var content = line
        if let hash = content.range(of: "#") { content = String(content[..<hash.lowerBound]) }
        content = content.trimmingCharacters(in: .whitespaces)
        if content.isEmpty { continue }
        switch mode {
        case "exclude-files":
            ex.excludedFileSubstrings.append(content)
        case "file-thresholds":
            let parts = content.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let pct = Double(parts[1]) {
                ex.fileThresholds.append((parts[0], pct))
            }
        default: break
        }
    }
    return ex
}

let exclusions = loadExclusions()

// MARK: - Run tests

if doTest {
    print("==> swift test --enable-code-coverage")
    let r = run("/usr/bin/env", ["swift", "test", "--enable-code-coverage"], capture: false)
    if r.status != 0 {
        FileHandle.standardError.write(Data("swift test failed (status \(r.status))\n".utf8))
        exit(r.status == 0 ? 1 : r.status)
    }
}

// MARK: - Locate artifacts

func findFirst(under dir: String, matching predicate: (String) -> Bool) -> String? {
    guard let en = fm.enumerator(atPath: dir) else { return nil }
    for case let rel as String in en where predicate(rel) {
        return dir + "/" + rel
    }
    return nil
}

let buildDir = repoRoot + "/.build"
guard let profdata = findFirst(under: buildDir, matching: { $0.hasSuffix("codecov/default.profdata") }) else {
    FileHandle.standardError.write(Data("could not find default.profdata under .build (run without --no-test first)\n".utf8))
    exit(1)
}
// The instrumented binary lives inside the .xctest bundle.
guard let bundle = findFirst(under: buildDir, matching: { $0.hasSuffix("meridianPackageTests.xctest") }) else {
    FileHandle.standardError.write(Data("could not find meridianPackageTests.xctest under .build\n".utf8))
    exit(1)
}
let binary = bundle + "/Contents/MacOS/meridianPackageTests"

let llvmCov = which("llvm-cov")

// Base ignore regex + any fully-excluded files from coverage-exclusions.md.
var ignoreParts = ["\\.build/", "/Tests/", "/SampleDemoFlows/", "/checkouts/"]
ignoreParts += exclusions.excludedFileSubstrings.map { NSRegularExpression.escapedPattern(for: $0) }
let ignoreRegex = "(" + ignoreParts.joined(separator: "|") + ")"

// MARK: - HTML (optional)

if let html = htmlDir {
    print("==> emitting HTML coverage to \(html)")
    run(llvmCov, ["show", binary, "-instr-profile", profdata,
                  "-ignore-filename-regex=\(ignoreRegex)",
                  "-format=html", "-output-dir=\(html)"], capture: false)
}

// MARK: - Report

let report = run(llvmCov, ["report", binary, "-instr-profile", profdata,
                           "-ignore-filename-regex=\(ignoreRegex)"])
if report.status != 0 {
    FileHandle.standardError.write(Data("llvm-cov report failed:\n\(report.out)\n".utf8))
    exit(1)
}

// MARK: - Parse the per-file table

struct FileCov {
    let file: String
    let regionPct: Double
    let linePct: Double
    let missedRegions: Int
}

func parsePercent(_ s: String) -> Double? {
    guard s.hasSuffix("%") else { return nil }
    return Double(s.dropLast())
}

var rows: [FileCov] = []
for line in report.out.components(separatedBy: "\n") {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("Meridian") else { continue }   // in-scope module rows only
    let tokens = trimmed.split(whereSeparator: { $0 == " " }).map(String.init)
    guard tokens.count >= 10 else { continue }
    let file = tokens[0]
    // Columns: file regions missed cover% functions missed executed% lines missed cover% ...
    let percents = tokens.compactMap { parsePercent($0) }
    guard percents.count >= 3 else { continue }
    let regionPct = percents[0]
    let linePct = percents[2]
    let missedRegions = Int(tokens[2]) ?? 0
    rows.append(FileCov(file: file, regionPct: regionPct, linePct: linePct, missedRegions: missedRegions))
}

// MARK: - Gate evaluation

func requiredThreshold(for file: String) -> Double {
    for t in exclusions.fileThresholds where file.contains(t.substr) {
        return t.minPercent
    }
    return globalThreshold
}

var failures: [(FileCov, Double)] = []
for r in rows {
    let req = requiredThreshold(for: r.file)
    if r.regionPct + 1e-9 < req {
        failures.append((r, req))
    }
}

// MARK: - Output

func pad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
}
func lpad(_ s: String, _ width: Int) -> String {
    s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
}
func pct(_ d: Double) -> String { String(format: "%6.2f%%", d) }

var out = ""
out += "Meridian coverage report\n"
out += "========================\n\n"
out += pad("File", 58) + " " + lpad("Region%", 8) + " " + lpad("Line%", 8) + " " + lpad("Missed", 8) + "\n"

let sorted = rows.sorted { $0.regionPct < $1.regionPct }
for r in sorted {
    out += pad(r.file, 58) + " " + lpad(pct(r.regionPct), 8) + " "
        + lpad(pct(r.linePct), 8) + " " + lpad(String(r.missedRegions), 8) + "\n"
}

// TOTAL line straight from llvm-cov.
if let total = report.out.components(separatedBy: "\n").first(where: { $0.hasPrefix("TOTAL") }) {
    out += "\n" + total + "\n"
}

print(out)

if let bp = baselinePath {
    let header = "<!-- Generated by scripts/coverage.swift. Do not edit by hand. -->\n\n```\n"
    try? (header + out + "```\n").write(toFile: repoRoot + "/" + bp, atomically: true, encoding: .utf8)
    print("==> wrote baseline to \(bp)")
}

if !failures.isEmpty {
    print("\n\(failures.count) file(s) below required region coverage:")
    for (f, req) in failures.sorted(by: { $0.0.regionPct < $1.0.regionPct }) {
        print("  " + pad(f.file, 56) + " " + pct(f.regionPct) + " < " + pct(req))
    }
    if gate {
        print("\nFAIL: coverage gate not met.")
        exit(1)
    } else {
        print("\n(report-only; pass --gate to enforce)")
    }
} else {
    print("\nAll in-scope files meet their required region coverage.")
}
