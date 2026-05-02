import Testing
@testable import MeridianCore

@Suite("English idiom desugaring")
struct EnglishIdiomTests {

    private func parse(_ source: String) throws -> ASTBlock {
        try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize(source))
    }

    @Test("ensure and make sure become assertions")
    func assurancePhrases() throws {
        let block = try parse("ensure ci is passed.")
        guard case .assertStmt(let stmt) = block.statements.first else {
            Issue.record("Expected assert")
            return
        }
        if case .comparison = stmt.condition {
            // expected
        } else {
            Issue.record("Expected parsed condition")
        }
    }

    @Test("after connective becomes conditional")
    func afterConnective() throws {
        let block = try parse("after ci is passed, complete.")
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("Expected conditional")
            return
        }
        if case .complete = cond.thenBlock.statements.first {} else {
            Issue.record("Expected complete then statement")
        }
    }

    @Test("except when becomes unless")
    func exceptWhen() throws {
        let block = try parse("complete except when blocked.")
        guard case .conditional(let cond) = block.statements.first,
              case .logical(.not, _) = cond.condition else {
            Issue.record("Expected negated conditional")
            return
        }
    }

    @Test("try-if-it-fails becomes recover")
    func tryIfItFails() throws {
        let block = try parse("try complete; if it fails complete with reason \"failed\".")
        guard case .recover(let rec) = block.statements.first else {
            Issue.record("Expected recover")
            return
        }
        if case .complete = rec.attached {} else { Issue.record("Expected attached complete") }
        #expect(rec.handler.statements.count == 1)
    }

    @Test("simple passive voice rewrites to active phrase")
    func passiveVoice() throws {
        let block = try parse("the comment should be resolved.")
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("Expected phrase invocation")
            return
        }
        #expect(phrase.words == "resolve the comment")
    }
}
