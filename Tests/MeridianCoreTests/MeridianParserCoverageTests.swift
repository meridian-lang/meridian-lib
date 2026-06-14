import Testing
@testable import MeridianCore

@Suite("MeridianParser — no-silent-drop error paths")
struct MeridianParserCoverageTests {
    private func compile(_ source: String) throws {
        _ = try Compiler(options: .init(trace: .silent()))
            .compile(meridianSource: source, meridianFile: "t.meridian", vocabularies: [])
    }

    @Test("body-level import is rejected")
    func bodyLevelImport() {
        #expect(throws: (any Error).self) {
            try compile("""
            import shipping.
            to do a thing:
                complete.
            """)
        }
    }

    @Test("frontmatter that is not the first entry is rejected")
    func frontmatterNotFirst() {
        #expect(throws: (any Error).self) {
            try compile("""
            to do a thing:
                complete.
            ---
            name: late
            ---
            """)
        }
    }

    @Test("a workflow header without a trailing colon is a structural error")
    func headerWithoutColon() {
        #expect(throws: (any Error).self) {
            try compile("""
            to do the thing
                complete.
            """)
        }
    }

    @Test("a well-formed minimal workflow compiles")
    func wellFormed() throws {
        try compile("""
        to do a thing:
            complete.
        """)
    }
}
