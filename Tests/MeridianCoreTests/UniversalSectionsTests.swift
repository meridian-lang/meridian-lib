import Foundation
import Testing
@testable import MeridianCore

// Coverage for the universal, strictly-deterministic markdown-section model:
// structural `hasHeadings` discriminator, the `(( inert ))` / `(( inert, role: R ))`
// / `(( role: R ))` marker family, no-silent-drop hard errors, blockquote-as-
// comment, and the mandatory `meridian_skill.sections` manifest plumbing.

@Suite("Universal sections — markers and roles")
struct UniversalSectionMarkerTests {

    private func parse(_ source: String, file: String = "skill.meri") throws -> MeridianFile {
        try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse(source, file: file)
    }

    @Test("(( inert )) records role inert and executes nothing")
    func bareInert() throws {
        let ast = try parse("""
        ## Philosophy (( inert ))
        Knowledge compounds when it is densely linked.

        ## Steps
        complete.
        """)
        let philosophy = try #require(ast.skillSections.first { $0.heading == "Philosophy" })
        #expect(philosophy.role == "inert")
        #expect(philosophy.executes == false)
        #expect(philosophy.lines.contains { $0.contains("Knowledge compounds") })
        // The procedure section still runs.
        #expect(ast.workflows.first?.body.statements.count == 1)
    }

    @Test("(( inert, role: R )) keeps the label but stays non-executable")
    func inertWithRole() throws {
        let ast = try parse("""
        ## Contract (( inert, role: invariants ))
        This skill guarantees safe, idempotent writes.

        ## Steps
        complete.
        """)
        let contract = try #require(ast.skillSections.first { $0.heading == "Contract" })
        #expect(contract.role == "invariants")
        #expect(contract.executes == false)
    }

    @Test("(( role: R )) forces an executable role over heading derivation")
    func forcedExecutableRole() throws {
        let ast = try parse("""
        ## Preconditions (( role: invariants ))
        the connection count is at least 20.

        ## Steps
        complete.
        """)
        let pre = try #require(ast.skillSections.first { $0.heading == "Preconditions" })
        #expect(pre.role == "invariants")
        #expect(pre.executes == true)
        // The invariant lowers to an assert in the implicit body, before the
        // procedure's complete.
        #expect((ast.workflows.first?.body.statements.count ?? 0) >= 2)
    }

    @Test("(( role: template )) is recognized but non-executable")
    func forcedTemplateRole() throws {
        let ast = try parse("""
        ## Shape (( role: template ))
        one bullet per finding.

        ## Steps
        complete.
        """)
        let shape = try #require(ast.skillSections.first { $0.heading == "Shape" })
        #expect(shape.role == "template")
        #expect(shape.executes == false)
    }

    @Test("phase-prefixed headings resolve to procedure without an alias")
    func phasePrefixProcedure() throws {
        let ast = try parse("""
        ## Phase 1: Inventory
        complete.
        """)
        let phase = try #require(ast.skillSections.first { $0.heading.hasPrefix("Phase 1") })
        #expect(phase.role == "procedure")
        #expect(phase.executes == true)
    }
}

@Suite("Universal sections — no silent drops (hard errors)")
struct UniversalSectionErrorTests {

    private func parse(_ source: String, file: String = "skill.meri") throws -> MeridianFile {
        try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse(source, file: file)
    }

    @Test("unrecognized heading with content is a hard error")
    func unrecognizedHeadingErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            ## What This Is
            A narrative paragraph that maps to no role.
            """)
        }
    }

    @Test("content before the first heading is a hard error")
    func preambleContentErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            Some intro prose with no heading above it.

            ## Steps
            complete.
            """)
        }
    }

    @Test("non-checkable invariant item is a hard error")
    func nonCheckableInvariantErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            ## Contract
            This skill guarantees idempotent writes.
            """)
        }
    }

    @Test("unknown role marker term is a hard error")
    func unknownRoleMarkerErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            ## Steps (( role: nonsense ))
            complete.
            """)
        }
    }

    @Test("blockquote and # lines may precede the first heading as comments")
    func blockquotePreambleAllowed() throws {
        let ast = try parse("""
        > **Convention:** all writes are idempotent.
        # an ordinary comment

        ## Steps
        complete.
        """)
        #expect(ast.workflows.first?.body.statements.count == 1)
    }
}

@Suite("Universal sections — mandatory manifest plumbing")
struct UniversalSectionManifestTests {

    @Test("blockquote line tokenizes as a comment")
    func blockquoteIsComment() {
        let lines = IndentTokenizer().tokenize("> a quoted aside")
        #expect(lines[0].isComment)
        #expect(lines[0].isContent == false)
    }

    @Test("meridian_skill.sections round-trips every marker form and is deterministic")
    func sectionsManifestRoundTrip() throws {
        let ast = try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse("""
        ## Philosophy (( inert ))
        Prose rationale.

        ## Output Shape (( inert, role: template ))
        one bullet per finding.

        ## Preconditions (( role: invariants ))
        the connection count is at least 20.

        ## Phase 1: Inventory
        complete.
        """, file: "skill.meri")

        let input = ManifestEmitter.Input(
            workflows: [],
            outline: ast.outline,
            skillSections: ast.skillSections.map {
                ManifestEmitter.SkillSectionEntry(
                    heading: $0.heading, role: $0.role, executes: $0.executes,
                    lines: $0.lines, line: $0.line)
            }
        )
        let emitter = ManifestEmitter()
        let first = try emitter.emit(input)
        let second = try emitter.emit(input)
        #expect(first == second)   // deterministic (sortedKeys + source order)

        let data = try #require(first.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["meridian_skill"] as? [String: Any])
        let sections = try #require(skill["sections"] as? [[String: Any]])

        func section(_ heading: String) throws -> [String: Any] {
            try #require(sections.first { ($0["heading"] as? String) == heading })
        }
        #expect(try section("Philosophy")["role"] as? String == "inert")
        #expect(try section("Philosophy")["executes"] as? Bool == false)
        #expect(try section("Output Shape")["role"] as? String == "template")
        #expect(try section("Output Shape")["executes"] as? Bool == false)
        #expect(try section("Preconditions")["role"] as? String == "invariants")
        #expect(try section("Preconditions")["executes"] as? Bool == true)
        #expect(try section("Phase 1: Inventory")["role"] as? String == "procedure")

        // outline[].kind follows the resolved role of the section it heads.
        let outline = try #require(skill["outline"] as? [[String: Any]])
        let philosophyOutline = try #require(outline.first { ($0["text"] as? String) == "Philosophy" })
        #expect(philosophyOutline["kind"] as? String == "inert")
    }
}
