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

    @Test("text without an anaphora marker passes through")
    func noMarkerPassesThrough() throws {
        let resolved = try AnaphoraResolver().resolve(
            "summarize the report",
            referents: ["analysisResult"]
        )
        #expect(resolved == "summarize the report")
    }

    @Test("direct resolver reports ambiguous anaphora with referent notes")
    func directAmbiguousReferentThrows() throws {
        do {
            _ = try AnaphoraResolver().resolve(
                "summarize it",
                referents: ["first", "second"]
            )
            Issue.record("expected ambiguous anaphora")
        } catch let err as CompilerError {
            let diag = try #require(err.diagnostics.first { $0.code == .ambiguousAnaphora })
            #expect(diag.notes.first?.message.contains("first") == true)
            #expect(diag.notes.first?.message.contains("second") == true)
        }
    }

    @Test("empty referent list is ambiguous")
    func emptyReferentsThrow() throws {
        #expect(throws: CompilerError.self) {
            _ = try AnaphoraResolver().resolve(
                "summarize it",
                referents: []
            )
        }
    }

    @Test("resolver replaces every anaphora marker in the text")
    func replacesAllMarkers() throws {
        let resolved = try AnaphoraResolver().resolve(
            "connect it to them",
            referents: ["the content"]
        )
        #expect(resolved == "connect the content to the content")
    }
}
