import Testing
@testable import MeridianCore

@Suite("ExpressionParser — literals, logic, malformed forms")
struct ExpressionParserCoverageTests {
    private let p = ExpressionParser()

    private func isMalformed(_ e: ExpressionAST) -> Bool {
        if case .malformed = e { return true }
        return false
    }

    @Test("a $-prefixed token parses as an env-var reference")
    func envVar() {
        if case .envVar(let name) = p.parse("$HOME") {
            #expect(name == "HOME")
        } else {
            Issue.record("expected env-var reference")
        }
    }

    @Test("a quoted string literal parses")
    func quotedString() {
        if case .literal(.string(let s)) = p.parse("\"hello world\"") {
            #expect(s == "hello world")
        } else {
            Issue.record("expected string literal")
        }
    }

    @Test("boolean and numeric literals")
    func scalars() {
        #expect({ if case .literal(.boolean(true)) = p.parse("true") { return true } else { return false } }())
        #expect({ if case .literal(.boolean(false)) = p.parse("false") { return true } else { return false } }())
        if case .literal(.integer(let n)) = p.parse("42") { #expect(n == 42) }
        else { Issue.record("expected integer") }
    }

    @Test("now expression")
    func now() {
        #expect({ if case .now = p.parse("now") { return true } else { return false } }())
    }

    @Test("a bare mix of and/or at one level is malformed")
    func mixedConnectives() {
        #expect(isMalformed(p.parse("a is 1 and b is 2 or c is 3")))
    }

    @Test("either … or … is one operand, not a top-level disjunction")
    func eitherGroup() {
        let e = p.parse("either a is 1 or b is 2")
        // It should NOT be malformed — the either-group protects the inner `or`.
        #expect(!isMalformed(e))
    }

    @Test("not negates a clause")
    func negation() {
        if case .logical(.not, let kids) = p.parse("not a is 1") {
            #expect(kids.count == 1)
        } else {
            Issue.record("expected a not-logical node")
        }
    }

    @Test("it is not the case that … negates")
    func clauseNegation() {
        #expect({ if case .logical(.not, _) = p.parse("it is not the case that a is 1") { return true } else { return false } }())
    }

    @Test("a comparison parses to a comparison node")
    func comparison() {
        #expect({ if case .comparison = p.parse("the total is more than 5") { return true } else { return false } }())
    }

    @Test("comparison markers match case-insensitively outside quotes")
    func uppercaseComparisonMarker() {
        let e = p.parse("the total IS MORE THAN 5")
        if case .comparison(let lhs, .greaterThan, let rhs) = e {
            #expect({ if case .identifierRef("total") = lhs { return true } else { return false } }())
            #expect({ if case .literal(.integer(5)) = rhs { return true } else { return false } }())
        } else {
            Issue.record("expected a greater-than comparison")
        }
    }

    @Test("a duration literal parses")
    func duration() {
        #expect({ if case .literal(.duration) = p.parse("1 hour") { return true } else { return false } }())
    }

    @Test("empty input is a malformed carrier, not a silent empty string literal")
    func emptyInputMalformed() {
        #expect(isMalformed(p.parse("")))
        #expect(isMalformed(p.parse("   ")))
    }

    @Test("a corrupt code-block sentinel is malformed, not a silent empty string literal")
    func corruptCodeBlockMalformed() {
        let sentinel = "\u{E000}codeblock:plain:!!!not-valid-base64!!!"
        #expect(isMalformed(p.parse(sentinel)))
    }

    @Test("malformed atom paths log under .expression when tracing is enabled")
    func malformedPathsTraced() {
        let cap = ParserTrace.capturing(categories: [.expression])
        let p = ExpressionParser()
        cap.trace.run {
            _ = p.parse("")
            _ = p.parse("\u{E000}codeblock:plain:!!!not-valid-base64!!!")
        }
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("malformed (empty expression)") })
        #expect(lines.contains { $0.contains("malformed (corrupt sentinel)") })
    }

    @Test("clause and atom dispatch paths log under .expression when tracing is enabled")
    func clauseAndAtomDispatchTraced() throws {
        let cap = ParserTrace.capturing(categories: [.expression])
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has a summary, which is text.
        """
        let sym = SymbolTable.build(from: try MerConfigParser().parse(cfg, file: "t.merconfig"))
        let p = ExpressionParser(symbols: sym)
        cap.trace.run {
            _ = p.parse("all pages have a summary")
            _ = p.parse("results is empty")
            _ = p.parse("the price corresponding to the sku \"SKU1\" in the price table")
            _ = p.parse("pages frobnicated by the user")
        }
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("→ quantifier") })
        #expect(lines.contains { $0.contains("→ emptiness/temporal-window") })
        #expect(lines.contains { $0.contains("→ table-lookup") })
        #expect(lines.contains { $0.contains("→ undeclared-passive-verb error") })
    }
}
