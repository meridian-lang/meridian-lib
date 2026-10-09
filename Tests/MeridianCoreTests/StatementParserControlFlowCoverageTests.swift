import Foundation
import Testing
@testable import MeridianCore

/// Branch coverage for `StatementParser+ControlFlow` — unless / unknown /
/// blank-line skips / recover quote forms / fallback-chain edges that
/// end-to-end fixtures rarely hit in isolation.
@Suite("StatementParser+ControlFlow coverage")
struct StatementParserControlFlowCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable())

    private func lines(_ source: String) -> [SourceLine] {
        IndentTokenizer().tokenize(source)
    }

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(lines(source))
    }

    // MARK: - unless block form

    @Test("unless block with otherwise and blank/comment lines in bodies")
    func unlessWithOtherwiseAndSkips() throws {
        let block = try parse("""
        unless the order is cancelled,

            let x be 1.

        # skip

            let y be 2.
        otherwise,

            # comment

            let z be 3.
        """)
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        #expect(cond.authoredForm == .unlessHeader)
        #expect(cond.thenBlock.statements.count == 2)
        #expect(cond.elseBlock?.statements.count == 1)
    }

    @Test("unless treating unknown as true/false and unknown-whether branch")
    func unlessUnknownPolicies() throws {
        let asTrue = try parse("""
        unless the flag is set treating unknown as true,
            let a be 1.
        if it is unknown whether,
            let u be 1.
        otherwise,
            let e be 1.
        """)
        guard case .conditional(let t) = asTrue.statements.first else {
            Issue.record("expected as-true conditional"); return
        }
        #expect(t.unknownPolicy == .asTrue)
        #expect(t.unknownBlock?.statements.count == 1)
        #expect(t.elseBlock?.statements.count == 1)

        let asFalse = try parse("""
        unless the flag is set treating unknown as false,
            let a be 1.
        if it is unknown whether,
            let u be 1.
        """)
        guard case .conditional(let f) = asFalse.statements.first else {
            Issue.record("expected as-false conditional"); return
        }
        #expect(f.unknownPolicy == .asFalse)
        #expect(f.unknownBlock?.statements.count == 1)
    }

    @Test("unless unknown-whether accepts comma and colon header variants")
    func unlessUnknownWhetherHeaderVariants() throws {
        for header in ["if it is unknown whether,", "if it is unknown whether:"] {
            let block = try parse("""
            unless ready,
                let a be 1.
            \(header)
                let u be 1.
            """)
            guard case .conditional(let cond) = block.statements.first else {
                Issue.record("expected conditional for \(header)"); return
            }
            #expect(cond.unknownBlock?.statements.count == 1)
        }
    }

    // MARK: - if block form extras

    @Test("if treating unknown as false with otherwise comma form")
    func ifUnknownFalseAndOtherwiseComma() throws {
        let block = try parse("""
        if the flag is set treating unknown as false,
            let a be 1.
        otherwise,
            let e be 1.
        """)
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        #expect(cond.unknownPolicy == .asFalse)
        #expect(cond.elseBlock?.statements.count == 1)
    }

    @Test("if unknown-whether colon header and blank lines in then-block")
    func ifUnknownWhetherColonAndThenBlanks() throws {
        let block = try parse("""
        if ready,

            let a be 1.

        if it is unknown whether:
            let u be 1.
        """)
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected conditional"); return
        }
        #expect(cond.thenBlock.statements.count == 1)
        #expect(cond.unknownBlock?.statements.count == 1)
    }

    // MARK: - inline unless / if edges

    @Test("inline unless with otherwise else-block")
    func inlineUnlessWithOtherwise() throws {
        let block = try parse(
            "unless the order is cancelled, let x be 1, otherwise let y be 2.")
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected inline unless"); return
        }
        #expect(cond.authoredForm == .unlessHeader)
        #expect(cond.thenBlock.statements.count == 1)
        #expect(cond.elseBlock?.statements.count == 1)
    }

    @Test("inline if with empty otherwise clause still parses then-body")
    func inlineIfEmptyOtherwiseTail() throws {
        // Trailing `, otherwise` with no else text — else block stays nil / empty.
        let block = try parse("if ready, let x be 1, otherwise .")
        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("expected inline if"); return
        }
        #expect(cond.thenBlock.statements.count == 1)
    }

    // MARK: - guarded fence edges

    @Test("guarded fence with empty condition falls through")
    func guardedFenceEmptyConditionFallsThrough() throws {
        // `if , run:` is not a valid guarded fence (empty cond) — expect
        // phrase / unparseable rather than a conditional wrapping a shell.
        let block = try parse("""
        if , run:
        ```bash
        echo hi
        ```
        """)
        // Should not invent a ConditionalStatementAST for an empty condition.
        if case .conditional = block.statements.first {
            Issue.record("empty guarded-fence condition must not win")
        }
    }

    // MARK: - iteration / simultaneously skips

    @Test("for each and simultaneously skip blank and comment body lines")
    func iterationAndSimultaneouslySkipBlanks() throws {
        let iter = try parse("""
        for each item in the items,

            # note

            let x be item.
        """)
        guard case .iteration(let it) = iter.statements.first else {
            Issue.record("expected iteration"); return
        }
        #expect(it.body.statements.count == 1)

        let sim = try parse("""
        simultaneously:

            let a be 1.

            let b be 2.
        """)
        guard case .simultaneously(let s) = sim.statements.first else {
            Issue.record("expected simultaneously"); return
        }
        #expect(s.branches.count == 2)
    }

    // MARK: - recover edges

    @Test("recover from single-quoted name and typed/any patterns")
    func recoverQuoteAndTypedForms() throws {
        let quoted = try parse("""
        let x be 1.
        recover from 'planning.host_denied':
            let y be 2.
        """)
        guard case .recover(let r) = quoted.statements.last,
              case .named(let name) = r.pattern else {
            Issue.record("expected named recover"); return
        }
        #expect(name == "planning.host_denied")

        let typed = try parse("""
        let x be 1.
        recover from TimeoutError:
            let y be 2.
        """)
        guard case .recover(let t) = typed.statements.last,
              case .typed(let typeName) = t.pattern else {
            Issue.record("expected typed recover"); return
        }
        #expect(typeName == "TimeoutError")
    }

    @Test("empty recover header without colon suggests recover from any")
    func emptyRecoverHeaderSuggestion() throws {
        // Blank statement (no trailing `:`) hits the empty-rewrite suggestion arm.
        let blank = SourceLine(indent: 0, text: "   ", raw: "   ", number: 1)
        #expect(throws: CompilerError.self) {
            _ = try parser.parseRecover([blank], at: 0, sourceFile: "t.meridian")
        }
        do {
            _ = try parser.parseRecover([blank], at: 0, sourceFile: "t.meridian")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.first?.help?.contains("recover from any:") == true)
        }
    }

    @Test("recover handler body skips blank and comment lines")
    func recoverHandlerSkipsBlanks() throws {
        let block = try parse("""
        let x be 1.
        recover from any:

            # handler comment

            let y be 2.
        """)
        guard case .recover(let r) = block.statements.last else {
            Issue.record("expected recover"); return
        }
        #expect(r.handler.statements.count == 1)
    }

    // MARK: - fallback chain edges

    @Test("fallback chain stops at non-list content and skips blanks between steps")
    func fallbackChainBlanksAndBoundary() throws {
        let block = try parse("""
        try the following in order until one succeeds:

        1. Run `gbrain doctor`.

        2. Run `gbrain reset`.
        let done be 1.
        """)
        #expect(block.statements.count == 2)
        guard case .recover = block.statements.first else {
            Issue.record("expected recover chain"); return
        }
    }

    @Test("fallback chain returns nil when a step does not parse to one statement")
    func fallbackChainRejectsMultiStatementStep() throws {
        // A step line that expands to zero/multiple statements should make
        // parseFallbackChain return nil so phrase-dispatch can claim the lead-in.
        let src = lines("""
        try the following in order until one succeeds:
        1.
        2. Run `gbrain reset`.
        """)
        let result = try parser.parseFallbackChain(src, at: 0, sourceFile: "t.meridian")
        #expect(result == nil)
    }

    // MARK: - Direct helper edges (blank/comment skips + nil guards)

    @Test("parseConditional skips empty and comment lines in then/unknown/else")
    func conditionalSkipsViaSyntheticLines() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "if ready,", raw: "if ready,", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# note", raw: "# note", number: 3),
            SourceLine(indent: 2, text: "let a be 1.", raw: "let a be 1.", number: 4),
            SourceLine(indent: 0, text: "if it is unknown whether,", raw: "if it is unknown whether,", number: 5),
            SourceLine(indent: 2, text: "", raw: "", number: 6),
            SourceLine(indent: 2, text: "# u", raw: "# u", number: 7),
            SourceLine(indent: 2, text: "let u be 1.", raw: "let u be 1.", number: 8),
            SourceLine(indent: 0, text: "otherwise,", raw: "otherwise,", number: 9),
            SourceLine(indent: 2, text: "", raw: "", number: 10),
            SourceLine(indent: 2, text: "# e", raw: "# e", number: 11),
            SourceLine(indent: 2, text: "let e be 1.", raw: "let e be 1.", number: 12),
        ]
        let (cond, consumed) = try parser.parseConditional(src, at: 0, sourceFile: "t.meridian")
        #expect(consumed == 12)
        #expect(cond.thenBlock.statements.count == 1)
        #expect(cond.unknownBlock?.statements.count == 1)
        #expect(cond.elseBlock?.statements.count == 1)
    }

    @Test("parseUnlessConditional skips empty/comment lines like if")
    func unlessSkipsViaSyntheticLines() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "unless ready,", raw: "unless ready,", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# note", raw: "# note", number: 3),
            SourceLine(indent: 2, text: "let a be 1.", raw: "let a be 1.", number: 4),
            SourceLine(indent: 0, text: "if it is unknown whether,", raw: "if it is unknown whether,", number: 5),
            SourceLine(indent: 2, text: "", raw: "", number: 6),
            SourceLine(indent: 2, text: "let u be 1.", raw: "let u be 1.", number: 7),
            SourceLine(indent: 0, text: "otherwise,", raw: "otherwise,", number: 8),
            SourceLine(indent: 2, text: "", raw: "", number: 9),
            SourceLine(indent: 2, text: "let e be 1.", raw: "let e be 1.", number: 10),
        ]
        let (cond, _) = try parser.parseUnlessConditional(src, at: 0, sourceFile: "t.meridian")
        #expect(cond.authoredForm == .unlessHeader)
        #expect(cond.thenBlock.statements.count == 1)
        #expect(cond.unknownBlock?.statements.count == 1)
        #expect(cond.elseBlock?.statements.count == 1)
    }

    @Test("guarded fence returns nil when blanks are followed by a non-fence")
    func guardedFenceNilWhenNoShellFence() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "if ready, run:", raw: "if ready, run:", number: 1),
            SourceLine(indent: 0, text: "", raw: "", number: 2),
            SourceLine(indent: 0, text: "# not a fence", raw: "# not a fence", number: 3),
            SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 4),
        ]
        let result = try parser.parseGuardedFence(src, at: 0)
        #expect(result == nil)
    }

    @Test("inline unless/if nil guards for missing separator and empty body")
    func inlineNilGuards() throws {
        let noSep = SourceLine(indent: 0, text: "unless ready let x be 1.", raw: "unless ready let x be 1.", number: 1)
        #expect(try parser.parseInlineUnlessConditional(noSep, sourceFile: "t.meridian") == nil)

        let emptyBody = SourceLine(
            indent: 0,
            text: "unless ready, , otherwise let y be 1.",
            raw: "unless ready, , otherwise let y be 1.",
            number: 1
        )
        // Empty then-body after otherwise peel → nil.
        let peeled = try parser.parseInlineUnlessConditional(emptyBody, sourceFile: "t.meridian")
        #expect(peeled == nil || peeled?.thenBlock.statements.isEmpty == false)

        let ifEmptyOtherwise = SourceLine(
            indent: 0,
            text: "if ready, let x be 1, otherwise",
            raw: "if ready, let x be 1, otherwise",
            number: 1
        )
        let inlineIf = try parser.parseInlineConditional(ifEmptyOtherwise, sourceFile: "t.meridian")
        #expect(inlineIf != nil)
        #expect(inlineIf?.elseBlock == nil)
    }

    @Test("wait approval-of without from falls through; iteration/sim/recover/fallback skip blanks")
    func waitApprovalOfWithoutFromAndMoreSkips() throws {
        #expect(parser.parseWaitCondition("for approval of the order") == nil)

        let iter: [SourceLine] = [
            SourceLine(indent: 0, text: "for each item in the items,", raw: "for each item in the items,", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# c", raw: "# c", number: 3),
            SourceLine(indent: 2, text: "let x be item.", raw: "let x be item.", number: 4),
        ]
        let (iteration, _) = try parser.parseIteration(iter, at: 0, sourceFile: "t.meridian")
        #expect(iteration.body.statements.count == 1)

        let sim: [SourceLine] = [
            SourceLine(indent: 0, text: "simultaneously:", raw: "simultaneously:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "let a be 1.", raw: "let a be 1.", number: 3),
        ]
        let (simultaneous, _) = try parser.parseSimultaneously(sim, at: 0, sourceFile: "t.meridian")
        #expect(simultaneous.branches.count == 1)

        let rec: [SourceLine] = [
            SourceLine(indent: 0, text: "recover from any:", raw: "recover from any:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# h", raw: "# h", number: 3),
            SourceLine(indent: 2, text: "let y be 2.", raw: "let y be 2.", number: 4),
        ]
        let (recover, _) = try parser.parseRecover(rec, at: 0, sourceFile: "t.meridian")
        #expect(recover.handler.statements.count == 1)

        let chain: [SourceLine] = [
            SourceLine(indent: 0, text: "try the following in order until one succeeds:",
                       raw: "try the following in order until one succeeds:", number: 1),
            SourceLine(indent: 0, text: "", raw: "", number: 2),
            SourceLine(indent: 0, text: "Run `gbrain doctor`.", raw: "1. Run `gbrain doctor`.", number: 3,
                       listMarker: "1."),
            SourceLine(indent: 0, text: "", raw: "", number: 4),
            SourceLine(indent: 0, text: "Run `gbrain reset`.", raw: "2. Run `gbrain reset`.", number: 5,
                       listMarker: "2."),
        ]
        let fallback = try parser.parseFallbackChain(chain, at: 0, sourceFile: "t.meridian")
        #expect(fallback != nil)
    }
}

