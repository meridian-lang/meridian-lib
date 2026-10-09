import Foundation
import Testing
@testable import MeridianCore

/// Coverage for `StatementParser+Idioms` — iteration take/last prefixes,
/// vague-hedge diagnostics, compound notes, chain paren depth, and idiom
/// nil-guards that end-to-end fixtures rarely hit in isolation.
@Suite("StatementParser+Idioms coverage")
struct StatementParserIdiomsCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable())

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(IndentTokenizer().tokenize(source))
    }

    // MARK: - Iteration refinement

    @Test("extractIterationRefinement covers first/last take and temporal window")
    func iterationTakeAndTemporal() throws {
        let first = try parser.extractIterationRefinement(
            "the first 3 pages sorted by title, ascending",
            sourceFile: "t.meridian", line: 1)
        #expect(first.refinement?.take == 3)
        #expect(first.noun == "pages")

        // Bare `first N` (article already stripped by the scan loop).
        let bareFirst = try parser.extractIterationRefinement(
            "first 5 items",
            sourceFile: "t.meridian", line: 1)
        #expect(bareFirst.refinement?.take == 5)

        // `the last N` arm runs after the article-strip pass — feed a leading
        // indefinite article so stripping leaves `the last …` intact.
        let last = try parser.extractIterationRefinement(
            "a the last 2 alerts",
            sourceFile: "t.meridian", line: 1)
        #expect(last.refinement?.takeFromEnd == 2)

        // Same trick for the definite+first arm (bare `first N` is covered above).
        let theFirst = try parser.extractIterationRefinement(
            "a the first 4 rows",
            sourceFile: "t.meridian", line: 1)
        #expect(theFirst.refinement?.take == 4)

        let temporal = try parser.extractIterationRefinement(
            "orders within the last 2 hours",
            sourceFile: "t.meridian", line: 1)
        #expect(temporal.refinement?.temporal != nil)
    }

    @Test("whose clause with a vague hedge raises conditionUnknownComparator")
    func vagueHedgeDiagnostic() throws {
        let hedge = EnglishLexicon.default.conditionVagueHedges.sorted().first ?? "roughly"
        #expect(throws: CompilerError.self) {
            _ = try parser.extractIterationRefinement(
                "pages whose status is \(hedge) ready",
                sourceFile: "t.meridian", line: 1)
        }
        do {
            _ = try parser.extractIterationRefinement(
                "pages whose status is \(hedge) ready",
                sourceFile: "t.meridian", line: 1)
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .conditionUnknownComparator })
        }
    }

    // MARK: - Idiom surfaces

    @Test("background / after / try / assert idiom happy paths")
    func idiomHappyPaths() throws {
        let bg = try parse("in the background, let x be 1.")
        guard case .simultaneously(let sim) = bg.statements.first else {
            Issue.record("expected background simultaneously"); return
        }
        #expect(sim.detached == true)

        let after = try parse("after ready, let x be 1.")
        guard case .conditional = after.statements.first else {
            Issue.record("expected after-idiom conditional"); return
        }

        let tryIdiom = try parse("try let x be 1; if it fails let y be 2.")
        guard case .recover = tryIdiom.statements.first else {
            Issue.record("expected try-idiom recover"); return
        }

        let assertIdiom = try parse("assert ready.")
        guard case .assertStmt = assertIdiom.statements.first else {
            Issue.record("expected assert idiom"); return
        }
    }

    @Test("idiom nil-guards for empty action/condition tails")
    func idiomNilGuards() throws {
        let line = SourceLine(indent: 0, text: "in the background,", raw: "in the background,", number: 1)
        #expect(try parser.parseEnglishIdiom(line, sourceFile: "t.meridian") == nil)

        let assertEmpty = SourceLine(indent: 0, text: "assert ", raw: "assert ", number: 1)
        #expect(try parser.parseEnglishIdiom(assertEmpty, sourceFile: "t.meridian") == nil)

        let afterEmpty = SourceLine(indent: 0, text: "after , let x be 1.", raw: "after , let x be 1.", number: 1)
        #expect(try parser.parseEnglishIdiom(afterEmpty, sourceFile: "t.meridian") == nil)

        let exceptEmpty = SourceLine(indent: 0, text: " except when blocked.", raw: " except when blocked.", number: 1)
        #expect(try parser.parseEnglishIdiom(exceptEmpty, sourceFile: "t.meridian") == nil)

        let tryEmpty = SourceLine(
            indent: 0,
            text: "try ; if it fails let y be 2.",
            raw: "try ; if it fails let y be 2.",
            number: 1
        )
        #expect(try parser.parseEnglishIdiom(tryEmpty, sourceFile: "t.meridian") == nil)

        let suffixEmpty = SourceLine(indent: 0, text: " unless ready.", raw: " unless ready.", number: 1)
        #expect(try parser.parseSuffixConditional(suffixEmpty, sourceFile: "t.meridian") == nil)
    }

    @Test("passive rewrite requires a subject and -ed verb")
    func passiveEdges() {
        #expect(parser.passiveVoiceRewrite("should be archived") == nil) // no subject
        #expect(parser.passiveVoiceRewrite("the file should be ready") == nil) // not -ed
        #expect(parser.passiveVoiceRewrite("the file should be archived") == "archive the file")
    }

    // MARK: - Chains / compound note / duration

    @Test("splitStatementChain respects parentheses and cleanup and-prefix")
    func chainParenAndCleanup() {
        let parts = parser.splitStatementChain(
            "let x be f(a, b) and let y be 2 then let z be 3")
        #expect(parts.count == 3)

        let cleaned = parser.cleanChainPart("and let x be 1")
        #expect(cleaned == "let x be 1" || cleaned.hasPrefix("let"))
    }

    @Test("compound note parses and rejects malformed shapes")
    func compoundNote() throws {
        let ok = try parse("proceed, and note \"hello\" in the status.")
        guard case .note(let note) = ok.statements.first else {
            Issue.record("expected compound note"); return
        }
        #expect(note.text == "hello")
        #expect(note.binding == "status")

        #expect(parser.parseCompoundNote("proceed", line: SourceLine(indent: 0, text: "proceed", raw: "proceed", number: 1)) == nil)
        #expect(parser.parseCompoundNote(
            "proceed, and note hello in the status",
            line: SourceLine(indent: 0, text: "x", raw: "x", number: 1)
        ) == nil)
        #expect(parser.parseCompoundNote(
            "proceed, and note \"hello\" elsewhere",
            line: SourceLine(indent: 0, text: "x", raw: "x", number: 1)
        ) == nil)
        #expect(parser.parseCompoundNote(
            "proceed, and note \"\" in the ",
            line: SourceLine(indent: 0, text: "x", raw: "x", number: 1)
        ) == nil)
    }

    @Test("durationSeconds and every/each refinement edges")
    func durationAndEveryEach() throws {
        #expect(parser.durationSeconds("2 hours") == 7200)
        #expect(parser.durationSeconds("not-a-duration") == nil)

        let every = try parse("review every open page whose title is set.")
        guard case .iteration = every.statements.first else {
            Issue.record("expected every/each iteration"); return
        }
    }
}
