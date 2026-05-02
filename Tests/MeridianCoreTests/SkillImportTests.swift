import Testing
@testable import MeridianCore

@Suite("SKILL.md import preview")
struct SkillImportTests {

    @Test("preview converts common markdown shapes")
    func previewMarkdown() {
        let out = SkillMarkdownImporter().preview("""
        # Babysit
        ## Comments
        Review every comment.
        - Complete unless blocked.
        ```meridian
        To helper:
          complete.
        ```
        """, name: "babysit")

        #expect(out.contains("name: babysit"))
        #expect(out.contains("## Comments"))
        #expect(out.contains("- Review every comment."))
        #expect(out.contains("To helper:"))
    }

    @Test("supported paraphrases lower to equivalent statement shapes")
    func paraphraseEquivalence() throws {
        let parser = StatementParser(symbols: SymbolTable(), trace: .silent())
        let unless = try parser.parseBlock(IndentTokenizer().tokenize("complete unless blocked."))
        let except = try parser.parseBlock(IndentTokenizer().tokenize("complete except when blocked."))

        guard case .conditional(let a) = unless.statements.first,
              case .conditional(let b) = except.statements.first else {
            Issue.record("Expected conditional statements")
            return
        }
        #expect(a.thenBlock.statements.count == b.thenBlock.statements.count)
        #expect(String(describing: a.condition) == String(describing: b.condition))
    }
}
