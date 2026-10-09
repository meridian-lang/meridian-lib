import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime
import MeridianTestKit

// `swiftc -typecheck` gates moved out of the fast targets. Each invocation
// shells out to the host toolchain and dominates wall-clock time when the old
// `MERIDIAN_*_TYPECHECK=1` env vars were set on a full `swift test` run.

@Suite("SKILL corpus — golden Swift type-check (slow)")
struct SkillCorpusGoldenTypecheckSlowTests {
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

    @Test("each golden type-checks against MeridianRuntime")
    func typecheckAllGoldens() throws {
        let root = SwiftTypecheckSupport.packageRoot(from: #file)
        let goldenDir = root.appendingPathComponent("examples/golden/skill")
        let artifacts = try SwiftTypecheckSupport.locateArtifacts(packageRoot: root)
        var failures: [String] = []
        for sample in Self.samples {
            let golden = goldenDir.appendingPathComponent(
                (sample as NSString).deletingPathExtension + ".expected.swift"
            )
            guard FileManager.default.fileExists(atPath: golden.path) else {
                failures.append("\(sample): missing golden at \(golden.path)")
                continue
            }
            let result = SwiftTypecheckSupport.typecheck(file: golden, artifacts: artifacts)
            if !result.ok { failures.append("\(sample): \(result.message)") }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "type-check failures:\n" + failures.joined(separator: "\n\n")))
    }
}

@Suite("Wave 6 synthetic corpora — type-check (slow)")
struct CorporaTypecheckSlowTests {
    struct Corpus {
        let name: String
        let vocabulary: Compiler.VocabularyInput
        let rulebook: RulebookInput
        let files: [URL]
    }

    static func corpora() throws -> [Corpus] {
        let root = SwiftTypecheckSupport.packageRoot(from: #file)
        return try ["erp", "procedures", "incident", "etl", "governance", "clinical"].map { name in
            let corpusRoot = root.appendingPathComponent("corpora").appendingPathComponent(name)
            let vocabURL = corpusRoot.appendingPathComponent("\(name).merconfig")
            let ruleURL = corpusRoot.appendingPathComponent("\(name).merrules")
            let skills = try FileManager.default.contentsOfDirectory(
                at: corpusRoot.appendingPathComponent("skills"), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "meri" }
            let files = (skills + [corpusRoot.appendingPathComponent("RESOLVER.meri")])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            return Corpus(
                name: name,
                vocabulary: .init(
                    name: name,
                    file: vocabURL.lastPathComponent,
                    source: try String(contentsOf: vocabURL, encoding: .utf8)),
                rulebook: .init(
                    name: name,
                    file: ruleURL.lastPathComponent,
                    source: try String(contentsOf: ruleURL, encoding: .utf8)),
                files: files
            )
        }
    }

    @Test("every emitted synthetic corpus file type-checks against MeridianRuntime")
    func everySkillTypechecks() throws {
        let root = SwiftTypecheckSupport.packageRoot(from: #file)
        let artifacts = try SwiftTypecheckSupport.locateArtifacts(packageRoot: root)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-corpora-typecheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var failures: [String] = []
        for (name, swift) in try compileAll() {
            let file = tmp.appendingPathComponent(name.replacingOccurrences(of: "/", with: "_") + ".swift")
            try swift.write(to: file, atomically: true, encoding: .utf8)
            let result = SwiftTypecheckSupport.typecheck(file: file, artifacts: artifacts)
            if !result.ok { failures.append("\(name):\n\(result.message)") }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "Synthetic corpus type-check failures:\n" + failures.joined(separator: "\n\n")))
    }

    private func compileAll() throws -> [(name: String, swift: String)] {
        let packageRoot = SwiftTypecheckSupport.packageRoot(from: #file)
        return try Self.corpora().flatMap { corpus in
            var moduleSearchPaths: [URL] = []
            if corpus.name == "governance" {
                moduleSearchPaths = [
                    packageRoot
                        .appendingPathComponent("corpora")
                        .appendingPathComponent(corpus.name)
                        .appendingPathComponent("modules")
                ]
            }
            return try corpus.files.map { file in
                let source = try String(contentsOf: file, encoding: .utf8)
                let opts = Compiler.Options(
                    emitterOptions: SwiftEmitter.Options(
                        namespaceEnum: IdentifierNaming.swiftTypeNameFromStem(
                            file.deletingPathExtension().lastPathComponent)),
                    moduleSearchPaths: moduleSearchPaths
                )
                let swift = try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file.lastPathComponent)], vocabularies: [corpus.vocabulary], rulebooks: [corpus.rulebook]))[file.lastPathComponent]!.swift
                return ("\(corpus.name)/\(file.lastPathComponent)", swift)
            }
        }
    }
}

@Suite("sample-gbrain — type-check (slow)")
struct SampleGbrainTypecheckSlowTests {
    private func sampleRoot() -> URL {
        SwiftTypecheckSupport.packageRoot(from: #file).appendingPathComponent("sample-gbrain")
    }

    private func namespace(for file: URL) -> String {
        let stem = file.deletingPathExtension().lastPathComponent
        let parts = stem.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        guard let first = joined.first else { return "Skill" }
        return first.isNumber ? "_" + joined : joined
    }

    private func compileAll() throws -> [(name: String, swift: String)] {
        let root = sampleRoot()
        let vocab = Compiler.VocabularyInput(
            name: "brain",
            file: "brain.merconfig",
            source: try String(contentsOf: root.appendingPathComponent("brain.merconfig"), encoding: .utf8)
        )
        let rulebook = RulebookInput(
            name: "brain",
            file: "brain.merrules",
            source: try String(contentsOf: root.appendingPathComponent("brain.merrules"), encoding: .utf8)
        )
        var files = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("skills"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "meri" }
        files.append(root.appendingPathComponent("RESOLVER.meri"))
        return try files.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { file in
            let source = try String(contentsOf: file, encoding: .utf8)
            let opts = Compiler.Options(
                emitterOptions: SwiftEmitter.Options(namespaceEnum: namespace(for: file)),
            )
            let swift = try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file.lastPathComponent)], vocabularies: [vocab], rulebooks: [rulebook]))[file.lastPathComponent]!.swift
            return (file.lastPathComponent, swift)
        }
    }

    @Test("every emitted Swift file type-checks against MeridianRuntime")
    func everySkillTypechecks() throws {
        let root = SwiftTypecheckSupport.packageRoot(from: #file)
        let artifacts = try SwiftTypecheckSupport.locateArtifacts(packageRoot: root)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-gbrain-typecheck-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        var failures: [String] = []
        for (name, swift) in try compileAll() {
            let file = tmp.appendingPathComponent((name as NSString).deletingPathExtension + ".swift")
            try swift.write(to: file, atomically: true, encoding: .utf8)
            let result = SwiftTypecheckSupport.typecheck(file: file, artifacts: artifacts)
            if !result.ok { failures.append("\(name):\n\(result.message)") }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "type-check failures:\n" + failures.joined(separator: "\n\n")))
    }
}
