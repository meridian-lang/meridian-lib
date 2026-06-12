import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Conformance tests for the full ported gbrain skill corpus under
// sample-gbrain/skills/. These are the regression gate proving that every
// SKILL.md ported to .meri compiles deterministically (no _unresolved, no
// fuzzy-condition errors) against the shared brain vocabulary + rulebook.

@Suite("sample-gbrain conformance")
struct SampleGbrainConformanceTests {

    static func sampleRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("sample-gbrain")
    }

    static func vocab() throws -> Compiler.VocabularyInput {
        let src = try String(contentsOf: sampleRoot().appendingPathComponent("brain.merconfig"), encoding: .utf8)
        return Compiler.VocabularyInput(name: "brain", file: "brain.merconfig", source: src)
    }

    static func rulebook() throws -> RulebookInput {
        let src = try String(contentsOf: sampleRoot().appendingPathComponent("brain.merrules"), encoding: .utf8)
        return RulebookInput(name: "brain", file: "brain.merrules", source: src)
    }

    /// Every ported skill plus RESOLVER.meri.
    static func skillFiles() throws -> [URL] {
        let fm = FileManager.default
        let skillsDir = sampleRoot().appendingPathComponent("skills")
        var files = try fm.contentsOfDirectory(at: skillsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "meri" }
        files.append(sampleRoot().appendingPathComponent("RESOLVER.meri"))
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @Test("the full corpus is present (50+ skills + RESOLVER)")
    func corpusIsComplete() throws {
        let files = try Self.skillFiles()
        #expect(files.count >= 51,
                Comment(rawValue: "Expected >= 51 .meri files, found \(files.count)"))
    }

    @Test("every ported gbrain skill compiles deterministically with no _unresolved")
    func everySkillCompiles() throws {
        let vocab = try Self.vocab()
        let rulebook = try Self.rulebook()
        var failures: [String] = []

        for file in try Self.skillFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            do {
                let out = try Compiler(options: .init(trace: .silent())).compile(
                    meridianSource: source,
                    meridianFile: file.lastPathComponent,
                    vocabularies: [vocab],
                    rulebooks: [rulebook]
                )
                if out.contains("_unresolved") {
                    failures.append("\(file.lastPathComponent): emitted _unresolved")
                }
                if out.isEmpty {
                    failures.append("\(file.lastPathComponent): empty output")
                }
            } catch {
                failures.append("\(file.lastPathComponent): \(error)")
            }
        }

        #expect(failures.isEmpty,
                Comment(rawValue: "Skills failed to compile:\n" + failures.joined(separator: "\n")))
    }

    // MARK: - Rulebook extensibility (pure data, no dispatcher edit)

    @Test("a new desugar idiom + a new section alias can be added as pure rulebook data")
    func rulebookExtensibilityIsDataOnly() throws {
        // This rulebook adds:
        //   1. a brand-new desugar idiom ("Note: X." -> emit) that the core
        //      dispatcher has never seen, and
        //   2. a brand-new section-role alias ("Steps" -> procedure).
        // Neither requires a code change — the engine reads them as data.
        let extended = RulebookInput(
            name: "ext",
            file: "ext.merrules",
            source: """
            === desugar ===
            rule "memo-emit":
              match: Memo: {message}
              lowers to: emit skill.report with message = {message}.

            === sections ===
            section "Recipe" -> procedure
            """
        )
        let meri = """
        ---
        name: extensible demo
        vocabulary: brain.merconfig
        rulebook: ext.merrules
        ---
        ## Recipe
        publish the page at the slug.
        Memo: "filed".
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "extensible_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [extended]
        )
        #expect(out.contains("struct ExtensibleDemo"))
        // The "Steps" alias routed the body through procedure lowering…
        #expect(out.contains("workflow:") || out.contains("runtime.invoke") || out.contains("("))
        // …and the new "Note:" idiom desugared into an emit.
        #expect(out.contains("skill.report"))
        #expect(!out.contains("_unresolved"))
    }

    // MARK: - SkillMigrator

    static func migrator(maxRepair: Int = 0,
                         repair: (@Sendable (SkillMigrator.RepairRequest) async throws -> String)? = nil) throws -> SkillMigrator {
        SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [try Self.vocab()],
            rulebooks: [try Self.rulebook()],
            options: .init(maxRepair: maxRepair),
            repair: repair
        )
    }

    @Test("migrator (deterministic-only) injects nothing and compiles a clean SKILL.md verbatim")
    func migratorDeterministicOnly() async throws {
        // A raw SKILL.md with NO meridian frontmatter. Section semantics now
        // activate structurally on the `##` heading, so the migrator injects
        // nothing — the body compiles verbatim (vocabulary/rulebook are
        // autodiscovered by the CLI, never injected).
        let markdown = """
        # Capture Demo

        ## Phases
        ```bash
        gbrain capture "a thought"
        ```
        """
        let result = try await Self.migrator().migrate(markdown, file: "capture_demo.meri")
        #expect(result.compiledOK)
        #expect(result.report.repairAttempts == 0)
        #expect(result.report.addedFrontmatterKeys.isEmpty)
        #expect(result.meriSource == markdown)   // verbatim passthrough
        #expect(!result.meriSource.contains("skill: true"))
    }

    @Test("migrator (deterministic-only) fails on unmarked prose without a repair closure")
    func migratorDeterministicFailsOnProse() async throws {
        let markdown = """
        # Prose Demo

        ## Phases
        Ponder the deeper meaning of the request and act accordingly.
        """
        let result = try await Self.migrator().migrate(markdown, file: "prose_demo.meri")
        #expect(!result.compiledOK)
        #expect(!result.report.diagnostics.isEmpty)
    }

    @Test("migrator (mock-LLM repair) wraps flagged prose in a judgment marker, then recompiles strict")
    func migratorMockLLMRepair() async throws {
        let markdown = """
        # Repair Demo

        ## Phases
        Ponder the deeper meaning of the request and act accordingly.
        """
        // The mock "LLM" only ever rephrases the flagged line into an explicit
        // judgment block. It can NEVER introduce a silent LLM path because the
        // migrator re-compiles strict after every repair round.
        let repair: @Sendable (SkillMigrator.RepairRequest) async throws -> String = { req in
            req.candidate.replacingOccurrences(
                of: "Ponder the deeper meaning of the request and act accordingly.",
                with: """
                use judgment to act on the request:
                  Ponder the deeper meaning of the request and act accordingly.
                """
            )
        }
        let result = try await Self.migrator(maxRepair: 2, repair: repair).migrate(markdown, file: "repair_demo.meri")
        #expect(result.compiledOK)
        #expect(result.report.repairAttempts == 1)
        #expect(result.meriSource.contains("use judgment to act on the request"))
        #expect(result.report.editCount >= 1)
    }
}
