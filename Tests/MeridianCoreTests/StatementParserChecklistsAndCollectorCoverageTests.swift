import Foundation
import Testing
@testable import MeridianCore

@Suite("StatementParser+Checklists coverage")
struct StatementParserChecklistsCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable(), trace: .silent())

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(IndentTokenizer().tokenize(source))
    }

    @Test("inert checklist expands to no statements")
    func inertChecklistEmpty() throws {
        let block = try parse("""
        !!! checklist (( inert ))
        - [ ] the count is at least 1
        """)
        #expect(block.statements.isEmpty)
    }

    @Test("checklistProse headers differ for autonomy vs discretion")
    func checklistProseHeaders() {
        let auto = parser.checklistProse(["a"], autonomy: true)
        let disc = parser.checklistProse(["a"], autonomy: false)
        #expect(auto.hasPrefix("Ensure every acceptance criterion"))
        #expect(disc.hasPrefix("Verify the following acceptance criteria"))
        #expect(auto.contains("- a"))
        #expect(disc.contains("- a"))
    }

    @Test("shouldResolveAnaphora is false for try/or-if-that-fails idiom")
    func shouldResolveAnaphoraTryIdiom() {
        let sep = EnglishLexicon.default.grammar.tryIdiomFailureSeparator
        let blocked = SourceLine(indent: 0, text: "try x \(sep) y.", raw: "try x \(sep) y.", number: 1)
        let ok = SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 1)
        #expect(parser.shouldResolveAnaphora(blocked) == false)
        #expect(parser.shouldResolveAnaphora(ok) == true)
    }

    @Test("recordReferents tracks bind/rebind/note/iteration and caps at four")
    func recordReferentsTracksAndCaps() {
        var refs: [String] = []
        parser.recordReferents(
            from: .bind(BindStatementAST(name: "alpha", value: .literal(.integer(1)), sourceLine: 1)),
            into: &refs
        )
        parser.recordReferents(
            from: .rebind(RebindStatementAST(name: "beta", value: .literal(.integer(2)), sourceLine: 1)),
            into: &refs
        )
        parser.recordReferents(
            from: .note(NoteStatementAST(binding: "gamma", text: "n", sourceLine: 1)),
            into: &refs
        )
        parser.recordReferents(
            from: .iteration(IterationStatementAST(
                mode: .forEach(variable: "item", collection: .identifierRef("items")),
                body: ASTBlock(statements: []),
                sourceLine: 1
            )),
            into: &refs
        )
        parser.recordReferents(
            from: .bind(BindStatementAST(name: "delta", value: .literal(.integer(3)), sourceLine: 1)),
            into: &refs
        )
        #expect(refs.count == 4)
        #expect(refs.contains("delta"))

        var labelledRefs: [String] = []
        parser.recordReferents(
            from: .labelled(LabelledStatementAST(
                label: "Step",
                statement: .bind(BindStatementAST(name: "inner", value: .literal(.integer(1)), sourceLine: 1)),
                sourceLine: 1
            )),
            into: &labelledRefs
        )
        #expect(labelledRefs == ["inner"])

        var ignored: [String] = []
        parser.recordReferents(
            from: .emit(EmitStatementAST(eventID: "e", payload: [], sourceLine: 1)),
            into: &ignored
        )
        #expect(ignored.isEmpty)
    }

    @Test("appendStatement attaches recover to the preceding statement")
    func appendStatementAttachesRecover() {
        var stmts: [StatementAST] = [
            .bind(BindStatementAST(name: "x", value: .literal(.integer(1)), sourceLine: 1))
        ]
        let recover = RecoverStatementAST(
            pattern: .named("timeout"),
            handler: ASTBlock(statements: []),
            attached: parser.recoverPlaceholder(sourceLine: 2),
            sourceLine: 2
        )
        parser.appendStatement(.recover(recover), to: &stmts)
        #expect(stmts.count == 1)
        guard case .recover(let rec) = stmts[0],
              case .bind(let bind) = rec.attached else {
            Issue.record("expected recover wrapping prior bind"); return
        }
        #expect(bind.name == "x")
    }

    @Test("appendStatement without placeholder just appends")
    func appendStatementPlain() {
        var stmts: [StatementAST] = []
        parser.appendStatement(
            .bind(BindStatementAST(name: "x", value: .literal(.integer(1)), sourceLine: 1)),
            to: &stmts
        )
        #expect(stmts.count == 1)
    }
}

@Suite("StatementParser+Collector coverage")
struct StatementParserCollectorCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable(), trace: .silent())

    @Test("collectMultiLineCounted returns immediately for period-terminated headers")
    func collectStopsOnPeriod() {
        let lines = [
            SourceLine(indent: 0, text: "do something.", raw: "do something.", number: 1),
            SourceLine(indent: 2, text: "more text", raw: "  more text", number: 2),
        ]
        let result = parser.collectMultiLineCounted(lines, at: 0)
        #expect(result.consumed == 0)
        #expect(result.text == "do something")
    }

    @Test("collectMultiLineCounted folds indented continuations and skips blanks/comments")
    func collectFoldsContinuations() {
        let lines = [
            SourceLine(indent: 0, text: "notify the customer", raw: "notify the customer", number: 1),
            SourceLine(indent: 0, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "> note", raw: "  > note", number: 3),
            SourceLine(indent: 2, text: "about the delay", raw: "  about the delay", number: 4),
            SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 5),
        ]
        let result = parser.collectMultiLineCounted(lines, at: 0)
        #expect(result.consumed == 1)
        #expect(result.text == "notify the customer about the delay")
    }

    @Test("collectMultiLineCounted stops at structural recover/simultaneously boundaries")
    func collectStopsAtStructuralBoundary() {
        let lines = [
            SourceLine(indent: 0, text: "notify the customer", raw: "notify the customer", number: 1),
            SourceLine(indent: 2, text: "recover from timeout:", raw: "  recover from timeout:", number: 2),
        ]
        let result = parser.collectMultiLineCounted(lines, at: 0)
        #expect(result.consumed == 0)
        #expect(result.text == "notify the customer")
    }

    @Test("isStructuralBoundary recognizes recover and simultaneously headers")
    func structuralBoundaryVariants() {
        #expect(parser.isStructuralBoundary(
            SourceLine(indent: 0, text: "recover from timeout:", raw: "recover from timeout:", number: 1)))
        #expect(parser.isStructuralBoundary(
            SourceLine(indent: 0, text: "recover where the order failed:", raw: "recover where the order failed:", number: 1)))
        #expect(parser.isStructuralBoundary(
            SourceLine(indent: 0, text: "simultaneously:", raw: "simultaneously:", number: 1)))
        #expect(!parser.isStructuralBoundary(
            SourceLine(indent: 0, text: "notify the customer", raw: "notify the customer", number: 1)))
    }
}
