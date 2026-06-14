import Testing
@testable import MeridianCore

@Suite("StatementParser — coverage of less-common idioms")
struct StatementParserCoverageTests {
    private func parse(_ source: String) throws -> ASTBlock {
        try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize(source))
    }

    @Test("while <cond>, body lowers to a while-condition iteration")
    func whileLoop() throws {
        let block = try parse("""
        while the counter is less than 10,
            let x be 5.
        """)
        guard case .iteration(let it) = block.statements.first else {
            Issue.record("expected iteration"); return
        }
        guard case .whileCondition = it.mode else {
            Issue.record("expected whileCondition mode"); return
        }
    }

    @Test("commit with label \"X\" carries the label")
    func commitWithLabel() throws {
        let block = try parse("commit with label \"checkpoint\".")
        guard case .commit(let c) = block.statements.first else {
            Issue.record("expected commit"); return
        }
        #expect(c.label == "checkpoint")
    }

    @Test("a bare commit has no label")
    func bareCommit() throws {
        let block = try parse("commit.")
        guard case .commit(let c) = block.statements.first else {
            Issue.record("expected commit"); return
        }
        #expect(c.label == nil)
    }

    @Test("with discretion: block becomes a discretion prose step")
    func discretionBlock() throws {
        let block = try parse("""
        with discretion:
            figure out the best approach.
        """)
        guard case .proseStep(let p) = block.statements.first else {
            Issue.record("expected proseStep"); return
        }
        #expect(p.dispatch == .discretion)
    }

    @Test("with autonomy: block becomes an autonomy prose step")
    func autonomyBlock() throws {
        let block = try parse("""
        with autonomy:
            keep refining until it converges.
        """)
        guard case .proseStep(let p) = block.statements.first else {
            Issue.record("expected proseStep"); return
        }
        #expect(p.dispatch == .autonomy)
    }

    @Test("do A and B then C splits into three statements")
    func chainSplit() throws {
        let block = try parse("do let a be 1 and let b be 2 then let c be 3.")
        #expect(block.statements.count == 3)
        for s in block.statements {
            guard case .bind = s else { Issue.record("expected a bind in the chain"); return }
        }
    }

    @Test("a leading recover (no predecessor) uses the placeholder attachment")
    func leadingRecover() throws {
        let block = try parse("""
        recover from "some.error":
            let y be 2.
        """)
        guard case .recover(let r) = block.statements.first else {
            Issue.record("expected recover"); return
        }
        guard case .named(let name) = r.pattern else {
            Issue.record("expected a named error pattern"); return
        }
        #expect(name == "some.error")
    }

    @Test("recover attaches to the immediately preceding statement")
    func attachedRecover() throws {
        let block = try parse("""
        let x be 1.
        recover from "boom":
            let y be 2.
        """)
        guard case .recover(let r) = block.statements.last else {
            Issue.record("expected recover as the last top-level statement"); return
        }
        guard case .bind = r.attached else {
            Issue.record("expected the preceding bind to be attached"); return
        }
    }
}
