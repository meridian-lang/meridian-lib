import Testing
@testable import MeridianCore

@Suite("Meridian linter")
struct MeridianLinterTests {

    @Test("linter reports ambiguous anaphora with hint")
    func ambiguousAnaphora() {
        let diagnostics = MeridianLinter().lint(source: """
        bind comment = "c1".
        bind job = "j1".
        resolve it.
        """)
        #expect(diagnostics.contains { $0.severity == "error" && $0.message.contains("Ambiguous") })
        #expect(diagnostics.first?.hint?.contains("Spell out") == true)
    }

    @Test("linter suggests supported paraphrases")
    func paraphraseHints() {
        let diagnostics = MeridianLinter().lint(source: "please maybe resolve the comment.")
        #expect(diagnostics.contains { $0.severity == "info" })

        let infixMaybe = MeridianLinter().lint(source: "resolve maybe the comment.")
        #expect(infixMaybe.contains { $0.hint?.contains("discretion") == true })
    }

    @Test("linter ignores headings and keeps only the four most recent bind referents")
    func headingAndReferentWindow() {
        let diagnostics = MeridianLinter().lint(source: """
        ## Notes
        it is only documentation.
        bind first = "1".
        bind second = "2".
        bind third = "3".
        bind fourth = "4".
        bind fifth = "5".
        resolve it.
        """)

        #expect(diagnostics.contains { $0.line == 2 && $0.severity == "error" })
        #expect(diagnostics.contains { $0.line == 8 && $0.severity == "error" })
        #expect(!diagnostics.contains { $0.line == 1 })
    }

}
