import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Wave 7 verbalizer equality")
struct VerbalizerEqualityTests {
    @Test("workflow equality ignores location carriers")
    func workflowLocationIgnored() {
        let a = IRWorkflow(
            name: "process an order",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(
                statements: [.complete(CompleteIR(sourceRange: SourceRange(file: "a.meri", line: 2, column: 3)))],
                sourceRange: SourceRange(file: "a.meri", line: 1, column: 1)
            ),
            sourceFile: "a.meri",
            sourceRange: SourceRange(file: "a.meri", line: 1, column: 1)
        )
        let b = IRWorkflow(
            name: "process an order",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(
                statements: [.complete(CompleteIR(sourceRange: SourceRange(file: "b.meri", line: 20, column: 30)))],
                sourceRange: SourceRange(file: "b.meri", line: 10, column: 10)
            ),
            sourceFile: "b.meri",
            sourceRange: SourceRange(file: "b.meri", line: 10, column: 10)
        )

        #expect(IREquality.structurallyEqual(a, b))
        #expect(IREquality.structurallyEqual([a], [b]))
    }

    @Test("semantic fields are compared")
    func semanticFieldsCompared() {
        let a = IRPrimitive.complete(CompleteIR(reason: "ok"))
        let b = IRPrimitive.complete(CompleteIR(reason: "not ok"))
        #expect(!IREquality.structurallyEqual(a, b))

        let lhs = IRExpression.comparison(.identifierRef(name: "score"), .greaterThan, .literal(.number(10)))
        let rhs = IRExpression.comparison(.identifierRef(name: "score"), .greaterOrEqual, .literal(.number(10)))
        #expect(!IREquality.structurallyEqual(lhs, rhs))
    }

    @Test("tuple sort fields compare path and direction")
    func sortTupleCompared() {
        let a = DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            sort: (path: "createdAt", ascending: false),
            take: 3
        )
        let b = DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            sort: (path: "createdAt", ascending: false),
            take: 3
        )
        let c = DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            sort: (path: "createdAt", ascending: true),
            take: 3
        )

        #expect(IREquality.structurallyEqual(a, b))
        #expect(!IREquality.structurallyEqual(a, c))
    }

    @Test("all primitive cases compare equal to themselves")
    func allPrimitiveCasesSelfEqual() {
        let expr = IRExpression.literal(.boolean(true))
        let block = IRBlock(statements: [.complete(CompleteIR())])
        let primitives: [IRPrimitive] = [
            .invoke(InvokeIR(toolID: "tool.run", arguments: [InvokeArg("value", .literal(.string("x")))], resultBinding: "result", comment: "note")),
            .bind(BindIR(name: "value", expression: .literal(.number(1)))),
            .branch(BranchIR(condition: .predicate(expr), thenBlock: block, elseBlock: block)),
            .iterate(IterateIR(mode: .overCollection(parameter: "item", kind: KindRef("Item"), collection: .identifierRef(name: "items")), body: block)),
            .assert(AssertIR(condition: expr, message: "Expected true", otherwiseAction: block)),
            .emit(EmitIR(eventID: "demo.event", payload: [EmitField("value", .identifierRef(name: "value"))], strict: false)),
            .wait(WaitIR(condition: .choice(prompt: "Pick", options: ["A", "B"]), timeout: .seconds(5))),
            .commit(CommitIR(label: "checkpoint")),
            .recover(RecoverIR(pattern: .predicate(expr), handler: block, attachedTo: block)),
            .simultaneously(SimultaneouslyIR(branches: [block], detached: true)),
            .aiJudgment(AIJudgmentIR(text: "decide", scopedTools: ["shell.run"], snapshotKeys: ["state"], guidance: "guide")),
            .aiAutonomy(AIAutonomyIR(text: "repair", scopedTools: ["ci.fix"], snapshotKeys: ["state"], autonomy: AutonomyConfigIR(until: expr, unless: .literal(.boolean(false)), replanAfterFailures: 2, maxSteps: 4), guidance: "guide")),
            .complete(CompleteIR(reason: "done")),
        ]

        for primitive in primitives {
            #expect(IREquality.structurallyEqual(primitive, primitive), Comment(rawValue: "\(primitive)"))
        }
    }
}
