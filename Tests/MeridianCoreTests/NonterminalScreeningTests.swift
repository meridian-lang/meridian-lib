import Testing
@testable import MeridianCore

@Suite("Wave 5 nonterminal screening")
struct NonterminalScreeningTests {

    @Test("anchor masks include production anchors")
    func anchorMasks() throws {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let comparison = try #require(table.production(named: "comparison"))

        #expect(screen.anchorCount > 0)
        #expect(screen.anchorMask(for: comparison) != 0)
        #expect(screen.mask(for: "total amount is more than 500") & screen.anchorMask(for: comparison) != 0)
    }

    @Test("candidates skip productions with missing anchors")
    func candidates() {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let names = screen.candidates(for: "total amount is more than 500").map(\.name)

        #expect(names.contains("comparison"))
        #expect(!names.contains("template-loop"))
    }

    @Test("screening does not change parsed AST for supported expressions")
    func parserEquivalence() {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let source = "status is not active"
        let hasComparison = screen.candidates(for: source).contains { $0.name == "comparison" }
        #expect(hasComparison)

        let screened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: true)
            .parse(source)
        let unscreened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: false)
            .parse(source)
        #expect(screened.traceDescription(detail: .verbose) == unscreened.traceDescription(detail: .verbose))
    }

    @Test("parser benchmark reports both unscreened and screened modes")
    func parserBenchmark() {
        let result = ParserBenchmark().run(sentences: [
            "total amount is more than 500",
            "status is not active",
        ])

        #expect(result.sentenceCount == 2)
        #expect(result.screenedCandidateCount > 0)
        #expect(result.unscreenedSeconds >= 0)
        #expect(result.screenedSeconds >= 0)
    }

    @Test("screen keeps no-anchor productions eligible")
    func noAnchorProduction() {
        let production = GrammarProduction(
            name: "fallback",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`x`",
            summary: "Fallback production.",
            anchors: []
        )
        let screen = NonterminalScreen(table: GrammarTable(productions: [production]))

        #expect(screen.anchorCount == 0)
        #expect(screen.anchorMask(for: production) == 0)
        #expect(screen.candidates(for: "anything").map(\.name) == ["fallback"])
    }
}
