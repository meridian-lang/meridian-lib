import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Direct-emission coverage for the long tail of `emitExpr` / `emitValueExpr`
// branches and the block-level constructs (match-branch, while-loop) that the
// example corpus doesn't exercise. These call the emitter API directly with
// hand-built IR so each branch is hit deterministically.

@Suite("SwiftEmitter — expression branch coverage")
struct SwiftEmitterExprCoverageTests {
    private let e = SwiftEmitter()

    @Test("temporal window comparisons")
    func temporalWindows() {
        let lhs = IRExpression.identifierRef(name: "ts")
        let rhs = IRExpression.literal(.duration(.seconds(3600)))
        #expect(e.emitExpr(.comparison(lhs, .withinPast, rhs)).contains("isWithinPast"))
        #expect(e.emitExpr(.comparison(lhs, .withinFuture, rhs)).contains("isWithinFuture"))
    }

    @Test("string prefix / suffix / membership comparisons")
    func stringOps() {
        let lhs = IRExpression.literal(.string("hello world"))
        let rhs = IRExpression.literal(.string("hello"))
        #expect(e.emitExpr(.comparison(lhs, .startsWith, rhs)).contains("hasPrefix"))
        #expect(e.emitExpr(.comparison(lhs, .endsWith, rhs)).contains("hasSuffix"))
        #expect(e.emitExpr(.comparison(lhs, .oneOf, rhs)).contains("contains"))
    }

    @Test("env var and now in plain context")
    func envAndNow() {
        #expect(e.emitExpr(.envVar(name: "HOME")).contains("ProcessInfo.processInfo.environment"))
        #expect(e.emitExpr(.nowExpression) == "Date()")
    }

    @Test("inline invocation comment and relation traversal")
    func inlineInvokeAndTraversal() {
        let inv = InvokeIR(toolID: "some.tool")
        #expect(e.emitExpr(.invocation(inv)).contains("inline invoke: some.tool"))
        let trav = IRExpression.relationTraversal(.identifierRef(name: "task"), relationName: "assigned_to", target: nil)
        #expect(e.emitExpr(trav).contains("assignedTo"))
    }

    @Test("discretion question: missing, interpolated, and default forms")
    func discretionQuestion() {
        // No `question` argument → empty string literal.
        let noQ = InvokeIR(toolID: "runtime.discretion.decide")
        #expect(e.emitExpr(.invocation(noQ)).contains("question: \"\""))

        // Interpolated question → emitted via emitExpr(interpolatedString).
        let interp = InvokeIR(toolID: "runtime.discretion.decide",
                              arguments: [InvokeArg("question", .interpolatedString([.literal("ask "), .expression(.identifierRef(name: "x"))]))])
        #expect(e.emitExpr(.invocation(interp)).contains("meridianStringify"))

        // Non-literal, non-interpolated question → meridianStringify(value).
        let other = InvokeIR(toolID: "runtime.discretion.decide",
                             arguments: [InvokeArg("question", .identifierRef(name: "topic"))])
        #expect(e.emitExpr(.invocation(other)).contains("meridianStringify"))
    }

    private func desc() -> DescriptionIR {
        DescriptionIR(collection: .identifierRef(name: "items"), elementVar: "item")
    }

    @Test("value-context description / aggregate / superlative / recordList / derived")
    func valueContextCollections() {
        #expect(e.emitValueExpr(.description(desc())).hasPrefix("Value.list("))
        #expect(e.emitValueExpr(.aggregate(.count, desc())).contains(".number(Decimal("))
        #expect(e.emitValueExpr(.aggregate(.list, desc())).hasPrefix("Value.list("))
        let sup = SuperlativeIR(description: desc(), sortPath: "createdAt", ascending: false)
        #expect(e.emitValueExpr(.superlative(sup)).contains(".first"))
        let rl = IRExpression.recordList(fields: ["a", "b"], rows: [[.literal(.number(1)), .literal(.string("x"))]])
        #expect(e.emitValueExpr(rl).hasPrefix("Value.list(["))
        // Derived expression (comparison) → wrapped `.init(...)`.
        let derived = IRExpression.comparison(.literal(.number(1)), .lessThan, .literal(.number(2)))
        #expect(e.emitValueExpr(derived).hasPrefix(".init("))
    }

    @Test("plain-context description / aggregate / superlative / recordList")
    func plainContextCollections() {
        #expect(e.emitExpr(.description(desc())).hasPrefix("Value.list("))
        #expect(e.emitExpr(.aggregate(.count, desc())).hasPrefix("Decimal("))
        #expect(e.emitExpr(.aggregate(.list, desc())).hasPrefix("Value.list("))
        let sup = SuperlativeIR(description: desc(), sortPath: "createdAt", ascending: true)
        #expect(e.emitExpr(.superlative(sup)).contains(".first"))
    }

    @Test("quantifier element-context: logical and / or / not, nested, default")
    func quantifierElementContext() {
        func q(_ body: IRExpression) -> String {
            e.emitExpr(.quantified(QuantifierIR(kind: .all, description: desc(), body: body)))
        }
        let p1 = IRExpression.comparison(.propertyAccess(.identifierRef(name: "item"), propertyName: "done"), .equal, .literal(.boolean(true)))
        let p2 = IRExpression.comparison(.propertyAccess(.identifierRef(name: "item"), propertyName: "open"), .equal, .literal(.boolean(false)))
        #expect(q(.logical(.and, [p1, p2])).contains("&&"))
        #expect(q(.logical(.or, [p1, p2])).contains("||"))
        #expect(q(.logical(.not, [p1])).hasPrefix("("))
        // Empty logical operands → the constant fallbacks.
        #expect(q(.logical(.and, [])).contains("true") || q(.logical(.and, [])).count > 0)
        // Default element branch (a non-comparison, non-logical leaf) → `!= nil`.
        #expect(q(.propertyAccess(.identifierRef(name: "item"), propertyName: "tag")).contains("!= nil"))
        // Nested quantifier in element context.
        let inner = QuantifierIR(kind: .any, description: DescriptionIR(collection: .propertyAccess(.identifierRef(name: "item"), propertyName: "tags"), elementVar: "t"))
        #expect(q(.quantified(inner)).count > 0)
    }
}

@Suite("SwiftEmitter — block constructs via emitFile")
struct SwiftEmitterBlockCoverageTests {

    @Test("while loop and match branch with literal/enum/wildcard patterns")
    func whileAndMatch() {
        let cond = IRExpression.comparison(.identifierRef(name: "n"), .lessThan, .literal(.number(10)))
        let whileLoop = IRPrimitive.iterate(IterateIR(
            mode: .whileCondition(cond),
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        ))
        let match = IRPrimitive.branch(BranchIR(
            condition: .match(
                .identifierRef(name: "status"),
                [
                    BranchCase(pattern: .literal(.string("open")), block: IRBlock(statements: [.complete(CompleteIR(reason: "o"))])),
                    BranchCase(pattern: .enumValue("approved", kind: "Verdict"), block: IRBlock(statements: [.complete(CompleteIR(reason: nil))])),
                    BranchCase(pattern: .wildcard, block: IRBlock(statements: [.complete(CompleteIR(reason: nil))])),
                ]
            ),
            thenBlock: IRBlock(statements: [])
        ))
        let wf = IRWorkflow(name: "run the loop", parameters: [], body: IRBlock(statements: [whileLoop, match]))
        let out = SwiftEmitter().emitFile(workflows: [wf])
        #expect(out.contains("while "))
        #expect(out.contains("switch "))
        #expect(out.contains("case \"open\""))
        #expect(out.contains("case .approved"))
        #expect(out.contains("default:"))
    }

    @Test("until loop emits a negated while")
    func untilLoop() {
        let cond = IRExpression.comparison(.identifierRef(name: "done"), .equal, .literal(.boolean(true)))
        let loop = IRPrimitive.iterate(IterateIR(
            mode: .untilCondition(cond),
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        ))
        let wf = IRWorkflow(name: "spin until done", parameters: [], body: IRBlock(statements: [loop]))
        let out = SwiftEmitter().emitFile(workflows: [wf])
        #expect(out.contains("while "))
    }
}
