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
    }
}
