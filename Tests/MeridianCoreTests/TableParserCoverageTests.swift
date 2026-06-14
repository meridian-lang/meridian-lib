import Testing
@testable import MeridianCore

@Suite("TableParser — cell→predicate mapping")
struct TableParserCoverageTests {
    private let tp = TableParser(lexicon: .default)

    private func table(_ header: [String], _ rows: [[String]]) -> TableParser.ParsedTable {
        TableParser.ParsedTable(header: header, rows: rows)
    }

    @Test("symbolic operator prefix renders the canonical spelling")
    func symbolicOps() {
        let texts = tp.decisionRowTexts(table(
            ["score", "action"],
            [[">= 90", "approve"], ["< 50", "reject"], ["!= 0", "flag"]]
        ))
        #expect(texts.count == 3)
        #expect(texts[0].contains("approve"))
        // The score column is rendered as a comparison, not a bare equality.
        #expect(texts[0].hasPrefix("if score "))
        #expect(!texts[0].contains(">="))
    }

    @Test("a comparison-marker shorthand cell is restored to canonical form")
    func shorthandMarker() {
        let texts = tp.decisionRowTexts(table(
            ["count", "action"],
            [["more than 5", "escalate"]]
        ))
        #expect(texts.first?.contains("more than 5") == true)
    }

    @Test("wildcard cells drop the column; an all-wildcard row is a bare action")
    func wildcards() {
        let texts = tp.decisionRowTexts(table(
            ["a", "b", "action"],
            [["*", "-", "fallback"]]
        ))
        #expect(texts == ["fallback"])
    }

    @Test("a bare multi-word value is quoted as a string equality")
    func bareValueQuoted() {
        let texts = tp.decisionRowTexts(table(
            ["status", "action"],
            [["needs review", "hold"]]
        ))
        #expect(texts.first?.contains("\"needs review\"") == true)
    }

    @Test("ai-decision prose renders one rule per row plus an otherwise fallback")
    func aiDecisionProse() {
        let prose = tp.aiDecisionProse(table(
            ["intent", "action"],
            [["user is frustrated", "apologize"], ["*", "continue"]]
        ))
        #expect(prose.contains("- when intent is user is frustrated, apologize"))
        #expect(prose.contains("- otherwise, continue"))
    }

    @Test("decode of a non-table sentinel returns nil")
    func decodeNonTable() {
        #expect(TableParser.decode("just some text") == nil)
    }

    @Test("splitRow trims pipes and cells")
    func splitRow() {
        #expect(TableParser.splitRow("| a | b | c |") == ["a", "b", "c"])
        #expect(TableParser.splitRow("a|b") == ["a", "b"])
    }
}
