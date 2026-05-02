import Testing
@testable import MeridianCore

@Suite("Anaphora resolution")
struct AnaphoraTests {

    @Test("single referent resolves it")
    func resolvesSingleReferent() throws {
        let block = try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize("""
            bind comment = "c1".
            resolve it.
            """))

        guard case .phraseInvocation(let phrase) = block.statements.last else {
            Issue.record("Expected phrase invocation")
            return
        }
        #expect(phrase.words == "resolve comment")
    }

    @Test("ambiguous referent throws")
    func ambiguousReferentThrows() throws {
        #expect(throws: CompilerError.self) {
            _ = try StatementParser(symbols: SymbolTable(), trace: .silent())
                .parseBlock(IndentTokenizer().tokenize("""
                bind comment = "c1".
                bind job = "j1".
                resolve it.
                """))
        }
    }

    @Test("that result resolves to the last single referent")
    func thatResult() throws {
        let resolved = try AnaphoraResolver().resolve(
            "summarize that result",
            referents: ["analysisResult"]
        )
        #expect(resolved == "summarize analysisResult")
    }
}
