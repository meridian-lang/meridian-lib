#!/usr/bin/env swift

// Zero-deferral mechanical scan for Final Wave closure.
//
// Scans active Sources/, Tests/, scripts/, and docs/ for user-facing deferral
// promises (TODO, FIXME, not implemented, later wave, deferred feature).
// Allowlisted categories:
//   - docs/21_OUT_OF_SCOPE.md permanent boundary prose
//   - docs/coverage/* audit and matrix status vocabulary
//   - documented internal-invariant false positives (see allowlist below)
//
// Usage:
//   swift scripts/forbidden-deferral-scan.swift

import Foundation

struct Hit: CustomStringConvertible {
    let file: String
    let line: Int
    let text: String
    var description: String { "\(file):\(line): \(text)" }
}

struct AllowRule {
    let fileSuffix: String?
    let lineContains: String?
    let reason: String

    func matches(file: String, line: String) -> Bool {
        if let suffix = fileSuffix, !file.hasSuffix(suffix) { return false }
        if let needle = lineContains, !line.contains(needle) { return false }
        return true
    }
}

let allowlist: [AllowRule] = [
    // Permanent out-of-scope boundary (entire file is the allowlist).
    AllowRule(fileSuffix: "docs/21_OUT_OF_SCOPE.md", lineContains: nil, reason: "permanent boundary"),

    // Coverage / audit docs use status vocabulary intentionally.
    AllowRule(fileSuffix: "docs/coverage/ZERO_DEFERRAL_AUDIT.md", lineContains: nil, reason: "audit evidence"),
    AllowRule(fileSuffix: "docs/coverage/FINAL_WAVE_REQUIREMENTS.md", lineContains: nil, reason: "matrix legend"),
    AllowRule(fileSuffix: "docs/coverage/WAVE8_REQUIREMENTS.md", lineContains: nil, reason: "wave8 matrix"),
    AllowRule(fileSuffix: "docs/coverage/WAVE8_COMPLETION_EVIDENCE.md", lineContains: nil, reason: "wave8 evidence"),
    AllowRule(fileSuffix: "docs/coverage/final-wave-requirements.json", lineContains: nil, reason: "matrix json"),

    // Exhaustive-switch maintenance lists (internal, non-user-facing).
    AllowRule(fileSuffix: "Sources/MeridianCore/Rulebook/Rulebook.swift",
              lineContains: "compile-time TODO list", reason: "exhaustive-switch list"),
    AllowRule(fileSuffix: "Sources/MeridianCore/Lowering/SkillTriggers.swift",
              lineContains: "TODO list", reason: "exhaustive-switch list"),

    // Parser deferred-marker transport (deferred *error*, not feature deferral).
    AllowRule(fileSuffix: "Sources/MeridianCore/Parser/Lexical/IndentTokenizer.swift",
              lineContains: "deferred", reason: "deferred marker plumbing"),
    AllowRule(fileSuffix: "Sources/MeridianCore/Parser/Productions/StatementParser.swift",
              lineContains: "deferred marker", reason: "deferred marker plumbing"),

    // Retired diagnostic catalog entry (MER0003).
    AllowRule(fileSuffix: "Sources/MeridianCore/Diagnostics/DiagnosticCode.swift",
              lineContains: "MER0003", reason: "retired not-implemented code"),

    // Compile-time rejection message for unsupported northstar producing clause.
    AllowRule(fileSuffix: "Sources/MeridianCore/IR/IRTypes.swift",
              lineContains: "not implemented", reason: "stable compile-time rejection"),

    // Domain enum vocabulary — not a feature backlog.
    AllowRule(fileSuffix: "Sources/MeridianRuntime/Wait/WaitCondition.swift",
              lineContains: "deferred", reason: "ApprovalVerdict enum case"),
    AllowRule(fileSuffix: "Sources/SampleDemoFlows/", lineContains: "deferred", reason: "domain enum"),

    // Negative assertions in tests.
    AllowRule(fileSuffix: "Tests/MeridianCoreTests/Inform7/VerbalizerTotalityTests.swift",
              lineContains: "#expect(!source.contains", reason: "negative grep gate"),

    // Historical note — Wave 9 shipped; update comment if touched.
    AllowRule(fileSuffix: "Tests/MeridianCoreTests/Inform7/CompositionGalleryTests.swift",
              lineContains: "deferred to Wave 9", reason: "historical suite comment"),

    // DX docs describing forbidden markers.
    AllowRule(fileSuffix: "docs/09_MERIDIAN_TESTS.md", lineContains: nil, reason: "test policy doc"),
    AllowRule(fileSuffix: "docs/14_DEVELOPER_EXPERIENCE.md", lineContains: "not implemented", reason: "MER0003 catalog doc"),
    AllowRule(fileSuffix: "docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md", lineContains: nil, reason: "design risks ledger"),
    AllowRule(fileSuffix: "docs/cookbook/INFORM7_DESIGN_NOTES.md", lineContains: "deferred", reason: "inform7 design sketch"),
    AllowRule(fileSuffix: "docs/status.md", lineContains: nil, reason: "historical status log"),
]

let scanRoots = ["Sources", "Tests", "scripts", "docs"]
let skipDirNames: Set<String> = [
    ".build", ".git", "checkouts", "compile-outputs", "migration-deviations",
    "original-skills", "implementation-log-archive",
]
let extensions: Set<String> = ["swift", "md"]

let patterns: [(name: String, regex: NSRegularExpression)] = [
    ("TODO", try! NSRegularExpression(pattern: #"\bTODO\b"#)),
    ("FIXME", try! NSRegularExpression(pattern: #"\bFIXME\b"#)),
    ("not implemented", try! NSRegularExpression(pattern: #"\bnot implemented\b"#, options: .caseInsensitive)),
    ("later wave", try! NSRegularExpression(pattern: #"later wave"#, options: .caseInsensitive)),
    ("deferred feature", try! NSRegularExpression(pattern: #"deferred feature"#, options: .caseInsensitive)),
    ("planned for later", try! NSRegularExpression(pattern: #"planned for later"#, options: .caseInsensitive)),
    ("not yet implemented", try! NSRegularExpression(pattern: #"not yet implemented"#, options: .caseInsensitive)),
]

func repoRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}

func relativePath(repo: URL, file: URL) -> String {
    let repoPath = repo.path + "/"
    let path = file.path
    if path.hasPrefix(repoPath) {
        return String(path.dropFirst(repoPath.count))
    }
    return path
}

func fileMatches(_ file: String, suffix: String) -> Bool {
    file == suffix || file.hasSuffix("/" + suffix) || file.hasSuffix(suffix)
}

func isAllowed(file: String, line: String) -> Bool {
    if file.contains("docs/coverage/") { return true }
    for rule in allowlist {
        if let suffix = rule.fileSuffix, !fileMatches(file, suffix: suffix) { continue }
        if let needle = rule.lineContains, !line.contains(needle) { continue }
        return true
    }
    return false
}

func scanFile(repo: URL, file: URL) -> [Hit] {
    let rel = relativePath(repo: repo, file: file)
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    var hits: [Hit] = []
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    for (index, lineSub) in lines.enumerated() {
        let line = String(lineSub)
        if isAllowed(file: rel, line: line) { continue }
        let nsRange = NSRange(line.startIndex..., in: line)
        for (name, regex) in patterns {
            if regex.firstMatch(in: line, range: nsRange) != nil {
                hits.append(Hit(file: rel, line: index + 1, text: name + " — " + line.trimmingCharacters(in: .whitespaces)))
            }
        }
    }
    return hits
}

func walk(repo: URL, directory: URL) -> [Hit] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    var hits: [Hit] = []
    for case let url as URL in enumerator {
        let name = url.lastPathComponent
        if url.hasDirectoryPath {
            if skipDirNames.contains(name) {
                enumerator.skipDescendants()
            }
            continue
        }
        guard extensions.contains(url.pathExtension) else { continue }
        let rel = relativePath(repo: repo, file: url)
        if rel.hasSuffix("scripts/forbidden-deferral-scan.swift")
            || rel.hasSuffix("scripts/final-wave-traceability.swift") {
            continue
        }
        hits.append(contentsOf: scanFile(repo: repo, file: url))
    }
    return hits
}

let repo = repoRoot()
var allHits: [Hit] = []
for rootName in scanRoots {
    let dir = repo.appendingPathComponent(rootName)
    if FileManager.default.fileExists(atPath: dir.path) {
        allHits.append(contentsOf: walk(repo: repo, directory: dir))
    }
}

if allHits.isEmpty {
    print("forbidden-deferral-scan: OK (no unallowlisted deferral promises)")
    exit(0)
}

fputs("forbidden-deferral-scan: FAILED (\(allHits.count) hit(s))\n", stderr)
for hit in allHits {
    fputs("  - \(hit)\n", stderr)
}
exit(1)
