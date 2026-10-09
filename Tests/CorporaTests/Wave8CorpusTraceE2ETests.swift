import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 8 corpus trace E2E")
struct Wave8CorpusTraceE2ETests {
    struct CorpusFixture {
        let name: String
        let root: URL
        let vocabulary: Compiler.VocabularyInput
        let rulebook: RulebookInput
    }

    @Test("incident release health sentinel compiles temporal contrast hooks")
    func incidentReleaseHealthSentinel() throws {
        let swift = try compileSkill(
            corpus: "incident",
            stem: "releasehealthsentinel"
        )
        for needle in [
            "scope: .acrossAllRuns",
            "kind: .withinWindow(",
            "kind: .countInWindow(",
            "kind: .inARow("
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    @Test("etl pipeline reliability watch compiles monitor cadence and denominator contrast")
    func etlPipelineReliabilityWatch() throws {
        let swift = try compileSkill(
            corpus: "etl",
            stem: "pipelinereliabilitywatch"
        )
        for needle in [
            "runtime.registerMonitor(",
            "denominator: .runs",
            "denominator: .occurrences"
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    @Test("procedures ledger parity watch compiles statistical parity receipt flow")
    func proceduresLedgerParityWatch() throws {
        let swift = try compileSkill(
            corpus: "procedures",
            stem: "ledgerparitywatch"
        )
        for needle in [
            "TraceStatisticalQuery(",
            "denominator: .occurrences",
            "event: \"procedure.report\""
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    @Test("erp payment failure monitor compiles default-cadence monitor and streak hook")
    func erpPaymentFailureMonitor() throws {
        let swift = try compileSkill(
            corpus: "erp",
            stem: "paymentfailuremonitor"
        )
        for needle in [
            "runtime.registerMonitor(",
            "denominator: .runs",
            "kind: .inARow("
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    @Test("governance access review freshness compiles production trace capture policy")
    func governanceAccessReviewFreshness() throws {
        let swift = try compileSkill(
            corpus: "governance",
            stem: "accessreviewfreshness"
        )
        for needle in [
            "profile: .production",
            "\"request.list\": .hashOnly"
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    @Test("clinical handoff reliability monitor compiles privacy-safe tool scope")
    func clinicalHandoffReliabilityMonitor() throws {
        let swift = try compileSkill(
            corpus: "clinical",
            stem: "handoffreliabilitymonitor"
        )
        for needle in [
            "profile: .production",
            "\"patient.list\": .hashOnly",
            "\"vitals.read\": .redacted([\"patient\"])",
            "scopedTools:",
            "\"patient.list\"",
            "\"vitals.read\""
        ] {
            #expect(swift.contains(needle), Comment(rawValue: "Missing `\(needle)` in:\n\(swift)"))
        }
    }

    private func compileSkill(corpus: String, stem: String) throws -> String {
        let fixture = try loadFixture(corpus: corpus)
        let file = fixture.root.appendingPathComponent("skills/\(stem).meri")
        let source = try String(contentsOf: file, encoding: .utf8)
        let opts = CorpusCompileSupport.compilerOptions(
            moduleSearchPaths: CorpusCompileSupport.moduleSearchPaths(forCorpus: corpus, root: fixture.root),
            emitterOptions: SwiftEmitter.Options(
                namespaceEnum: IdentifierNaming.swiftTypeNameFromStem(file.deletingPathExtension().lastPathComponent)
            )
        )
        return try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file.lastPathComponent)], vocabularies: [fixture.vocabulary], rulebooks: [fixture.rulebook]))[file.lastPathComponent]!.swift
    }

    private func loadFixture(corpus: String) throws -> CorpusFixture {
        let root = Self.repoRoot().appendingPathComponent("corpora").appendingPathComponent(corpus)
        let vocabURL = root.appendingPathComponent("\(corpus).merconfig")
        let ruleURL = root.appendingPathComponent("\(corpus).merrules")
        return CorpusFixture(
            name: corpus,
            root: root,
            vocabulary: .init(
                name: corpus,
                file: vocabURL.lastPathComponent,
                source: try String(contentsOf: vocabURL, encoding: .utf8)
            ),
            rulebook: .init(
                name: corpus,
                file: ruleURL.lastPathComponent,
                source: try String(contentsOf: ruleURL, encoding: .utf8)
            )
        )
    }

    static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
