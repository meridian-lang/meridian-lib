import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("SwiftEmitter+ControlFlow coverage")
struct SwiftEmitterControlFlowCoverageTests {
    private let e = SwiftEmitter()
    private var ctx: Ctx { Ctx(depth: 0, options: .init()) }
    private var workflow: IRWorkflow { IRWorkflow(name: "w", parameters: [], body: IRBlock(statements: [])) }

    @Test("indeterminateThenCondition covers asTrue vs asFalse/explicit")
    func indeterminateThenPolicies() {
        #expect(e.indeterminateThenCondition(truthVar: "t", policy: .asTrue).contains(".indeterminate"))
        #expect(!e.indeterminateThenCondition(truthVar: "t", policy: .asFalse).contains(".indeterminate"))
        #expect(!e.indeterminateThenCondition(truthVar: "t", policy: .explicit).contains(".indeterminate"))
    }

    @Test("emitBranchTakenCall defaults step when stableStepPath is nil")
    func branchTakenNilStep() {
        let out = e.emitBranchTakenCall(ctx: ctx, condition: "c", into: "then", stableStepPath: nil)
        #expect(out.contains("\"branch\""))
    }

    @Test("emitDeonticDenyIfNeeded is empty for nil and emits throw when blocking")
    func deonticDenyArms() {
        let empty = e.emitDeonticDenyIfNeeded(nil, ctx: ctx, stableStepPath: nil).toString(separator: "\n")
        #expect(empty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let guardIR = DeonticGuardIR(
            obligationId: "o1",
            disposition: .prevented,
            blocking: true,
            actionPattern: ActionPatternIR(toolID: "shell.run")
        )
        let blocking = e.emitDeonticDeny(guardIR, ctx: ctx, stableStepPath: nil).toString(separator: "\n")
        #expect(blocking.contains("recordViolation"))
        #expect(blocking.contains("throw MeridianRuntimeError.violation"))

        let soft = e.emitDeonticDeny(
            DeonticGuardIR(
                obligationId: "o2",
                disposition: .observed,
                blocking: false,
                actionPattern: ActionPatternIR(toolID: "http.get")
            ),
            ctx: ctx,
            stableStepPath: "step.1"
        ).toString(separator: "\n")
        #expect(soft.contains("\"step.1\""))
        #expect(!soft.contains("throw MeridianRuntimeError.violation"))
    }

    @Test("emitSimultaneously covers detached Task and joining task-group forms")
    func simultaneouslyVariants() {
        let branch = IRBlock(statements: [])
        let detached = e.emitSimultaneously(
            SimultaneouslyIR(branches: [branch], detached: true),
            ctx: ctx,
            workflow: workflow
        ).toString(separator: "\n")
        #expect(detached.contains("Task {"))
        #expect(!detached.contains("withThrowingTaskGroup"))

        let joined = e.emitSimultaneously(
            SimultaneouslyIR(branches: [branch, branch], detached: false),
            ctx: ctx,
            workflow: workflow
        ).toString(separator: "\n")
        #expect(joined.contains("withThrowingTaskGroup"))
        #expect(joined.contains("waitForAll"))
    }

    @Test("errorPattern helpers cover any/named/typed/predicate")
    func errorPatternHelpers() {
        #expect(e.errorPatternTraceName(.anyError) == "any")
        #expect(e.errorPatternTraceName(.named("timeout")) == "timeout")
        #expect(e.errorPatternTraceName(.typed(KindRef("TimeoutError"))) == "TimeoutError")
        #expect(e.errorPatternTraceName(.predicate(.literal(.boolean(true)))).contains("true"))

        #expect(e.errorPatternClause(.anyError).clause.contains("let _recoveredError"))
        #expect(e.errorPatternClause(.named("x")).clause.contains("meridianMatches"))
        #expect(e.errorPatternClause(.typed(KindRef("E"))).clause.contains("as E"))
        #expect(e.errorPatternClause(.predicate(.literal(.boolean(false)))).clause.contains("where"))
    }

    @Test("emitWait covers duration/signal/event/choice/approval arms")
    func emitWaitVariants() {
        let duration = e.emitWait(WaitIR(condition: .duration(.seconds(1))), ctx: ctx)
            .toString(separator: "\n")
        #expect(duration.contains(".duration"))

        let signal = e.emitWait(WaitIR(condition: .signal("go"), timeout: .seconds(5)), ctx: ctx)
            .toString(separator: "\n")
        #expect(signal.contains(".signal"))
        #expect(signal.contains("timeout:"))

        let event = e.emitWait(WaitIR(condition: .event("paid", matching: nil)), ctx: ctx)
            .toString(separator: "\n")
        #expect(event.contains("matching: nil"))

        let matched = e.emitWait(
            WaitIR(condition: .event("paid", matching: .literal(.boolean(true)))),
            ctx: ctx
        ).toString(separator: "\n")
        #expect(matched.contains("matching: { _event in"))

        let choice = e.emitWait(
            WaitIR(condition: .choice(prompt: "Pick", options: ["a", "b"])),
            ctx: ctx
        ).toString(separator: "\n")
        #expect(choice.contains(".choice"))
        #expect(choice.contains("consumeChoiceSelection"))

        let approval = e.emitWait(
            WaitIR(condition: .approval(of: .literal(.string("order")), by: "manager")),
            ctx: ctx
        ).toString(separator: "\n")
        #expect(approval.contains(".approval"))
    }
}

@Suite("SwiftEmitter+FileTail coverage")
struct SwiftEmitterFileTailCoverageTests {
    @Test("sourceLineComment respects emitSourceLineComments and zero line")
    func sourceLineCommentFlags() {
        let on = SwiftEmitter(options: .init(emitSourceLineComments: true))
        let off = SwiftEmitter(options: .init(emitSourceLineComments: false))
        let ctxOn = Ctx(depth: 0, options: on.options)
        let ctxOff = Ctx(depth: 0, options: off.options)
        let ranged = SourceRange(file: "t.meridian", line: 3, column: 1)
        #expect(on.sourceLineComment(ranged, ctx: ctxOn).toString(separator: "\n").contains("// L3"))
        #expect(off.sourceLineComment(ranged, ctx: ctxOff).toString(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(on.sourceLineComment(.unknown, ctx: ctxOn).toString(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("blockEndsWithComplete recognizes complete and nested branch completeness")
    func blockEndsWithComplete() {
        let e = SwiftEmitter()
        #expect(e.blockEndsWithComplete(IRBlock(statements: [
            .complete(CompleteIR(reason: "done"))
        ])))
        #expect(!e.blockEndsWithComplete(IRBlock(statements: [
            .commit(CommitIR())
        ])))
        let completeBlock = IRBlock(statements: [.complete(CompleteIR())])
        let branch = BranchIR(
            condition: .predicate(.literal(.boolean(true))),
            thenBlock: completeBlock,
            elseBlock: completeBlock
        )
        #expect(e.blockEndsWithComplete(IRBlock(statements: [.branch(branch)])))
    }

    @Test("emitInstanceValue and typeOfLiteral cover env-var and calendarAmount")
    func instanceValueAndLiteralTypes() {
        let e = SwiftEmitter()
        #expect(e.emitInstanceValue(.envVar("HOME")).contains("ProcessInfo"))
        #expect(e.emitInstanceValue(.literal(.string("x"))).contains(".string"))
        #expect(e.typeOfLiteral(.calendarAmount(CalendarAmountIR(magnitude: 1, unit: .months))) == "Record")
        #expect(e.typeOfLiteral(.money(1, currency: "USD")) == "Money")
    }

    @Test("fileHeader includes timestamp when requested")
    func fileHeaderTimestamp() {
        let with = SwiftEmitter(options: .init(includeTimestamp: true, sourceFileName: "demo.meridian"))
        let out = with.fileHeader().toString(separator: "\n")
        #expect(out.contains("Source: demo.meridian"))
        #expect(out.contains("Generated at:"))
    }
}
