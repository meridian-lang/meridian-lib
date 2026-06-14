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

    @Test("generated guidance judgment collects until next heading")
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
        #expect(step.text.contains("item: validate inputs"))
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
}
