import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("ASTToIR+Phrase coverage")
struct ASTToIRPhraseCoverageTests {

    private func makeIR(symbols: SymbolTable = SymbolTable(trace: .silent())) -> ASTToIR {
        ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
    }

    private func eventPattern(predicate: ExpressionAST? = .identifierRef("the user")) -> EventPatternAST {
        EventPatternAST(subject: .step("deploy"), outcome: .failed, payloadPredicate: predicate)
    }

    private func inlineBody(
        _ statements: [StatementAST],
        args: [String: ExpressionAST] = [:],
        at line: Int = 42
    ) throws -> [IRPrimitive] {
        let phrase = PhraseDefinition(
            pattern: PhrasePattern(segments: [.literal("do it")]),
            body: ASTBlock(statements: statements, sourceLine: 1),
            sourceLine: 1
        )
        return try makeIR().inlinePhrase(
            phrase,
            args: args,
            invocationLine: line,
            mode: .strict,
            depth: 0
        )
    }

    @Test("phrase inline depth exceeded raises phraseInlineDepthExceeded")
    func phraseInlineDepthExceeded() throws {
        let ir = makeIR()
        do {
            _ = try ir.lowerPhraseInvocation(
                PhraseInvocationAST(words: "do a thing", sourceLine: 1),
                mode: .strict,
                depth: ir.maxInlineDepth
            )
            Issue.record("expected depth exceeded")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .phraseInlineDepthExceeded })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("shell command phrase lowers to shell.run invoke")
    func shellCommandPhrase() throws {
        let ir = makeIR()
        let words = encodeShellCommand("echo hi")
        let primitives = try ir.lowerPhraseInvocation(
            PhraseInvocationAST(words: words, sourceLine: 1),
            mode: .strict,
            depth: 0
        )
        #expect(primitives.count == 1)
        if case .invoke(let inv) = primitives[0] {
            #expect(inv.toolID == "shell.run")
        } else {
            Issue.record("expected shell.run invoke")
        }
    }

    @Test("substituteArgs replaces identifierRefs by descending key length")
    func substituteArgsOrder() {
        let ir = makeIR()
        let block = ASTBlock(statements: [
            .emit(EmitStatementAST(
                eventID: "e",
                payload: [("x", .identifierRef("total amount"))],
                sourceLine: 1
            ))
        ], sourceLine: 1)
        let out = ir.substituteArgs(block, args: [
            "amount": .literal(.integer(1)),
            "total amount": .literal(.integer(9)),
        ])
        guard case .emit(let e) = out.statements[0],
              let first = e.payload.first,
              case .literal(.integer(let n)) = first.1 else {
            Issue.record("expected emit with integer literal"); return
        }
        #expect(n == 9)
    }

    @Test("exprToText covers identifier/instance/constant/property/literal/now arms")
    func exprToTextMatrix() {
        let ir = makeIR()
        #expect(ir.exprToText(.identifierRef("order")) == "order")
        #expect(ir.exprToText(.instanceRef("acct")) == "the acct")
        #expect(ir.exprToText(.constantRef("limit")) == "the limit")
        #expect(ir.exprToText(.propertyAccess(.identifierRef("order"), "id")) == "order's id")
        #expect(ir.exprToText(.literal(.string("hi"))) == "\"hi\"")
        #expect(ir.exprToText(.literal(.integer(3))) == "3")
        #expect(ir.exprToText(.literal(.double(1.5))) == "1.5")
        #expect(ir.exprToText(.literal(.money(2.0, currency: "USD"))) == "$2.0")
        #expect(ir.exprToText(.now) == "now")
        #expect(ir.exprToText(.interpolatedString([.literal("x")])) == "")
        #expect(ir.exprToText(.invoke("t", [])) == "")
    }

    @Test("substituteArgs recurses through invoke/eventPattern/trace forms")
    func substituteArgsInvokeAndTraceShapes() {
        let ir = makeIR()
        let user = ExpressionAST.identifierRef("the user")
        let args = ["the user": ExpressionAST.identifierRef("substituted")]
        let pattern = eventPattern(predicate: user)
        let value: ExpressionAST = .logical(.and, [
            .invoke("tool.run", [("p", user)]),
            .eventPattern(pattern),
            .traceTemporal(TraceTemporalAST(kind: .ever(pattern))),
            .traceTemporal(TraceTemporalAST(kind: .withinWindow(pattern, duration: (5, .second)))),
            .traceTemporal(TraceTemporalAST(kind: .countInWindow(pattern, comparator: .atLeast(1), duration: (1, .minute)))),
            .traceTemporal(TraceTemporalAST(kind: .inARow(pattern, count: 2))),
            .traceTemporal(TraceTemporalAST(kind: .sinceLast(anchor: pattern, holds: user))),
            .traceTemporal(TraceTemporalAST(kind: .boundedFutureMonitor(
                condition: user, horizon: (10, .second), mode: .eventuallyWithin
            ))),
            .traceStatistical(TraceStatisticalAST(
                pattern: TraceStatisticalPatternAST(subject: .step("deploy"), payloadPredicate: user),
                outcome: .succeeds,
                bound: .atLeast(0.9),
                denominator: .runs
            )),
            .identifierRef("payment processor"),
            .instanceRef("acct"),
            .constantRef("limit"),
            .literal(.boolean(true)),
            .envVar("HOME"),
            .now,
            .decideWhether(question: "ok?"),
            .malformed("x"),
        ])
        let block = ASTBlock(statements: [
            .bind(BindStatementAST(name: "x", value: value, sourceLine: 1)),
            .note(NoteStatementAST(binding: "x", text: "note", sourceLine: 2)),
            .assertStmt(AssertStatementAST(condition: user, sourceLine: 3)),
            .wait(WaitStatementAST(condition: .duration(1, .second), sourceLine: 4)),
            .commit(CommitStatementAST(label: "c", sourceLine: 5)),
            .iteration(IterationStatementAST(
                mode: .whileCondition(user),
                body: ASTBlock(statements: [], sourceLine: 6),
                sourceLine: 6
            )),
            .recover(RecoverStatementAST(
                pattern: .any,
                handler: ASTBlock(statements: [], sourceLine: 7),
                attached: .emit(EmitStatementAST(eventID: "e", payload: [], sourceLine: 7)),
                sourceLine: 7
            )),
            .modal(.lenient),
            .phraseInvocation(PhraseInvocationAST(words: "notify the mailer server", sourceLine: 8)),
        ], sourceLine: 1)

        let out = ir.substituteArgs(block, args: args.merging([
            "mailerServer": .identifierRef("primary"),
            "paymentProcessor": .literal(.string("pp")),
        ]) { _, new in new })

        guard case .bind(let bind) = out.statements[0],
              case .logical(_, let exprs) = bind.value else {
            Issue.record("expected substituted bind"); return
        }
        #expect(exprs.count == 17)
        if case .invoke(_, let callArgs) = exprs[0],
           case .identifierRef(let name) = callArgs[0].1 {
            #expect(name == "substituted")
        } else {
            Issue.record("expected substituted invoke arg")
        }
        if case .eventPattern(let p) = exprs[1],
           case .identifierRef(let name) = p.payloadPredicate {
            #expect(name == "substituted")
        } else {
            Issue.record("expected substituted eventPattern payload")
        }
        if case .traceTemporal(let t) = exprs[6],
           case .sinceLast(_, let holds) = t.kind,
           case .identifierRef(let name) = holds {
            #expect(name == "substituted")
        } else {
            Issue.record("expected substituted sinceLast holds")
        }
        if case .traceStatistical(let s) = exprs[8],
           case .identifierRef(let name) = s.pattern.payloadPredicate {
            #expect(name == "substituted")
        } else {
            Issue.record("expected substituted statistical payload")
        }
        if case .literal(.string(let s)) = exprs[9] {
            #expect(s == "pp")
        } else {
            Issue.record("expected camelCase paymentProcessor lookup")
        }
        guard case .phraseInvocation(let inv) = out.statements[8] else {
            Issue.record("expected phraseInvocation"); return
        }
        #expect(inv.words.contains("primary"))
        #expect(!inv.words.contains("mailer"))
        // default substituteStmt passthroughs keep note/assert/wait/commit/iteration/recover/modal
        #expect({
            if case .note = out.statements[1] { return true }
            return false
        }())
        #expect({
            if case .modal = out.statements[7] { return true }
            return false
        }())
    }

    @Test("inlinePhrase retargets rare statement source lines to the invocation site")
    func inlinePhraseRetargetsRareShapes() throws {
        let line = 42
        let empty = ASTBlock(statements: [], sourceLine: 1)
        let primitives = try inlineBody([
            .bind(BindStatementAST(name: "log", value: .literal(.string("")), sourceLine: 1)),
            .note(NoteStatementAST(binding: "log", text: "hi", sourceLine: 1)),
            .assertStmt(AssertStatementAST(
                condition: .literal(.boolean(true)),
                otherwise: ASTBlock(statements: [
                    .complete(CompleteStatementAST(reason: "fallback", sourceLine: 1))
                ], sourceLine: 1),
                sourceLine: 1
            )),
            .wait(WaitStatementAST(condition: .duration(1, .second), sourceLine: 1)),
            .commit(CommitStatementAST(label: "ckpt", sourceLine: 1)),
            .complete(CompleteStatementAST(reason: "done", sourceLine: 1)),
            .matchBranch(MatchBranchStatementAST(
                subject: .literal(.string("a")),
                cases: [
                    MatchBranchCaseAST(
                        pattern: .literal(.literal(.string("a"))),
                        block: ASTBlock(statements: [
                            .emit(EmitStatementAST(eventID: "matched", payload: [], sourceLine: 1))
                        ], sourceLine: 1)
                    ),
                    MatchBranchCaseAST(pattern: .wildcard, block: empty),
                ],
                otherwiseBlock: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "otherwise", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                sourceLine: 1
            )),
            .recover(RecoverStatementAST(
                pattern: .named("payment.declined"),
                handler: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "recovered", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                attached: .emit(EmitStatementAST(eventID: "charge", payload: [], sourceLine: 1)),
                sourceLine: 1
            )),
            .conditional(ConditionalStatementAST(
                condition: .literal(.boolean(true)),
                thenBlock: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "then", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                unknownBlock: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "unknown", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                elseBlock: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "else", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                sourceLine: 1
            )),
            .iteration(IterationStatementAST(
                mode: .whileCondition(.literal(.boolean(false))),
                body: ASTBlock(statements: [
                    .emit(EmitStatementAST(eventID: "loop", payload: [], sourceLine: 1))
                ], sourceLine: 1),
                sourceLine: 1
            )),
            .simultaneously(SimultaneouslyStatementAST(
                branches: [
                    ASTBlock(statements: [
                        .emit(EmitStatementAST(eventID: "a", payload: [], sourceLine: 1))
                    ], sourceLine: 1),
                    ASTBlock(statements: [
                        .emit(EmitStatementAST(eventID: "b", payload: [], sourceLine: 1))
                    ], sourceLine: 1),
                ],
                sourceLine: 1
            )),
            .labelled(LabelledStatementAST(
                label: "step",
                statement: .emit(EmitStatementAST(eventID: "labelled", payload: [], sourceLine: 1)),
                sourceLine: 1
            )),
            .proseStep(ProseStepAST(text: "review the case", sourceLine: 1, dispatch: .discretion)),
            .modal(.lenient),
            .emit(EmitStatementAST(eventID: "tail", payload: [], sourceLine: 1)),
        ], at: line)

        let ranges = primitives.compactMap(\.sourceRange)
        #expect(!ranges.isEmpty)
        #expect(ranges.allSatisfy { $0.startLine == line })
    }
}
