import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Meridian linter")
struct MeridianLinterTests {

    @Test("linter reports ambiguous anaphora with hint")
    func ambiguousAnaphora() {
        let diagnostics = MeridianLinter().lint(source: """
        bind comment = "c1".
        bind job = "j1".
        resolve it.
        """)
        #expect(diagnostics.contains { $0.severity == .error && $0.code == .ambiguousAnaphora })
        #expect(diagnostics.first?.help?.contains("Spell out") == true)
        #expect(diagnostics.first?.primaryRange.startLine == 3)
    }

    @Test("linter suggests supported paraphrases")
    func paraphraseHints() {
        let diagnostics = MeridianLinter().lint(source: "please maybe resolve the comment.")
        #expect(diagnostics.contains { $0.severity == .warning && $0.code == .lintPoliteCommand })

        let infixMaybe = MeridianLinter().lint(source: "resolve maybe the comment.")
        #expect(infixMaybe.contains { $0.help?.contains("discretion") == true && $0.code == .lintUncertainty })

        let prefixMaybe = MeridianLinter().lint(source: "maybe resolve the comment.")
        #expect(prefixMaybe.contains { $0.severity == .warning && $0.code == .lintUncertainty })
    }

    @Test("SEM_5_11 across-all-runs in-a-row warns about interleaved ordering")
    func sem511CrossRunInARowWarning() {
        let diagnostics = MeridianLinter().lint(source: """
        if across all runs, the deploy step has failed 2 times in a row,
          complete.
        """)

        guard let warning = diagnostics.first(where: { $0.code == .lintCrossRunInARow }) else {
            Issue.record("expected MER6005, got \(diagnostics.map { $0.code.id })")
            return
        }
        #expect(warning.severity == .warning)
        #expect(warning.primaryRange.startLine == 1)
        #expect(warning.message.contains("cross-run `in a row`"))
        #expect(warning.help?.contains("deterministic trace ordering") == true)
        #expect(warning.help?.contains("current-run scope") == true)
        #expect(warning.help?.contains("times within the last <duration>") == true)
    }

    @Test("SEM_5_11 current-run in-a-row does not warn")
    func sem511CurrentRunNearMiss() {
        let diagnostics = MeridianLinter().lint(source: """
        if the deploy step has failed 2 times in a row,
          complete.
        """)

        #expect(!diagnostics.contains { $0.code == .lintCrossRunInARow },
                Comment(rawValue: diagnostics.map { "\($0.code.id): \($0.message)" }.joined(separator: "\n")))
    }

    @Test("SEM_5_11 count-in-window does not warn")
    func sem511CountInWindowNearMiss() {
        let diagnostics = MeridianLinter().lint(source: """
        if across all runs, the deploy step has failed at least 2 times within the last 7 days,
          complete.
        """)

        #expect(!diagnostics.contains { $0.code == .lintCrossRunInARow },
                Comment(rawValue: diagnostics.map { "\($0.code.id): \($0.message)" }.joined(separator: "\n")))
    }

    @Test("a superlative naming the since-the-last anchor's subject warns to split into two steps")
    func superlativeEventAnchorWarns() {
        let diagnostics = MeridianLinter().lint(source: """
        if since the last deploy of the most recent troubled service, no critical alert has occurred,
          complete.
        """)

        guard let warning = diagnostics.first(where: { $0.code == .lintSuperlativeEventAnchor }) else {
            Issue.record("expected lintSuperlativeEventAnchor, got \(diagnostics.map { $0.code.id })")
            return
        }
        #expect(warning.severity == .warning)
        #expect(warning.message.contains("superlative event-anchor wording"))
        #expect(warning.help?.contains("most recent") == true)
        #expect(warning.help?.contains("let the target be") == true)
    }

    @Test("an anchor with no superlative gradable word does not warn")
    func noSuperlativeEventAnchorNearMiss() {
        let diagnostics = MeridianLinter().lint(source: """
        if since the last production deploy, no critical alert has occurred,
          complete.
        """)

        #expect(!diagnostics.contains { $0.code == .lintSuperlativeEventAnchor },
                Comment(rawValue: diagnostics.map { "\($0.code.id): \($0.message)" }.joined(separator: "\n")))
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

        #expect(diagnostics.contains { $0.primaryRange.startLine == 2 && $0.severity == .error })
        #expect(diagnostics.contains { $0.primaryRange.startLine == 8 && $0.severity == .error })
        #expect(!diagnostics.contains { $0.primaryRange.startLine == 1 })
    }

    @Test("single bind referent resolves anaphora and suppresses MER3014")
    func singleReferentSuppressesAnaphora() {
        let diagnostics = MeridianLinter().lint(source: """
        bind comment = "c1".
        resolve it.
        """)

        #expect(!diagnostics.contains { $0.code == .ambiguousAnaphora },
                Comment(rawValue: diagnostics.map { "\($0.code.id): \($0.message)" }.joined(separator: "\n")))
    }
}
