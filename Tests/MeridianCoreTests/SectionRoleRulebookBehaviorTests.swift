import Testing
@testable import MeridianCore

@Suite("Section roles and rulebook parser — behavioral coverage")
struct SectionRoleRulebookBehaviorTests {
    @Test("SectionRoleResolver marker matrix preserves marker-first semantics")
    func resolverMarkerMatrix() {
        let inert = SkillSectionRole.SectionMarker(inert: true, role: .procedure)
        let forcedProcedure = SkillSectionRole.SectionMarker(inert: false, role: .procedure)
        let bareInert = SkillSectionRole.SectionMarker(inert: true, role: nil)

        let inertDecision = SectionRoleResolver.decide(marker: inert, derivedRole: .invariants)
        #expect(inertDecision.resolved)
        #expect(inertDecision.fromMarker)
        #expect(!inertDecision.executes)
        #expect(inertDecision.recordedRole == "procedure")

        let forcedDecision = SectionRoleResolver.decide(marker: forcedProcedure, derivedRole: nil)
        #expect(forcedDecision.executes)
        #expect(forcedDecision.role == .procedure)

        let bareDecision = SectionRoleResolver.decide(marker: bareInert, derivedRole: .procedure)
        #expect(bareDecision.resolved)
        #expect(!bareDecision.executes)
        #expect(bareDecision.recordedRole == "inert")

        let derivedDecision = SectionRoleResolver.decide(marker: nil, derivedRole: .applicability)
        #expect(!derivedDecision.fromMarker)
        #expect(derivedDecision.executes)
        #expect(derivedDecision.recordedRole == "applicability")

        let unresolved = SectionRoleResolver.decide(marker: nil, derivedRole: nil)
        #expect(!unresolved.resolved)
        #expect(!unresolved.executes)
    }

    @Test("rulebook section aliases merge with builtins and custom headings compile")
    func rulebookAliasesDriveSectionBuilder() throws {
        let rulebook = try RulebookParser().parse("""
        === sections ===
        section "Repair missing back-links", "Fix links" -> procedure
        section "Guarantees" -> invariants
        """, file: "rules.merrules")

        #expect(rulebook.role(forHeading: "Repair missing back-links") == .procedure)
        #expect(rulebook.role(forHeading: "Fix links") == .procedure)
        #expect(rulebook.role(forHeading: "Guarantees") == .invariants)
        #expect(SkillSectionRole.builtinRole(forHeading: "Steps") == .procedure)

        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
        )).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
            ---
            rulebook: rules.merrules
            ---
            ## Repair missing back-links
            complete.
            """, file: "skill.meri")], vocabularies: [], rulebooks: [RulebookInput(name: "rules", file: "rules.merrules", source: """
            === sections ===
            section "Repair missing back-links" -> procedure
            """)]))["skill.meri"]!.swift

        #expect(swift.contains("complete(reason: nil, step:"), Comment(rawValue: swift))
        #expect(!swift.contains("_unresolved"), Comment(rawValue: swift))
    }

    @Test("rulebook parser rejects malformed section aliases and unknown roles")
    func rulebookSectionDiagnostics() {
        #expect(throws: CompilerError.self) {
            _ = try RulebookParser().parse("""
            === sections ===
            "Contract" -> invariants
            """, file: "rules.merrules")
        }

        #expect(throws: CompilerError.self) {
            _ = try RulebookParser().parse("""
            === sections ===
            section "Contract" invariants
            """, file: "rules.merrules")
        }

        #expect(throws: CompilerError.self) {
            _ = try RulebookParser().parse("""
            === sections ===
            section "Contract" -> executable
            """, file: "rules.merrules")
        }
    }

    @Test("SkillSectionBuilder preserves strict executable and non-executable section behavior")
    func sectionBuilderStrictness() throws {
        let executable = try MeridianParser(symbols: SymbolTable()).parse("""
        ## Custom Work (( role: procedure ))
        complete.

        ## Reference (( role: reference ))
        This prose is documentation only.
        """, file: "skill.meri")

        let custom = try #require(executable.skillSections.first { $0.heading == "Custom Work" })
        let reference = try #require(executable.skillSections.first { $0.heading == "Reference" })
        #expect(custom.executes)
        #expect(custom.role == "procedure")
        #expect(!reference.executes)
        #expect(executable.workflows.first?.body.statements.count == 1)

        #expect(throws: CompilerError.self) {
            _ = try MeridianParser(symbols: SymbolTable()).parse("""
            ## Custom Work
            complete.
            """, file: "skill.meri")
        }
    }
}
