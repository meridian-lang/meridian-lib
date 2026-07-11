import Testing
@testable import MeridianCore

@Suite("SkillMigrator — migrate repair loop")
struct SkillMigratorCoverageTests {

    private static let vocab = Compiler.VocabularyInput(
        name: "t",
        file: "t.merconfig",
        source: """
        === vocabulary ===
        thing is a kind of thing.
        """
    )

    @Test("knowledgeContext builds symbols from migrator vocab inputs")
    func knowledgeContextBuilds() throws {
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab]
        )
        let ctx = try migrator.knowledgeContext()
        #expect(ctx.symbols.kinds["thing"] != nil)
    }

    @Test("migrate stops after repair rounds exhaust without fixing the candidate")
    func migrateStopsAfterMaxRepair() async throws {
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 1),
            repair: { $0.candidate }
        )
        let result = try await migrator.migrate("""
        ---
        vocabulary: missing.merconfig
        ---
        ## Steps
        Complete the task.
        """)
        #expect(!result.compiledOK)
        #expect(result.report.repairAttempts == 1)
    }
    @Test("migrate invokes repair when the compile error is not section-markable")
    func migrateInvokesRepairClosure() async throws {
        // "Complete the task." never lowers even after the repair closure
        // fixes the vocabulary reference (no matching phrase in `Self.vocab`)
        // — routeFuzzy opts into the compile-retry rescue so the section
        // still ends up `(( role: reference ))` and compiles, after the
        // repair closure has already been exercised at least once.
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 2, routeFuzzy: true),
            repair: { request in
                request.candidate.replacingOccurrences(
                    of: "vocabulary: missing.merconfig",
                    with: "vocabulary: t.merconfig"
                )
            }
        )
        let result = try await migrator.migrate("""
        ---
        vocabulary: missing.merconfig
        ---
        ## Steps
        Complete the task.
        """)
        #expect(result.report.repairAttempts >= 1)
        #expect(result.compiledOK)
    }

    @Test("migrate records line-prefixed diagnostics when strict compile fails")
    func migrateRecordsSemanticDiagnostics() async throws {
        // No checkable/inference signal under "Phases" is a hard migration
        // error by default (P1 category 4); routeFuzzy opts into the
        // compile-retry rescue so this still ends up compiling once its own
        // diagnostics have been recorded.
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 0, routeFuzzy: true)
        )
        let result = try await migrator.migrate("""
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """)
        #expect(result.compiledOK)
        #expect(result.report.diagnostics.allSatisfy { $0.primaryRange.startLine > 0 })
        #expect(result.report.diagnostics.contains { $0.code == .migrationRouteFuzzyDowngrade })
        #expect(!result.report.diagnostics.isEmpty)
    }

    @Test("migrate leaves diagnostics when compile cannot recover")
    func migrateLeavesDiagnosticsOnFailure() async throws {
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 0)
        )
        let result = try await migrator.migrate("""
        ---
        vocabulary: missing.merconfig
        ---
        ## Steps
        Complete the task.
        """)
        #expect(!result.compiledOK)
        #expect(result.report.diagnostics.contains { $0.primaryRange.startLine > 0 })
    }

    @Test("migrate threads procedure section aliases through strict compile")
    func migrateThreadsProcedureAliases() async throws {
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 0)
        )
        let result = try await migrator.migrate("""
        ## How to use

        ```bash
        echo hello
        ```
        """)
        #expect(result.compiledOK)
        #expect(result.sectionAliases.contains { $0.heading == "How to use" && $0.role == .procedure })
    }
}
