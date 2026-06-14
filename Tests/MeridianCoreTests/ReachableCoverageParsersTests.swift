import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase 2: crafted source fixtures for the parser layer. Direct parse() calls
// (fast, no codegen) cover the rare expression-grammar arms; small compile/parse
// fixtures cover the statement and merconfig declaration forms the corpus
// doesn't exercise. Malformed-input cases drive the `return nil` / `.malformed`
// guards.

@Suite("Reachable coverage — parsers")
struct ReachableCoverageParsersTests {

    // A relational vocabulary with a verb + backing, so verb/relation parses
    // resolve. Mirrors examples/relations.merconfig in miniature.
    private static let relCfg = """
    === vocabulary ===
    A user is a kind of thing.
    A user has a name, which is a String.
    A page is a kind of thing.
    A page has an owner, which is a String.
    A page has a summary, which is a String.
    A page has a status, which is one of (draft, published, archived).
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    """

    private func relSymbols() throws -> SymbolTable {
        let cfg = try MerConfigParser(trace: .silent()).parse(Self.relCfg, file: "rel.merconfig")
        return SymbolTable.build(from: cfg)
    }

    private func parse(_ s: String, _ sym: SymbolTable? = nil) -> ExpressionAST {
        ExpressionParser(symbols: sym, trace: .silent()).parse(s)
    }

    private func examplesURL() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("examples")
    }

    // The full Wave-3 relations showcase vocabulary: one-to-one (Assignment,
    // scalar nav), one-to-many (Ownership), tool-backed (Mentioning), Money,
    // Date sort key, enums, and checkable definitions.
    private func wave3Symbols() throws -> SymbolTable {
        let src = try String(
            contentsOf: examplesURL().appendingPathComponent("relations.merconfig"),
            encoding: .utf8
        )
        let cfg = try MerConfigParser(trace: .silent()).parse(src, file: "relations.merconfig")
        return SymbolTable.build(from: cfg)
    }

    private func notMalformed(_ e: ExpressionAST, _ label: String) {
        if case .malformed(let m) = e { Issue.record("\(label): malformed — \(m)") }
    }

    // MARK: ExpressionParser — quantifier determiners

    @Test("matchDeterminer: every/some/none of/none determiners")
    func quantifierDeterminers() throws {
        let minimal = """
        === vocabulary ===
        A page is a kind of thing.
        A page has a summary, which is text.
        A page has a status, which is text.
        """
        let cfg = try MerConfigParser(trace: .silent()).parse(minimal, file: "q.merconfig")
        let sym = SymbolTable.build(from: cfg)
        func kind(_ s: String) -> QuantifierKindAST? {
            if case .quantified(let q) = parse(s, sym) { return q.kind }
            return nil
        }
        #expect(kind("every page has a summary") == .all)
        #expect(kind("some pages have a summary") == .any)
        // `.none` must be fully qualified here: on an Optional<QuantifierKindAST>
        // a bare `.none` binds to Optional.none (nil), not the quantifier case.
        #expect(kind("no pages whose status is \"draft\"") == QuantifierKindAST.none)
        #expect(kind("none of pages whose status is \"draft\"") == QuantifierKindAST.none)
        #expect(kind("none pages whose status is \"draft\"") == QuantifierKindAST.none)
    }

    // MARK: ExpressionParser — atom literal forms

    @Test("parseAtom: single-quoted string, env-var, and decimal literals")
    func atomLiterals() {
        guard case .comparison(_, _, let rhsStr) = parse("name is 'bob'"),
              case .literal(.string("bob")) = rhsStr else {
            Issue.record("single-quote string"); return
        }
        // `$`-prefixed tokens resolve to env-var references (the money atom in
        // parseAtom is shadowed by this and is dead — see ReachableCoverage notes).
        guard case .comparison(_, _, let rhsEnv) = parse("token is $API_KEY"),
              case .envVar("API_KEY") = rhsEnv else {
            Issue.record("env var"); return
        }
        guard case .comparison(_, _, let rhsDouble) = parse("ratio is 1.5"),
              case .literal(.double(1.5)) = rhsDouble else {
            Issue.record("double literal"); return
        }
    }

    // MARK: ExpressionParser — negated active-verb predicate

    @Test("negated do-support verb predicate wraps in logical-not")
    func negatedVerbPredicate() throws {
        let sym = try relSymbols()
        guard case .logical(.not, let parts) = parse("the user does not own the page", sym),
              parts.count == 1 else {
            Issue.record("expected negated verb predicate"); return
        }
    }

    // MARK: MerConfigParser — relation backing, verbs, constants, instances

    @Test("MerConfigParser parses relations, verbs, property backing, and the inverse form")
    func merConfigRelational() throws {
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === vocabulary ===
        An order is a kind of thing.
        An order has a total, which is Money.
        A customer is a kind of thing.

        placing relates one customer to many orders.
        The inverse of placing is being placed by.
        Ownership relates one customer to various orders.
        Ownership is read from the order's total.
        The verb to own (it owns, it is owned) means the ownership relation.

        === constants ===
        The default currency is "USD".
        The high value threshold is $5000.
        The maximum retry count is 3.
        """, file: "c.merconfig")
        #expect(cfg.constants.contains { $0.name == "default currency" })
        #expect(cfg.constants.contains { $0.name == "high value threshold" })
        // Verb + relation registered.
        let symbols = SymbolTable.build(from: cfg)
        #expect(symbols.verbs["own"] != nil)
        #expect(symbols.relation(named: "ownership") != nil)
    }

    @Test("MerConfigParser parseLiteral covers boolean/double/money/duration")
    func merConfigLiterals() throws {
        // Constants with each literal kind exercise parseLiteral's arms.
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === vocabulary ===
        A thing is a kind of thing.

        === constants ===
        The flag is true.
        The other flag is false.
        The ratio is 1.5.
        The fee is $9.
        The window is 30 minutes.
        """, file: "c.merconfig")
        #expect(cfg.constants.count == 5)
    }

    // MARK: StatementParser — rare statement forms via the full parser

    private func parseWorkflow(_ src: String) throws -> MeridianFile {
        try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse(src, file: "t.meridian")
    }

    @Test("single-line conditional with inline otherwise")
    func singleLineConditionalOtherwise() throws {
        let ast = try parseWorkflow("""
        To handle a thing:
          if the thing is ready, complete with reason "go", otherwise complete with reason "wait".
        """)
        guard case .conditional(let c) = ast.workflows[0].body.statements.first else {
            Issue.record("expected conditional"); return
        }
        #expect(c.elseBlock != nil)
    }

    @Test("in strict mode / in lenient mode modal lines")
    func modalLines() throws {
        let strict = try parseWorkflow("""
        To run:
          in strict mode.
          complete with reason "x".
        """)
        #expect(strict.workflows[0].body.statements.contains { if case .modal(.strict) = $0 { return true }; return false })
        let lenient = try parseWorkflow("""
        To run:
          in lenient mode.
          complete with reason "x".
        """)
        #expect(lenient.workflows[0].body.statements.contains { if case .modal(.lenient) = $0 { return true }; return false })
    }

    @Test("rebind statement parses as a rebind")
    func rebindStatement() throws {
        let ast = try parseWorkflow("""
        To run:
          bind count = 1.
          rebind count = 2.
        """)
        #expect(ast.workflows[0].body.statements.contains { if case .rebind = $0 { return true }; return false })
    }

    // MARK: ExpressionParser — Wave-3 relational forms (positive arms)

    @Test("Wave-3 relational expressions parse to structured forms")
    func wave3RelationalExpressions() throws {
        let sym = try wave3Symbols()
        // Scalar navigation (one-to-one Assignment), passive + relative
        // descriptions, aggregate, superlative-by-prop, sort+take, and `whose`.
        notMalformed(parse("the task assigned to the user", sym), "scalar-nav")
        notMalformed(parse("the pages owned by the user", sym), "passive-desc")
        notMalformed(parse("the pages that mention the entity", sym), "relative-desc")
        notMalformed(parse("the number of stale pages", sym), "aggregate-count")
        notMalformed(parse("the largest deal by amount", sym), "superlative-by")
        notMalformed(parse("the most recent page", sym), "superlative-recent")
        notMalformed(parse("the first 3 pages sorted by view count descending", sym), "sort-take-desc")
        notMalformed(parse("the first 3 pages sorted by view count", sym), "sort-take-asc")
        notMalformed(parse("pages whose status is \"draft\"", sym), "whose")
        // Active-verb predicate + do-support contraction negation.
        notMalformed(parse("the user owns the page", sym), "active-verb")
        guard case .logical(.not, _) = parse("the user doesn't own the page", sym) else {
            Issue.record("contraction negation"); return
        }
    }

    // MARK: StatementParser — multi-line collectors, chains, recover, parallel

    @Test("blank/comment lines inside multi-line blocks, do-chains, recover, simultaneously")
    func statementMultiLineForms() throws {
        // Blank + comment lines inside the body and inside multi-line headers
        // flip the `if l.isEmpty || l.isComment { continue }` continuation arms
        // across the collectors; the do-chain, recover, and simultaneously
        // blocks each drive their own collector.
        let ast = try parseWorkflow("""
        To process a thing:
          # a comment line inside the body

          do bind a = 1, bind b = 2, and bind c = 3.
          if the thing is ready,

            complete with reason "ok".
          recover from "x.failed":

            complete with reason "recovered".
          simultaneously:
            complete with reason "a".

            complete with reason "b".
        """)
        let stmts = ast.workflows[0].body.statements
        #expect(!stmts.isEmpty)
        #expect(stmts.contains { if case .recover = $0 { return true }; return false })
        #expect(stmts.contains { if case .simultaneously = $0 { return true }; return false })
    }

    @Test("suffix only-when / unless modality desugars to a conditional")
    func suffixModality() throws {
        let ast = try parseWorkflow("""
        To run:
          complete with reason "x" only when the thing is ready.
          complete with reason "y" unless the thing is blocked.
        """)
        #expect(ast.workflows[0].body.statements.allSatisfy {
            if case .conditional = $0 { return true }; return false
        })
    }

    @Test("logical or/and fold multiple operands; either-or is one disjunction")
    func logicalMultiOperand() {
        guard case .logical(.or, let ors) = parse("a is 1 or b is 2 or c is 3"), ors.count == 3 else {
            Issue.record("3-way or"); return
        }
        guard case .logical(.and, let ands) = parse("a is 1 and b is 2 and c is 3"), ands.count == 3 else {
            Issue.record("3-way and"); return
        }
        guard case .logical(.or, _) = parse("either a is 1 or b is 2") else {
            Issue.record("either-or"); return
        }
    }

    // MARK: ExpressionParser — relational guards (negative arms)

    @Test("relational productions return a fallback when symbols are absent")
    func relationalWithoutSymbols() {
        // No symbol table → every `guard let sym = symbols else { return nil }`
        // arm fires and the atom falls back to a plain reference (never throws).
        for s in [
            "the task assigned to the user",
            "the pages owned by the user",
            "the pages that mention the entity",
            "the number of stale pages",
            "the largest deal by amount",
            "the user owns the page",
        ] {
            notMalformed(parse(s), "no-symbols: \(s)")
        }
    }

    @Test("malformed relational inputs fall back without throwing")
    func relationalMalformed() throws {
        let sym = try wave3Symbols()
        // Unknown kind, empty operand, and an unknown verb each fail an inner
        // guard inside the description/verb productions → graceful fallback.
        notMalformed(parse("the widgets owned by the user", sym), "unknown-kind")
        notMalformed(parse("the pages owned by", sym), "empty-operand")
        // A plural-declared-kind + unknown participle is the one shape that
        // surfaces a `.malformed` "did you mean a relation verb?" diagnostic.
        guard case .malformed = parse("the pages frobnicated by the user", sym) else {
            Issue.record("expected undeclared-verb malformed"); return
        }
    }
}
