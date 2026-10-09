import Testing
@testable import MeridianCore

/// Phase B1 (Diagnostics Tracing Overhaul): assert every parse-stage decision
/// point that gained a `trace.log` call actually emits one, for both the
/// accept and reject branches. These are white-box tests of the `.statement`
/// `.tokenize` category streams, distinct from the end-to-end pipeline
/// coverage in `TraceEnabledCompileTests`.
@Suite("Parse-stage trace depth (B1)")
struct ParseStageTraceTests {

    // MARK: DefinitionParser

    @Test("DefinitionParser traces both rejection reasons and a successful parse")
    func definitionParserTraced() {
        let cap = ParserTrace.capturing(categories: [.statement])
        let dp = DefinitionParser(lexicon: .default)

        cap.trace.run {
            _ = dp.parse("Definition: a page is stale", line: 1)
            _ = dp.parse("Definition: a page stale if it has no summary", line: 2)
            _ = dp.parse("Definition: a page is stale if it has no summary", line: 3)
        }

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("no \"if\" condition introducer") || $0.contains("no \" if \" condition introducer") })
        #expect(lines.contains { $0.contains("has no \"is\" marker") })
        #expect(lines.contains { $0.contains("definition parsed") && $0.contains("adjective=\"stale\"") })
    }

    // MARK: ConditionClassifier

    @Test("ConditionClassifier traces all three classification outcomes")
    func conditionClassifierTraced() {
        let cap = ParserTrace.capturing(categories: [.statement])
        let cc = ConditionClassifier(symbols: nil, lexicon: .default)

        cap.trace.run {
            _ = cc.classify("amount is more than 5")
            _ = cc.classify("the report is notable")
            _ = cc.classify("send the report")
        }

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("→ checkable") })
        #expect(lines.contains { $0.contains("→ fuzzy") })
        #expect(lines.contains { $0.contains("→ dispatchPhrase") })
    }

    // MARK: SentenceBreaker (tokenize category)

    @Test("SentenceBreaker only traces when it actually trims a period")
    func sentenceBreakerSelectiveTrace() {
        let cap = ParserTrace.capturing(categories: [.tokenize])
        cap.trace.run {
            _ = SentenceBreaker().statementText(from: "bind x = 1.")
            _ = SentenceBreaker().statementText(from: "bind x = 1")
        }
        #expect(cap.lines().count == 1)
    }

    // MARK: StatementParser — every branch dispatch label (B1)

    /// One block exercising every previously-untraced `StatementParser`
    /// dispatch arm named in the plan, asserting each `L<n> -> <label>`
    /// line fires. Complements the broad end-to-end coverage in
    /// `TraceEnabledCompileTests` (which only hits whatever a real fixture
    /// happens to use) with a direct, exhaustive branch check.
    @Test("every StatementParser dispatch arm logs its L<n> -> <label> line")
    func statementParserDispatchLabelsTraced() throws {
        let cap = ParserTrace.capturing(categories: [.statement])
        let source = """
        in strict mode.
        in lenient mode.
        complete.
        complete with reason "done".
        commit.
        commit with label "checkpoint".
        wait 1 hour.
        ask the user to choose between "yes", "no".
        emit order.shipped.
        if the order is ready, complete, otherwise complete with reason "blocked".
        Step One: complete with reason "labelled".
        do not proceed unless the order is valid.
        let x be 5.
        simultaneously:
          emit branch.started.
        review every comment.
        for each item in the items,
          let y be 1.
        unless you decide that this is safe,
          complete with reason "unsafe".
        complete with reason "trailing".
        otherwise complete with reason "recovered".
        """
        let block = try cap.trace.run {
            try StatementParser(symbols: SymbolTable())
                .parseBlock(IndentTokenizer().tokenize(source))
        }
        #expect(!block.statements.isEmpty)

        let lines = cap.lines()
        let expectedLabels = [
            "modal(strict)", "modal(lenient)", "complete", "complete(reason:)",
            "commit", "commit(label:)", "wait", "choiceGate", "emit",
            "inlineConditional", "labelled", "suffixConditional", "letBind",
            "simultaneously", "iteration (every/each shorthand)",
            "iteration (for each/for every)", "unlessDecisionConditional",
            "otherwise (bare recover handler)",
        ]
        for label in expectedLabels {
            #expect(lines.contains { $0.contains("-> \(label)") },
                    Comment(rawValue: "missing trace for dispatch arm \"\(label)\""))
        }
    }
}
