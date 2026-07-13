#!/usr/bin/env swift

// Final Wave mechanical traceability gate.
//
// Loads docs/coverage/final-wave-requirements.json and fails on:
//   - pending / deferred / partial matrix rows (closure requires done)
//   - duplicate requirement ids
//   - missing evidence paths (implementationFiles, tests, docs)
//   - SEM-* / COOK-* tags in cookbook oracles without matrix / evidence coverage
//   - DiagnosticCode.all vs catalog inventory drift (regex spot-check)
//
// Usage:
//   swift scripts/final-wave-traceability.swift

import Foundation

struct RequirementRow: Decodable {
    let id: String
    let status: String
    let implementationFiles: [String]
    let tests: [String]
    let docs: [String]
}

struct Failure: CustomStringConvertible {
    let message: String
    var description: String { message }
}

func repoRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}

func loadText(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
}

func pathExists(_ repo: URL, _ relative: String) -> Bool {
    let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }
    return FileManager.default.fileExists(atPath: repo.appendingPathComponent(trimmed).path)
}

func evidenceSuffixes(_ path: String) -> Bool {
    let lower = path.lowercased()
    return lower.hasSuffix(".swift")
        || lower.hasSuffix(".md")
        || lower.hasSuffix(".json")
        || lower.hasSuffix(".yml")
        || lower.hasSuffix(".yaml")
        || lower.hasSuffix(".meri")
        || lower.hasSuffix(".meridian")
        || lower.hasSuffix(".merconfig")
}

func extractTags(from text: String, pattern: String) -> Set<String> {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    var tags = Set<String>()
    regex.enumerateMatches(in: text, range: range) { match, _, _ in
        guard let match, match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text) else { return }
        tags.insert(String(text[swiftRange]))
    }
    return tags
}

func diagnosticInventorySpotCheck(repo: URL) -> [Failure] {
    let codeFile = repo.appendingPathComponent("Sources/MeridianCore/Diagnostics/DiagnosticCode.swift")
    let catalogFile = repo.appendingPathComponent("Sources/MeridianCore/Diagnostics/DiagnosticCodeCatalog.swift")
    guard let codeText = try? loadText(codeFile),
          let catalogText = try? loadText(catalogFile) else {
        return [Failure(message: "could not read DiagnosticCode sources for catalog spot-check")]
    }

    let allCount = codeText.components(separatedBy: "public static let ").count - 1
    let catalogCount = catalogText.components(separatedBy: ".init(.").count - 1
    // `public static let all` array is not a diagnostic; subtract one from static-let count heuristic.
    let staticLetCount = max(0, allCount - 1)
    if staticLetCount != catalogCount {
        return [Failure(message:
            "DiagnosticCode catalog drift: ~\(staticLetCount) static codes vs ~\(catalogCount) catalog entries")]
    }
    return []
}

let root = repoRoot()
var failures: [Failure] = []

let matrixURL = root.appendingPathComponent("docs/coverage/final-wave-requirements.json")
guard let matrixData = try? Data(contentsOf: matrixURL) else {
    fputs("error: missing \(matrixURL.path)\n", stderr)
    exit(1)
}

let rows: [RequirementRow]
do {
    rows = try JSONDecoder().decode([RequirementRow].self, from: matrixData)
} catch {
    fputs("error: invalid final-wave-requirements.json: \(error)\n", stderr)
    exit(1)
}

var seenIDs = Set<String>()
var matrixCorpus = ""
for row in rows {
    if seenIDs.contains(row.id) {
        failures.append(Failure(message: "duplicate matrix id: \(row.id)"))
    }
    seenIDs.insert(row.id)

    switch row.status {
    case "done":
        break
    case "partial", "pending", "deferred":
        failures.append(Failure(message: "matrix row \(row.id) status is \(row.status) (closure requires done)"))
    default:
        failures.append(Failure(message: "matrix row \(row.id) has unknown status \(row.status)"))
    }

    matrixCorpus += row.id + "\n"
    for path in row.implementationFiles + row.tests + row.docs where evidenceSuffixes(path) {
        if !pathExists(root, path) {
            failures.append(Failure(message: "\(row.id): missing evidence path \(path)"))
        }
    }
}

let evidenceFiles = [
    "docs/coverage/COOK_EVIDENCE.md",
    "docs/coverage/WAVE8_REQUIREMENTS.md",
    "docs/coverage/final-wave-requirements.json",
]
var evidenceCorpus = matrixCorpus
for relative in evidenceFiles {
    let url = root.appendingPathComponent(relative)
    if let text = try? loadText(url) {
        evidenceCorpus += text
    } else {
        failures.append(Failure(message: "missing evidence corpus file \(relative)"))
    }
}

let semanticsURL = root.appendingPathComponent("docs/cookbook/MERIDIAN_SEMANTICS.md")
let cookbookURL = root.appendingPathComponent("docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md")
let semanticsText = (try? loadText(semanticsURL)) ?? ""
let cookbookText = (try? loadText(cookbookURL)) ?? ""

let semTags = extractTags(from: semanticsText, pattern: #"\[?(SEM-(?:MOD-)?[0-9]+-[0-9]+)\]?"#)
for tag in semTags.sorted() where !evidenceCorpus.contains(tag) {
    failures.append(Failure(message: "SEM tag \(tag) in MERIDIAN_SEMANTICS.md lacks matrix/COOK/WAVE8 evidence"))
}

let cookTags = extractTags(from: cookbookText, pattern: #"(COOK-[A-Za-z0-9-]+)"#)
    .union(extractTags(from: semanticsText, pattern: #"(COOK-[A-Za-z0-9-]+)"#))
for tag in cookTags.sorted() {
    let base = tag.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)
        .prefix(2).joined(separator: "-")
    if evidenceCorpus.contains(tag) || evidenceCorpus.contains(base) {
        continue
    }
    failures.append(Failure(message: "COOK tag \(tag) in cookbook lacks COOK_EVIDENCE / matrix coverage"))
}

failures.append(contentsOf: diagnosticInventorySpotCheck(repo: root))

if failures.isEmpty {
    print("final-wave-traceability: OK (\(rows.count) matrix rows, \(semTags.count) SEM tags, \(cookTags.count) COOK tags)")
    exit(0)
}

fputs("final-wave-traceability: FAILED (\(failures.count) issue(s))\n", stderr)
for failure in failures {
    fputs("  - \(failure.message)\n", stderr)
}
exit(1)
