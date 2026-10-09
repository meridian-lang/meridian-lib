import Testing
@testable import MeridianCore

@Suite("StatementParser — coverage of less-common idioms")
struct StatementParserCoverageTests {
    private func parse(_ source: String) throws -> ASTBlock {
        try StatementParser(symbols: SymbolTable())
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

    @Test("embedded every/each markers parse as action-over-collection loops")
    func embeddedEveryEachMarkers() throws {
        let every = try parse("review every comment.")
        guard case .iteration(let everyLoop) = every.statements.first,
              case .forEach(let everyVariable, .identifierRef(let everyCollection)) = everyLoop.mode else {
            Issue.record("expected embedded every loop"); return
        }
        #expect(everyVariable == "comment")
        #expect(everyCollection == "comments")

        let each = try parse("inspect each pull request.")
        guard case .iteration(let eachLoop) = each.statements.first,
              case .forEach(let eachVariable, .identifierRef(let eachCollection)) = eachLoop.mode else {
            Issue.record("expected embedded each loop"); return
        }
        #expect(eachVariable == "pullRequest")
        #expect(eachCollection == "pullRequests")
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

    @Test("labelled Markdown command line becomes a shell invocation with annotation")
    func embeddedBacktickCommand() throws {
        let block = try parse("**Verify** - `gbrain doctor --json`.")
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(decodeShellCommand(phrase.words) == "gbrain doctor --json")
        #expect(phrase.annotation == "Verify")
    }

    @Test("non-command code span remains a normal phrase invocation")
    func nonCommandBacktickSpan() throws {
        let block = try parse("Use `Page` as the type name.")
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(decodeShellCommand(phrase.words) == nil)
    }

    @Test("primitive statements with backticks are not reinterpreted as shell commands")
    func primitiveBacktickGuard() throws {
        let block = try parse("emit `order.escalated` with order_id = the order's id.")
        guard case .emit(let emit) = block.statements.first else {
            Issue.record("expected emit"); return
        }
        #expect(emit.eventID == "`order.escalated`")
    }

    @Test("bind statements with backticks are not reinterpreted as shell commands")
    func bindBacktickGuard() throws {
        let block = try parse("bind note = `not shell`.")
        guard case .bind = block.statements.first else {
            Issue.record("expected bind"); return
        }
    }

    @Test("choice gate accepts indented numbered options")
    func choiceGateNumberedOptions() throws {
        let block = try parse("""
        ask the user to choose between:
            1. Supabase
            2. BYO Postgres
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(let prompt, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(prompt == "ask the user to choose between:")
        #expect(options == ["1", "2"])
    }

    @Test("choice gate still accepts inline quoted options")
    func choiceGateInlineQuotedOptions() throws {
        let block = try parse("ask the user to choose between \"yes\", \"no\".")
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options == ["yes", "no"])
    }

    @Test("choice gate option collection handles blanks comments quotes and bullet labels")
    func choiceGateOptionCollectionBranches() throws {
        let block = try parse("""
        ask the user to choose between:

            > comment
            - "Remote Postgres"
            - Local SQLite
        complete.
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options == ["Remote Postgres", "Local SQLite"])
    }

    @Test("choice branch labels become conditionals over the choice binding")
    func choiceBranchLabels() throws {
        let block = try parse("""
        if the user picks 1:
            complete with reason "one".
        if no:
            complete with reason "declined".
        """)
        #expect(block.statements.count == 2)
        for statement in block.statements {
            guard case .conditional(let branch) = statement else {
                Issue.record("expected conditional"); return
            }
            guard case .comparison(.identifierRef(let name), .equal, .literal(.string(_))) = branch.condition else {
                Issue.record("expected choice equality condition"); return
            }
            #expect(name == "choice")
            #expect(branch.thenBlock.statements.count == 1)
        }
    }

    @Test("yes/no agreement labels normalize to yes and no")
    func choiceYesNoBranchLabels() throws {
        let block = try parse("""
        if the user agrees:
            complete with reason "yes".
        if the user declines:
            complete with reason "no".
        """)
        let strings = block.statements.compactMap { statement -> String? in
            guard case .conditional(let branch) = statement,
                  case .comparison(_, .equal, .literal(.string(let value))) = branch.condition else {
                return nil
            }
            return value
        }
        #expect(strings == ["yes", "no"])
    }

    @Test("user selects and chooses labels preserve selected value")
    func choiceSelectsBranchLabels() throws {
        let block = try parse("""
        if user selects remote:
            complete with reason "remote".
        if the user chooses local:
            complete with reason "local".
        """)
        let values = block.statements.compactMap { statement -> String? in
            guard case .conditional(let branch) = statement,
                  case .comparison(_, .equal, .literal(.string(let value))) = branch.condition else {
                return nil
            }
            return value
        }
        #expect(values == ["remote", "local"])
    }

    @Test("data table cells cover missing quoted empty and string fallback cases")
    func dataTableCellBranches() throws {
        let block = try parse("""
        !!! table (( data table ))
        | name | note | blank |
        | --- | --- | --- |
        | web | "quoted" |
        | db | raw-value | |
        """)
        guard case .bind(let bind) = block.statements.first,
              case .recordList(let fields, let rows) = bind.value else {
            Issue.record("expected data table binding"); return
        }
        #expect(bind.name == "table")
        #expect(fields == ["name", "note", "blank"])
        #expect(rows.count == 2)
    }

    @Test("AI autonomy table marker becomes an autonomy prose step")
    func aiAutonomyTableMarker() throws {
        let block = try parse("""
        !!! table (( ai-autonomy ))
        | intent | action |
        | --- | --- |
        | fuzzy input | resolve it |
        """)
        guard case .proseStep(let step) = block.statements.first else {
            Issue.record("expected prose step"); return
        }
        #expect(step.dispatch == .autonomy)
    }

    @Test("AI checklist marker keeps multiline task items together")
    func aiChecklistMultilineItems() throws {
        let block = try parse("""
        !!! checklist (( ai-autonomy ))
        - [ ] First requirement spans
          a continuation line.
        - [ ] Second requirement.
        """)
        guard case .proseStep(let step) = block.statements.first else {
            Issue.record("expected prose step"); return
        }
        #expect(step.dispatch == .autonomy)
        #expect(step.text.contains("First requirement spans a continuation line"))
    }

    @Test("generated guidance judgment collects until next heading, into the guidance field")
    func generatedGuidanceCollectsUntilHeading() throws {
        let block = try parse("""
        use judgment to follow the Install guidance:
          ```bash
          gbrain doctor --json
          ```

          item: validate inputs.
        ## Next
        """)
        guard case .proseStep(let step) = block.statements.first else {
            Issue.record("expected prose step"); return
        }
        // The collected narrative is carried separately as `guidance`, not
        // folded into the dispatch goal `text` (ProseStepAST.guidance).
        #expect(step.guidance?.contains("item: validate inputs") == true)
        #expect(!step.text.contains("item: validate inputs"))
        #expect(step.text == "follow the Install guidance")
    }

    @Test("shell block flushes trailing continuation")
    func shellBlockTrailingContinuation() throws {
        let block = try parse("""
        ```bash
        gbrain doctor \\
        ```
        """)
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("expected shell phrase"); return
        }
        #expect(decodeShellCommand(phrase.words) == "gbrain doctor")
    }

    @Test("guarded fence: if <cond>, run: + shell fence wraps in a branch")
    func guardedFenceWrapsShellFenceInBranch() throws {
        let block = try parse("""
        if the health check fails, run:
        ```bash
        gbrain doctor --repair
        ```
        """)
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        guard case .phraseInvocation(let phrase) = cond.thenBlock.statements.first else {
            Issue.record("expected shell phrase inside then-block"); return
        }
        #expect(decodeShellCommand(phrase.words) == "gbrain doctor --repair")
        #expect(cond.elseBlock == nil)
    }

    @Test("guarded fence tolerates a blank line before the fence")
    func guardedFenceSkipsBlankBeforeFence() throws {
        let block = try parse("""
        if the health check fails, run:

        ```bash
        gbrain doctor --repair
        ```
        """)
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        #expect(cond.thenBlock.statements.count == 1)
    }

    @Test("if <cond>, run: without a following fence falls back to inline conditional")
    func ifRunWithoutFenceFallsBackToInlineConditional() throws {
        let block = try parse("if the build fails, run the report.")
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        guard case .phraseInvocation = cond.thenBlock.statements.first else {
            Issue.record("expected inline phrase invocation"); return
        }
    }

    @Test("fallback chain: try the following in order until one succeeds, nests recover N deep")
    func fallbackChainNestsRecover() throws {
        let block = try parse("""
        try the following in order until one succeeds:
        1. Run `gbrain doctor`.
        2. Run `gbrain doctor --repair`.
        3. Run `gbrain reset`.
        """)
        guard case .recover(let outer) = block.statements.first else {
            Issue.record("expected top-level recover"); return
        }
        guard case .phraseInvocation(let first) = outer.attached else {
            Issue.record("expected first step as attached statement"); return
        }
        #expect(decodeShellCommand(first.words) == "gbrain doctor")

        guard case .recover(let middle) = outer.handler.statements.first else {
            Issue.record("expected nested recover as the handler"); return
        }
        guard case .phraseInvocation(let second) = middle.attached else {
            Issue.record("expected second step as attached statement"); return
        }
        #expect(decodeShellCommand(second.words) == "gbrain doctor --repair")

        guard case .phraseInvocation(let third) = middle.handler.statements.first else {
            Issue.record("expected third (final) step bare, with no further recover"); return
        }
        #expect(decodeShellCommand(third.words) == "gbrain reset")
    }

    @Test("fallback chain requires at least two steps")
    func fallbackChainRequiresMultipleSteps() throws {
        let block = try parse("""
        try the following in order until one succeeds:
        1. Run `gbrain doctor`.
        """)
        guard case .recover = block.statements.first else { return }
        Issue.record("single-step list should not be chained into a recover")
    }

    @Test("malformed while/until headers with empty conditions are hard errors")
    func emptyWhileUntilHeadersError() {
        #expect(throws: CompilerError.self) {
            _ = try parse("while ,")
        }
        #expect(throws: CompilerError.self) {
            _ = try parse("until ,")
        }
    }

    @Test("invariant checklist marker emits one assert per checkable item")
    func invariantChecklistMarker() throws {
        let block = try parse("""
        !!! checklist (( invariant ))
        - [ ] the page count is at least 1
        - [ ] the link count is less than 100
        """)
        #expect(block.statements.count == 2)
        for stmt in block.statements {
            guard case .assertStmt = stmt else {
                Issue.record("expected assert per checklist item"); return
            }
        }
    }

    @Test("ai-discretion checklist marker collapses to a discretion prose step")
    func discretionChecklistMarker() throws {
        let block = try parse("""
        !!! checklist (( ai-discretion ))
        - [ ] file everything properly
        """)
        guard case .proseStep(let p) = block.statements.first else {
            Issue.record("expected prose step"); return
        }
        #expect(p.dispatch == .discretion)
    }

    @Test("rulebook desugar re-enters parsing on the rewritten line")
    func rulebookDesugarReentry() throws {
        let rulebook = Rulebook(desugars: [
            DesugarRule(
                name: "annotated-command",
                match: [.literal("Run `"), .hole("command"), .literal("` to "), .hole("purpose")],
                rewrite: "`{command}` -- {purpose}"
            )
        ])
        let engine = RewriteEngine(rulebook: rulebook)
        let parser = StatementParser(symbols: SymbolTable(), rewriteEngine: engine)
        let block = try parser.parseBlock(
            IndentTokenizer().tokenize("Run `echo hi` to say hello."),
            sourceFile: "t.meridian"
        )
        guard case .phraseInvocation = block.statements.first else {
            Issue.record("expected rewritten shell phrase invocation"); return
        }
    }

    @Test("invariant checklist rejects fuzzy non-checkable items")
    func invariantChecklistRejectsFuzzyItem() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! checklist (( invariant ))
            - [ ] file everything properly
            """)
        }
    }

    @Test("typed data-table cells reject values that do not match the column type")
    func typedDataTableCellValidation() {
        let cases = [
            ("| count (Number) |\n| --- |\n| not-a-number |", "Number"),
            ("| flag (Boolean) |\n| --- |\n| maybe |", "Boolean"),
            ("| price (Money) |\n| --- |\n| twelve |", "Money"),
            ("| ttl (Duration) |\n| --- |\n| soon |", "Duration"),
        ]
        for (tableBody, _) in cases {
            #expect(throws: CompilerError.self) {
                _ = try parse("""
                !!! table (( data table ))
                \(tableBody)
                """)
            }
        }
    }

    @Test("decision-table rows that do not parse are hard errors")
    func decisionTableUnparseableRow() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            | status | action |
            | --- | --- |
            | ready | The setup skill provides:
            """)
        }
    }

    @Test("malformed recover headers without a pattern are hard errors")
    func malformedRecoverHeader() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            recover badly:
              complete.
            """)
        }
    }

    @Test("topic labels that wrap inert sentinels are hard errors")
    func topicLabelWrapsInertContent() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            Setup:
            !!! table (( inert ))
            | a | b |
            | --- | --- |
            | 1 | 2 |
            """)
        }
    }

    @Test("choice gates accept parenthesized numbered option labels")
    func choiceGateParenthesizedNumbers() throws {
        let block = try parse("""
        ask the user to choose between:
            1) Remote Postgres
            2) Local SQLite
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options == ["1", "2"])
    }

    @Test("shell blocks with pending continuations survive a blank line")
    func shellBlockBlankLineWithPending() throws {
        let block = try parse("""
        ```bash
        echo hello \\

        ```
        """)
        guard case .phraseInvocation(let phrase) = block.statements.first,
              let cmd = decodeShellCommand(phrase.words) else {
            Issue.record("expected shell phrase"); return
        }
        #expect(cmd.contains("hello"))
    }

    @Test("do-and chains strip leading and/then connectives from later chunks")
    func doChainStripsConnectives() throws {
        let andChain = try parse("do complete and let x be 1.")
        #expect(andChain.statements.count == 2)
        guard case .complete = andChain.statements[0] else {
            Issue.record("expected complete first in and-chain"); return
        }
        guard case .bind = andChain.statements[1] else {
            Issue.record("expected bind second in and-chain"); return
        }

        let thenChain = try parse("do complete then let y be 2.")
        #expect(thenChain.statements.count == 2)
        guard case .bind = thenChain.statements[1] else {
            Issue.record("expected bind second in then-chain"); return
        }
    }

    @Test("do-and chains reject unparseable middle chunks")
    func doChainUnparseableMiddleChunk() {
        #expect(throws: CompilerError.self) {
            _ = try parse("do complete and bind total.")
        }
    }

    @Test("emit statements fold indented payload continuation lines")
    func emitIndentedPayloadContinuation() throws {
        let block = try parse("""
        emit order.placed with
            note = "hello",
            count = 1.
        """)
        guard case .emit(let emit) = block.statements.first else {
            Issue.record("expected emit"); return
        }
        #expect(emit.eventID.contains("order.placed") || emit.eventID == "order.placed")
        #expect(emit.payload.count >= 2)
    }

    @Test("bind decide-whether and decide-using forms parse to invoke expressions")
    func bindDecideForms() throws {
        let whether = try parse("bind verdict = decide whether proceed with caution.")
        guard case .bind(let b1) = whether.statements.first,
              case .decideWhether(let q) = b1.value else {
            Issue.record("expected decideWhether bind"); return
        }
        #expect(q.contains("proceed"))

        let using = try parse("""
        bind verdict = decide using:
        ```text
        Should we continue?
        ```
        """)
        guard case .bind(let b2) = using.statements.first,
              case .invoke(let tool, _) = b2.value else {
            Issue.record("expected decide using invoke"); return
        }
        #expect(tool == "llm.decide")
    }

    @Test("bind decide-using without a following fence defaults to an empty question")
    func bindDecideUsingEmptyFallback() throws {
        let block = try parse("bind verdict = decide using:")
        guard case .bind(let b) = block.statements.first,
              case .invoke(let tool, let args) = b.value else {
            Issue.record("expected invoke bind"); return
        }
        #expect(tool == "llm.decide")
        guard case .literal(.string(let q)) = args.first?.1 else {
            Issue.record("expected empty question literal"); return
        }
        #expect(q.isEmpty)
    }

    @Test("typed data tables accept valid cells and unknown column types")
    func typedDataTableValidAndUnknownTypes() throws {
        let block = try parse("""
        !!! table (( data table: tiers ))
        | name (String) | widget (Widget) |
        | --- | --- |
        | gold | anything goes |
        """)
        guard case .bind(let bind) = block.statements.first,
              case .recordList(_, let rows) = bind.value else {
            Issue.record("expected data table binding"); return
        }
        #expect(bind.name == "tiers")
        #expect(rows.count == 1)
    }

    @Test("decision-table rows can expand via inline do-chains")
    func decisionTableInlineChain() throws {
        let block = try parse("""
        | status | action |
        | --- | --- |
        | * | do complete and commit. |
        """)
        #expect(block.statements.count >= 2)
    }

    @Test("topic labels with an empty trailing colon error before the body")
    func topicLabelEmptyRest() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            Setup:
            complete.
            """)
        }
    }

    @Test("bind values can pick up a fenced code block on the next line")
    func bindValueFromFollowingFence() throws {
        let block = try parse("""
        bind script =
        ```text
        hello
        ```
        """)
        guard case .bind(let b) = block.statements.first,
              case .literal(.string(let body)) = b.value else {
            Issue.record("expected literal bind from fence"); return
        }
        #expect(body == "hello")
    }

    @Test("parseStatement rewrite hook re-parses when parseBlock hoist was bypassed")
    func parseStatementRewriteHookDirect() throws {
        let rulebook = Rulebook(desugars: [
            DesugarRule(
                name: "arrow",
                match: [.literal("If "), .hole("cond"), .literal(" -> "), .hole("action")],
                rewrite: "if {cond}, {action}."
            )
        ])
        let engine = RewriteEngine(rulebook: rulebook)
        let parser = StatementParser(symbols: SymbolTable(), rewriteEngine: engine)
        let line = SourceLine(indent: 0, text: "If ready -> complete", raw: "If ready -> complete", number: 1)
        let (stmt, _) = try parser.parseStatement([line], at: 0, sourceFile: "t.meridian")
        guard case .conditional = stmt else {
            Issue.record("expected rewritten conditional"); return
        }
    }

    @Test("topic labels error when the labelled body yields no statement")
    func topicLabelWrapsSentinelOnSameLine() throws {
        let sentinel = try #require(
            IndentTokenizer().tokenize("""
            !!! table (( inert ))
            | a | b |
            | --- | --- |
            | 1 | 2 |
            """).first?.text
        )
        let parser = StatementParser(symbols: SymbolTable())
        let line = SourceLine(indent: 0, text: "Setup: \(sentinel)", raw: "", number: 1)
        #expect(throws: CompilerError.self) {
            _ = try parser.parseStatement([line], at: 0, sourceFile: "t.meridian")
        }
    }

    @Test("invariant checklist rejects dispatch-phrase items")
    func invariantChecklistRejectsDispatchPhrase() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! checklist (( invariant ))
            - [ ] run the deployment
            """)
        }
    }

    @Test("choice gates accept dotted numbered list markers")
    func choiceGateDottedNumbers() throws {
        let block = try parse("""
        ask the user to choose between:
            1. Remote Postgres
            2. Local SQLite
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options.count == 2)
    }

    @Test("emit payloads can continue on the next line after a trailing comma")
    func emitCommaContinuationLine() throws {
        let block = try parse("""
        emit order.placed with note = "hi",
            count = 2.
        """)
        guard case .emit(let emit) = block.statements.first else {
            Issue.record("expected emit"); return
        }
        #expect(emit.payload.count >= 2)
    }

    @Test("shell blocks join across a blank line when a continuation is pending")
    func shellBlockContinuationAcrossBlankLine() throws {
        let block = try parse("""
        ```sh
        echo start \\
        
        echo end
        ```
        """)
        let cmds = block.statements.compactMap { stmt -> String? in
            guard case .phraseInvocation(let p) = stmt else { return nil }
            return decodeShellCommand(p.words)
        }
        #expect(cmds.count >= 1)
        #expect(cmds.joined(separator: " ").contains("start"))
        #expect(cmds.joined(separator: " ").contains("end"))
    }

    @Test("do-comma-and chains strip a leading and from the following chunk")
    func doCommaAndChainStripsLeadingAnd() throws {
        let block = try parse("do complete, and commit.")
        #expect(block.statements.count == 2)
    }

    @Test("inline conditionals treat comma-or as an Oxford continuation, not a split")
    func inlineConditionalOxfordOr() throws {
        let block = try parse("if ci is passed, or ci is failed, complete.")
        guard case .conditional = block.statements.first else {
            Issue.record("expected conditional"); return
        }
    }

    @Test("bind with an empty RHS stops at a non-fence following line")
    func bindEmptyRHSStopsAtNonFence() throws {
        let block = try parse("""
        bind script =
        complete.
        """)
        guard case .bind(let b) = block.statements.first,
              case .malformed = b.value else {
            Issue.record("expected malformed bind from empty RHS"); return
        }
        #expect(block.statements.count >= 2)
    }

    @Test("decide-using stops at a non-fence following line")
    func decideUsingStopsAtNonFence() throws {
        let block = try parse("""
        bind verdict = decide using:
        complete.
        """)
        guard case .bind(let b) = block.statements.first,
              case .invoke(let tool, let args) = b.value else {
            Issue.record("expected decide-using invoke"); return
        }
        #expect(tool == "llm.decide")
        guard case .literal(.string(let q)) = args.first?.1 else {
            Issue.record("expected empty question"); return
        }
        #expect(q.isEmpty)
    }

    @Test("emit payloads can continue when the header line omits a with suffix")
    func emitContinuationWithoutWithSuffix() throws {
        let block = try parse("""
        emit order.placed
            with note = "hi".
        """)
        guard case .emit(let emit) = block.statements.first else {
            Issue.record("expected emit"); return
        }
        #expect(emit.eventID.contains("order.placed"))
    }

    @Test("recover headers without a trailing colon raise MER1003")
    func recoverHeaderWithoutColon() throws {
        #expect(throws: CompilerError.self) {
            _ = try parse("recover from any")
        }
        do {
            _ = try parse("recover from any")
            Issue.record("expected malformed recover header to throw")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .unparseableStatement })
            #expect(diags.first?.message.contains("malformed `recover` header") == true)
        }
    }

    @Test("commit labels accept single-quoted strings")
    func commitWithSingleQuotedLabel() throws {
        let block = try parse("commit with label 'checkpoint'.")
        guard case .commit(let c) = block.statements.first else {
            Issue.record("expected commit"); return
        }
        #expect(c.label == "checkpoint")
    }

    @Test("passive voice rewrites verbs ending in -ved to the active stem")
    func passiveVoiceVedStem() throws {
        let block = try parse("the file should be archived.")
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(phrase.words == "archive the file")
    }

    @Test("choice gates accept dash-bulleted option labels")
    func choiceGateDashBullets() throws {
        let block = try parse("""
        ask the user to choose between:
            - Remote Postgres
            - Local SQLite
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options.count == 2)
    }

    @Test("fallback chains accept dash-bulleted steps")
    func fallbackChainDashBullets() throws {
        let block = try parse("""
        try the following in order until one succeeds:
        - Run `gbrain doctor`.
        - Run `gbrain reset`.
        """)
        guard case .recover = block.statements.first else {
            Issue.record("expected recover chain"); return
        }
    }

    @Test("choice gates accept spaced numbered labels without dot or paren")
    func choiceGateSpacedNumberLabel() throws {
        let block = try parse("""
        ask the user to choose between:
            1 Remote Postgres
            2 Local SQLite
        """)
        guard case .wait(let wait) = block.statements.first,
              case .choice(_, let options) = wait.condition else {
            Issue.record("expected choice wait"); return
        }
        #expect(options.count == 2)
    }

    @Test("wait forms that do not match a known condition fall through")
    func waitUnknownConditionFallsThrough() throws {
        let block = try parse("wait until the order is ready.")
        guard case .phraseInvocation = block.statements.first else {
            Issue.record("expected phrase invocation fallback"); return
        }
    }

    @Test("wait for signal accepts single-quoted names")
    func waitSignalSingleQuoted() throws {
        let block = try parse("wait for signal 'manual_review_complete'.")
        guard case .wait(let wait) = block.statements.first,
              case .signal(let name) = wait.condition else {
            Issue.record("expected signal wait"); return
        }
        #expect(name == "manual_review_complete")
    }

    @Test("do-comma-and chains strip a leading then from the following chunk")
    func doCommaAndChainStripsLeadingThen() throws {
        let block = try parse("do complete, and then commit.")
        #expect(block.statements.count == 2)
    }

}
