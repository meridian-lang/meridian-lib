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

    @Test("legacy lint diagnostics bridge from structured diagnostics")
    func legacyDiagnosticsBridge() {
        let range = SourceRange(file: "lint.meri", line: 4, column: 2)
        let diagnostic = Diagnostic.warning(
            .lintPoliteCommand,
            message: "polite command wording",
            range: range,
            help: "Drop `please`."
        )
        let legacy = LintDiagnostic(diagnostic)
        #expect(legacy.line == 4)
        #expect(legacy.severity == "warning")
        #expect(legacy.code == DiagnosticCode.lintPoliteCommand)
        #expect(legacy.message == "polite command wording")
        #expect(legacy.hint == "Drop `please`.")

        let manual = LintDiagnostic(line: 2, severity: "warning", code: .lintUncertainty, message: "maybe", hint: "use discretion")
        #expect(manual.line == 2)
        #expect(manual.code == DiagnosticCode.lintUncertainty)

        let bridged = MeridianLinter().lintLegacy(source: "please resolve the comment.")
        #expect(bridged.contains { $0.code == .lintPoliteCommand && $0.hint?.contains("please") == true })
    }

}
