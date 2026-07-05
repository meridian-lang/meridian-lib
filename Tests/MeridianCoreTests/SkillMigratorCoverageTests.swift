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
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 2),
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
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [Self.vocab],
            options: .init(maxRepair: 0)
        )
        let result = try await migrator.migrate("""
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """)
        #expect(result.compiledOK)
        #expect(result.report.diagnostics.allSatisfy { $0.hasPrefix("L") })
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
        #expect(result.report.diagnostics.contains { $0.hasPrefix("L") })
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
