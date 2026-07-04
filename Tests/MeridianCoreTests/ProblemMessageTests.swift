import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Wave 5 problem messages")
struct ProblemMessageTests {

    private func range() -> SourceRange {
        SourceRange(file: "test.meridian", startLine: 1, startColumn: 1, endLine: 1, endColumn: 12)
    }

    @Test("template uses the Inform-style diagnostic voice")
    func templateVoice() {
        let message = ProblemMessage(
            read: "bind x =",
            reading: "a bind statement",
            problem: "there is no value after the equals sign",
            expectations: ["an expression", "an invocation"],
            rewrite: "bind x = 1."
        )

        #expect(message.message == "I read 'bind x =' as a bind statement, but there is no value after the equals sign. I expected an expression, an invocation.")
        #expect(message.help == "Rewrite as: bind x = 1.")
    }

    @Test("Diagnostic.problem carries message and rewrite help")
    func diagnosticFactory() {
        let diagnostic = Diagnostic.problem(
            .unparseableStatement,
            range: range(),
            read: "bind x =",
            as: "a bind statement",
            but: "there is no value after the equals sign",
            expected: ["an expression"],
            rewrite: "bind x = 1."
        )

        #expect(diagnostic.message.hasPrefix("I read 'bind x =' as a bind statement, but"))
        #expect(diagnostic.help == "Rewrite as: bind x = 1.")
        #expect(diagnostic.code == .unparseableStatement)
    }

    @Test("template has a default expectation sentence")
    func defaultExpectation() {
        let message = ProblemMessage(
            read: "???",
            reading: "source text",
            problem: "it does not match a production",
            expectations: [],
            rewrite: "use a documented Meridian form."
        )

        #expect(message.message.contains("I expected a supported Meridian form."))
    }

    @Test("catalog markdown includes active problem-message rows")
    func catalogMarkdown() {
        let markdown = ProblemMessageCatalog.renderMarkdown()

        #expect(markdown.contains("# Meridian Problem Messages"))
        #expect(markdown.contains("`MER1003`"))
        #expect(markdown.contains("malformed statement"))
        #expect(markdown.contains("Help Required"))
    }

    @Test("structural diagnostics can all use the problem-message shape")
    func structuralCodesCanUseProblemShape() {
        for code in DiagnosticCode.all where code.kind == .structural {
            let diagnostic = Diagnostic.problem(
                code,
                range: range(),
                read: "source",
                as: code.title,
                but: "the surface is incomplete",
                expected: ["a complete \(code.title)"],
                rewrite: "use the documented form."
            )

            #expect(diagnostic.message.hasPrefix("I read 'source' as"))
            #expect(diagnostic.help?.hasPrefix("Rewrite as:") == true)
        }
    }
}
