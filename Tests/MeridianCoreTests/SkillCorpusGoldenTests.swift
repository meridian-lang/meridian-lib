import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - SKILL corpus golden Swift
//
// Each sample under `examples/skill/*.{meridian,meri}` is compiled against its
// declared vocabulary and the generated Swift is diffed against a checked-in
// golden under `examples/golden/skill/<basename>.expected.swift`.
//
// Re-baseline by setting `MERIDIAN_REGEN_GOLDENS=1` in the environment. CI must
// not have that variable set, so silent drift is impossible.
//
// Each sample is also fed to `swiftc -typecheck` (linking against the built
// `MeridianRuntime` module) in `Tests/MeridianSlowIntegrationTests/
// GeneratedSwiftTypecheckSlowTests.swift` so uncompilable Swift fails loudly.

@Suite("SKILL corpus — golden Swift")
struct SkillCorpusGoldenTests {

    // MARK: - Repo navigation

    private func packageRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }

    private func skillDir() -> URL {
        packageRoot().appendingPathComponent("examples/skill")
    }

    private func goldenDir() -> URL {
        packageRoot().appendingPathComponent("examples/golden/skill")
    }

    /// Vocabulary sources keyed by basename (the path written in the sample's
    /// frontmatter `vocabulary:` entry, after path resolution). Each sample
    /// declares exactly one vocabulary; we resolve it against the on-disk
    /// merconfig file and pass it to the compiler.
    private func loadVocab(_ path: String, relativeTo sample: URL) throws -> (name: String, file: String, source: String) {
        // Sample files live under `examples/skill/`; relative paths in their
        // `vocabulary:` field resolve from that directory (so `../github.merconfig`
        // points at `examples/github.merconfig`).
        let merconfigURL = sample.deletingLastPathComponent().appendingPathComponent(path)
        let canonical    = merconfigURL.standardized
        let basename     = canonical.lastPathComponent
        let stem         = (basename as NSString).deletingPathExtension
        let source = try String(contentsOf: canonical, encoding: .utf8)
        return (name: stem, file: basename, source: source)
    }

    // MARK: - Sample manifest
    //
    // Listed explicitly so a stray `.meridian` file dropped into examples/skill
    // doesn't auto-enroll. New samples must be added here intentionally.
    private static let samples: [String] = [
        "ci_fixer.meridian",
        "code_review.meridian",
        "customer_support.meridian",
        "customer_support_router.meridian",
        "dependency_upgrade_sweep.meri",
        "deployment_promotion.meri",
        "domain.meri",
        "flaky_ci_stabilizer.meri",
        "hotfix_commander.meridian",
        "incident_pr_response.meri",
        "incident_response.meridian",
        "large_release_train.meridian",
        "merge_conflict_playbook.meridian",
        "multi_host_demo.meridian",
        "planner_schema_validation_demo.meri",
        "policy_guarded_autonomy.meridian",
        "release_orchestrator.meridian",
        "review_comment_refactor.meri",
        "security_review_triage.meridian",
    ]

    // MARK: - Compile

    private func compile(sampleBasename: String) throws -> String {
        let sampleURL = skillDir().appendingPathComponent(sampleBasename)
        let merSource = try String(contentsOf: sampleURL, encoding: .utf8)

        // Read the first `vocabulary:` line from frontmatter and resolve it.
        let lines = merSource.components(separatedBy: "\n")
        var vocabPath: String? = nil
        var inFM = false
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "---" {
                if !inFM { inFM = true; continue }
                break
            }
            if inFM, t.lowercased().hasPrefix("vocabulary:") {
                let raw = String(t.dropFirst("vocabulary:".count))
                vocabPath = raw.split(separator: ",").first.map {
                    $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "\"'"))
                }
                break
            }
        }
        guard let path = vocabPath else {
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .internalError,
                    message: "no vocabulary declared in frontmatter for \(sampleBasename)",
                    range: SourceRange(file: sampleBasename, line: 1, column: 1)
                )
            ])
        }
        let vocab = try loadVocab(path, relativeTo: sampleURL)

        // Autodiscover every sibling `.merrules` beside the sample so the
        // universal-section model can resolve organizational step headings via
        // `=== sections ===` aliases (the CLI does the same autodiscovery).
        let rulebooks = try siblingRulebooks(of: sampleURL)

        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: false,
                sourceFileName: sampleBasename,
                emitSourceLineComments: false
            )
        )
        return try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: merSource, file: sampleBasename)], vocabularies: [.init(name: vocab.name, file: vocab.file, source: vocab.source)], rulebooks: rulebooks))[sampleBasename]!.swift
    }

    /// Load every `.merrules` in the sample's directory (sorted for determinism).
    private func siblingRulebooks(of sample: URL) throws -> [RulebookInput] {
        let dir = sample.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "merrules" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                RulebookInput(
                    name: url.deletingPathExtension().lastPathComponent,
                    file: url.lastPathComponent,
                    source: (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                )
            }
    }

    private func goldenURL(for sampleBasename: String) -> URL {
        let stem = (sampleBasename as NSString).deletingPathExtension
        return goldenDir().appendingPathComponent("\(stem).expected.swift")
    }

    // MARK: - Diff helper

    private func reportFirstDiff(actual: String, expected: String) -> String {
        let aLines = actual.split(separator: "\n",   omittingEmptySubsequences: false)
        let eLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
        var firstDiff = -1
        for i in 0 ..< min(aLines.count, eLines.count) where aLines[i] != eLines[i] {
            firstDiff = i; break
        }
        if firstDiff < 0 { firstDiff = min(aLines.count, eLines.count) }
        let context = 3
        let lo = max(0, firstDiff - context)
        let hi = min(max(aLines.count, eLines.count), firstDiff + context + 1)
        var report = "Golden diff at line \(firstDiff + 1):\n"
        for i in lo ..< hi {
            let a = i < aLines.count ? String(aLines[i]) : "<EOF>"
            let e = i < eLines.count ? String(eLines[i]) : "<EOF>"
            if a == e {
                report += "  \(i + 1): \(a)\n"
            } else {
                report += "- \(i + 1): \(e)\n"
                report += "+ \(i + 1): \(a)\n"
            }
        }
        report += "\nTo accept: re-run with MERIDIAN_REGEN_GOLDENS=1"
        return report
    }

    // MARK: - Tests (one per sample so failures localise)

    @Test("golden diff", arguments: SkillCorpusGoldenTests.samples)
    func goldenDiff(sample: String) throws {
        let actual = try compile(sampleBasename: sample)
        let golden = goldenURL(for: sample)

        if ProcessInfo.processInfo.environment["MERIDIAN_REGEN_GOLDENS"] != nil {
            try FileManager.default.createDirectory(
                at: golden.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try actual.write(to: golden, atomically: true, encoding: .utf8)
            return
        }

        guard FileManager.default.fileExists(atPath: golden.path) else {
            Issue.record(.init(rawValue: "Missing golden for \(sample). Generate with MERIDIAN_REGEN_GOLDENS=1."))
            return
        }
        let expected = try String(contentsOf: golden, encoding: .utf8)
        if actual == expected { return }
        Issue.record(.init(rawValue: reportFirstDiff(actual: actual, expected: expected)))
    }
}
