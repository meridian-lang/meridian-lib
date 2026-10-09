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
        let parser = StatementParser(symbols: SymbolTable())
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

    @Test("preview preserves frontmatter wrapper and imports only meridian or plain fences")
    func previewFenceFilteringAndFrontmatter() {
        let out = SkillMarkdownImporter().preview("""
        # Demo
        Intro paragraph.

        ```meridian
        To helper:
          complete.
        ```

        ```python
        print("ignored")
        ```

        ```
        To plain helper:
          complete.
        ```
        """, name: "demo skill")

        #expect(out.hasPrefix("---\nname: demo skill\ndescription: Imported from SKILL.md preview.\n---"),
                Comment(rawValue: out))
        #expect(out.contains("- Intro paragraph."), Comment(rawValue: out))
        #expect(out.contains("To helper:"), Comment(rawValue: out))
        #expect(out.contains("To plain helper:"), Comment(rawValue: out))
        #expect(!out.contains("print(\"ignored\")"), Comment(rawValue: out))
        #expect(!out.contains("# Demo"), Comment(rawValue: out))
    }
}
