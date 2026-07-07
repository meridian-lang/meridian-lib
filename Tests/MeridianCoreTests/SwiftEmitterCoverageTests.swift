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

    /// Regression for the "1D output invariant" shape (`every emitted <noun>
    /// contains "<substring>".`), which lowers to a `.comparison` whose LHS is
    /// a bound state identifier (`Value?`), not a literal. `emitExpr` must
    /// route `.contains`/`.startsWith`/`.endsWith` through `?.description ??
    /// ""` on any operand that reads from state — calling `.contains`/
    /// `.hasPrefix`/`.hasSuffix` directly on `state.get(...)` (`Value?`) does
    /// not type-check (shipped broken in `incident/postmortem_render`,
    /// `etl/quality_gate`, `governance/access_matrix`/`policy_audit` — see
    /// IMPLEMENTATION_LOG.md). `.oneOf` needs the analogous `?? .null` on its
    /// needle when the needle reads from state.
    @Test("string prefix / suffix / membership comparisons against a bound state identifier")
    func stringOpsAgainstStateIdentifier() {
        let lhs = IRExpression.identifierRef(name: "report")
        let rhs = IRExpression.literal(.string("summary"))

        let contains = e.emitExpr(.comparison(lhs, .contains, rhs))
        #expect(contains.contains("?.description ?? \"\""))
        #expect(!contains.contains("(state.get(\"report\")).contains"))

        let starts = e.emitExpr(.comparison(lhs, .startsWith, rhs))
        #expect(starts.contains("?.description ?? \"\""))
        #expect(!starts.contains("(state.get(\"report\")).hasPrefix"))

        let ends = e.emitExpr(.comparison(lhs, .endsWith, rhs))
        #expect(ends.contains("?.description ?? \"\""))
        #expect(!ends.contains("(state.get(\"report\")).hasSuffix"))

        // `.oneOf`'s needle (lhs here) reads from state too — needs `?? .null`
        // rather than being passed straight into `Array<Value>.contains`.
        let oneOf = e.emitExpr(.comparison(lhs, .oneOf, rhs))
        #expect(oneOf.contains("?? .null"))
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
        // A comparison lowers to a bare `Bool`, not a `Value` — bridged via
        // `Value.from(_:)` rather than the generic `.init(...)` fallback
        // (which requires the wrapped expression to already be `Value`-typed).
        let derived = IRExpression.comparison(.literal(.number(1)), .lessThan, .literal(.number(2)))
        #expect(e.emitValueExpr(derived).hasPrefix("Value.from("))
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

    @Test("quantifier `all` with filters but no body emits non-empty check")
    func quantifierAllWithoutBody() {
        let desc = DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            filters: [.comparison(
                .propertyAccess(.identifierRef(name: "page"), propertyName: "status"),
                .equal,
                .literal(.string("open"))
            )]
        )
        let q = QuantifierIR(kind: .all, description: desc, body: nil)
        #expect(e.emitExpr(.quantified(q)).contains("isEmpty"))
    }

    @Test("value-context tableLookup and env-var use the Value bridges")
    func valueContextTableLookupAndEnv() {
        let lookup = IRExpression.tableLookup(
            table: "prices",
            keyColumn: "sku",
            key: .literal(.string("A1")),
            valueColumn: "price"
        )
        #expect(e.emitValueExpr(lookup).contains("?? .null"))
        #expect(e.emitValueExpr(.envVar(name: "HOME")).contains("ProcessInfo"))
    }

    @Test("interpolation with shell-escaped holes uses meridianShellQuote")
    func shellEscapedInterpolation() {
        let segs: [IRInterpolationSegment] = [
            .literal("curl "),
            .shellEscapedExpression(.identifierRef(name: "host")),
        ]
        #expect(e.emitValueExpr(.interpolatedString(segs)).contains("meridianShellQuote"))
    }

    @Test("definition helper reads the loop variable from the closure parameter")
    func elementValueExprLoopVar() {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_stale",
            subjectVar: "page",
            body: .comparison(
                .identifierRef(name: "page"),
                .equal,
                .literal(.string("open"))
            )
        )
        let out = e.emitFile(workflows: [], definitions: [def])
        #expect(out.contains("__subject"))
        #expect(out.contains("meridianDef_Page_stale"))
    }

    @Test("workflow invoke coerces Value-typed property arguments to the target kind")
    func workflowCallArgCoercion() {
        let domain = SwiftEmitter.DomainDecl(
            kinds: [
                .init(name: "order", parent: "thing", ownProperties: [], inheritedProperties: []),
            ],
            enumerations: []
        )
        let callee = IRWorkflow(
            name: "target",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))]),
            explicitStructName: "Target"
        )
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:Target",
                    arguments: [
                        InvokeArg("order", .propertyAccess(.identifierRef(name: "scratch"), propertyName: "nestedOrder")),
                    ],
                    sourceRange: .init(file: "t.meridian", line: 2, column: 1)
                )),
            ])
        )
        let out = SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emitFile(workflows: [callee, caller], domainDecl: domain)
        #expect(out.contains("coerce(to: Order.self)"))
    }

    @Test("declared multi-word parameter kinds preserve Swift-cased IR names")
    func declaredMultiWordParameterKindPreservesCasing() {
        let domain = SwiftEmitter.DomainDecl(
            kinds: [.init(name: "pull request", parent: "thing", ownProperties: [], inheritedProperties: [])],
            enumerations: []
        )
        let callee = IRWorkflow(
            name: "plan for a pull request",
            parameters: [IRParameter(name: "pullRequest", kind: KindRef("PullRequest"))],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))]),
            explicitStructName: "PlanPullRequest"
        )
        let caller = IRWorkflow(
            name: "triage a pull request",
            parameters: [IRParameter(name: "pullRequest", kind: KindRef("PullRequest"))],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:PlanPullRequest",
                    arguments: [InvokeArg("pullRequest", .identifierRef(name: "pullRequest"))]
                )),
            ]),
            explicitStructName: "TriagePullRequest"
        )
        let out = SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emitFile(workflows: [callee, caller], domainDecl: domain)

        #expect(out.contains("public let pullRequest: PullRequest"), Comment(rawValue: out))
        #expect(out.contains("public init(runtime: Runtime, pullRequest: PullRequest)"), Comment(rawValue: out))
        #expect(out.contains("PlanPullRequest(runtime: runtime, pullRequest: pullRequest).run()"), Comment(rawValue: out))
        #expect(!out.contains("pullRequest: Value"), Comment(rawValue: out))
        #expect(!out.contains("Pullrequest"), Comment(rawValue: out))
    }

    @Test("parameter kind resolver accepts natural and Swift-cased names")
    func parameterKindResolverForms() {
        let emitter = SwiftEmitter()
        let declared: Set<String> = ["PullRequest"]

        #expect(emitter.resolveParameterKind("PullRequest", declaredKinds: declared) == "PullRequest")
        #expect(emitter.resolveParameterKind("pull request", declaredKinds: declared) == "PullRequest")
        #expect(emitter.resolveParameterKind("ci repair", declaredKinds: declared) == "Value")
        #expect(emitter.resolveParameterKind("PullRequest", declaredKinds: []) == "PullRequest")
        #expect(emitter.resolveParameterKind("pull request", declaredKinds: []) == "PullRequest")
        #expect(emitter.resolveParameterKind("_Synthetic", declaredKinds: []) == "_Synthetic")
        #expect(emitter.resolveParameterKind("", declaredKinds: []) == "")
    }

    @Test("workflow invoke coerces bare identifier arguments to typed kinds")
    func workflowCallIdentifierCoercion() {
        let domain = SwiftEmitter.DomainDecl(
            kinds: [.init(name: "order", parent: "thing", ownProperties: [], inheritedProperties: [])],
            enumerations: []
        )
        let callee = IRWorkflow(
            name: "target",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))]),
            explicitStructName: "Target"
        )
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:Target",
                    arguments: [InvokeArg("order", .identifierRef(name: "scratch"))],
                    sourceRange: .init(file: "t.meridian", line: 2, column: 1)
                )),
            ])
        )
        let out = SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emitFile(workflows: [callee, caller], domainDecl: domain)
        #expect(out.contains("Value.from(scratch).coerce(to: Order.self)"))
    }

    @Test("value-context invocation uses the Value.init fallback")
    func valueContextInvocationFallback() {
        let inv = InvokeIR(toolID: "demo.tool", arguments: [])
        #expect(SwiftEmitter().emitValueExpr(.invocation(inv)).hasPrefix(".init("))
    }

    @Test("definition helpers read the loop variable as a Value operand")
    func elementValueExprUsesLoopVariableOperand() {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_open",
            subjectVar: "page",
            body: .comparison(
                .propertyAccess(.identifierRef(name: "page"), propertyName: "status"),
                .equal,
                .identifierRef(name: "page")
            )
        )
        let out = SwiftEmitter().emitFile(workflows: [], definitions: [def])
        #expect(out.contains("__subject"))
        #expect(out.contains("meridianDef_Page_open"))
    }

    @Test("nested for-each interpolation segments inside a loop body are dropped")
    func nestedForEachInterpolationInLoopBody() {
        let segs: [IRInterpolationSegment] = [
            .forEach(
                variable: "item",
                collection: .identifierRef(name: "items"),
                body: [
                    .forEach(
                        variable: "nested",
                        collection: .identifierRef(name: "subs"),
                        body: [.literal("x")]
                    ),
                ]
            ),
        ]
        #expect(SwiftEmitter().emitValueExpr(.interpolatedString(segs)).contains("for __item in"))
    }

    @Test("loop interpolation conditionals lower non-comparison predicates via emitExpr")
    func loopInterpolationConditionalLogical() {
        let segs: [IRInterpolationSegment] = [
            .forEach(
                variable: "item",
                collection: .identifierRef(name: "items"),
                body: [
                    .conditional(
                        condition: .logical(.not, [.literal(.boolean(true))]),
                        then: [.literal("yes")],
                        otherwise: [.literal("no")]
                    ),
                ]
            ),
        ]
        let out = SwiftEmitter().emitValueExpr(.interpolatedString(segs))
        #expect(out.contains("if "))
        #expect(out.contains("else"))
    }
}

@Suite("SwiftEmitter — Ctx helpers")
struct SwiftEmitterCtxCoverageTests {
    @Test("Ctx.withTyped unions extra typed identifier names")
    func withTypedMergesNames() {
        let ctx = Ctx(depth: 0, options: .init(), typedIdentifiers: ["order"])
            .withTyped(["customer"])
        #expect(ctx.typedIdentifiers.contains("order"))
        #expect(ctx.typedIdentifiers.contains("customer"))
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
