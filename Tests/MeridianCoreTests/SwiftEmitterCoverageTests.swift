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
    func temporalWindows() throws {
        let lhs = IRExpression.identifierRef(name: "ts")
        let rhs = IRExpression.literal(.duration(.seconds(3600)))
        #expect(try e.emitExpr(.comparison(lhs, .withinPast, rhs)).contains("isWithinPast"))
        #expect(try e.emitExpr(.comparison(lhs, .withinFuture, rhs)).contains("isWithinFuture"))
    }

    @Test("string prefix / suffix / membership comparisons")
    func stringOps() throws {
        let lhs = IRExpression.literal(.string("hello world"))
        let rhs = IRExpression.literal(.string("hello"))
        #expect(try e.emitExpr(.comparison(lhs, .startsWith, rhs)).contains("hasPrefix"))
        #expect(try e.emitExpr(.comparison(lhs, .endsWith, rhs)).contains("hasSuffix"))
        #expect(try e.emitExpr(.comparison(lhs, .oneOf, rhs)).contains("contains"))
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
    func stringOpsAgainstStateIdentifier() throws {
        let lhs = IRExpression.identifierRef(name: "report")
        let rhs = IRExpression.literal(.string("summary"))

        let contains = try e.emitExpr(.comparison(lhs, .contains, rhs))
        #expect(contains.contains("?.description ?? \"\""))
        #expect(!contains.contains("(state.get(\"report\")).contains"))

        let starts = try e.emitExpr(.comparison(lhs, .startsWith, rhs))
        #expect(starts.contains("?.description ?? \"\""))
        #expect(!starts.contains("(state.get(\"report\")).hasPrefix"))

        let ends = try e.emitExpr(.comparison(lhs, .endsWith, rhs))
        #expect(ends.contains("?.description ?? \"\""))
        #expect(!ends.contains("(state.get(\"report\")).hasSuffix"))

        // `.oneOf`'s needle (lhs here) reads from state too — needs `?? .null`
        // rather than being passed straight into `Array<Value>.contains`.
        let oneOf = try e.emitExpr(.comparison(lhs, .oneOf, rhs))
        #expect(oneOf.contains("?? .null"))
    }

    @Test("env var and now in plain context")
    func envAndNow() throws {
        #expect(try e.emitExpr(.envVar(name: "HOME")).contains("ProcessInfo.processInfo.environment"))
        #expect(try e.emitExpr(.nowExpression) == "Date()")
    }

    @Test("inline invocation throws and relation traversal emits")
    func inlineInvokeAndTraversal() throws {
        let inv = InvokeIR(toolID: "some.tool")
        let error = #expect(throws: CompilerError.self) {
            _ = try e.emitExpr(.invocation(inv))
        }
        #expect(try #require(error).diagnostics.contains { $0.code == .invalidIR })
        let trav = IRExpression.relationTraversal(.identifierRef(name: "task"), relationName: "assigned_to", target: nil)
        #expect(try e.emitExpr(trav).contains("assignedTo"))
    }

    @Test("discretion question: missing, interpolated, and default forms")
    func discretionQuestion() throws {
        // No `question` argument → empty string literal.
        let noQ = InvokeIR(toolID: "runtime.discretion.decide")
        #expect(try e.emitExpr(.invocation(noQ)).contains("question: \"\""))

        // Interpolated question → emitted via emitExpr(interpolatedString).
        let interp = InvokeIR(toolID: "runtime.discretion.decide",
                              arguments: [InvokeArg("question", .interpolatedString([.literal("ask "), .expression(.identifierRef(name: "x"))]))])
        #expect(try e.emitExpr(.invocation(interp)).contains("meridianStringify"))

        // Non-literal, non-interpolated question → meridianStringify(value).
        let other = InvokeIR(toolID: "runtime.discretion.decide",
                             arguments: [InvokeArg("question", .identifierRef(name: "topic"))])
        #expect(try e.emitExpr(.invocation(other)).contains("meridianStringify"))
    }

    private func desc() -> DescriptionIR {
        DescriptionIR(collection: .identifierRef(name: "items"), elementVar: "item")
    }

    @Test("value-context description / aggregate / superlative / recordList / derived")
    func valueContextCollections() throws {
        #expect(try e.emitValueExpr(.description(desc())).hasPrefix("Value.list("))
        #expect(try e.emitValueExpr(.aggregate(.count, desc())).contains(".number(Decimal("))
        #expect(try e.emitValueExpr(.aggregate(.list, desc())).hasPrefix("Value.list("))
        let sup = SuperlativeIR(description: desc(), sortPath: "createdAt", ascending: false)
        #expect(try e.emitValueExpr(.superlative(sup)).contains(".first"))
        let rl = IRExpression.recordList(fields: ["a", "b"], rows: [[.literal(.number(1)), .literal(.string("x"))]])
        #expect(try e.emitValueExpr(rl).hasPrefix("Value.list(["))
        // A comparison lowers to a bare `Bool`, not a `Value` — bridged via
        // `Value.from(_:)` rather than the generic `.init(...)` fallback
        // (which requires the wrapped expression to already be `Value`-typed).
        let derived = IRExpression.comparison(.literal(.number(1)), .lessThan, .literal(.number(2)))
        #expect(try e.emitValueExpr(derived).hasPrefix("Value.from("))
        let traversal = IRExpression.relationTraversal(.identifierRef(name: "page"), relationName: "mentions", target: nil)
        #expect(try e.emitValueExpr(traversal).hasPrefix(".init("))
    }

    @Test("plain-context description / aggregate / superlative / recordList")
    func plainContextCollections() throws {
        #expect(try e.emitExpr(.description(desc())).hasPrefix("Value.list("))
        #expect(try e.emitExpr(.aggregate(.count, desc())).hasPrefix("Decimal("))
        #expect(try e.emitExpr(.aggregate(.list, desc())).hasPrefix("Value.list("))
        let sup = SuperlativeIR(description: desc(), sortPath: "createdAt", ascending: true)
        #expect(try e.emitExpr(.superlative(sup)).contains(".first"))
    }

    @Test("quantifier element-context: logical and / or / not, nested, default")
    func quantifierElementContext() throws {
        func q(_ body: IRExpression) throws -> String {
            try e.emitExpr(.quantified(QuantifierIR(kind: .all, description: desc(), body: body)))
        }
        let p1 = IRExpression.comparison(.propertyAccess(.identifierRef(name: "item"), propertyName: "done"), .equal, .literal(.boolean(true)))
        let p2 = IRExpression.comparison(.propertyAccess(.identifierRef(name: "item"), propertyName: "open"), .equal, .literal(.boolean(false)))
        #expect(try q(.logical(.and, [p1, p2])).contains("&&"))
        #expect(try q(.logical(.or, [p1, p2])).contains("||"))
        #expect(try q(.logical(.not, [p1])).hasPrefix("("))
        let emptyLogicalError = #expect(throws: CompilerError.self) {
            _ = try q(.logical(.and, []))
        }
        #expect(try #require(emptyLogicalError).diagnostics.contains { $0.code == .invalidIR })
        // Default element branch (a non-comparison, non-logical leaf) → `!= nil`.
        #expect(try q(.propertyAccess(.identifierRef(name: "item"), propertyName: "tag")).contains("!= nil"))
        // Nested quantifier in element context.
        let inner = QuantifierIR(kind: .any, description: DescriptionIR(collection: .propertyAccess(.identifierRef(name: "item"), propertyName: "tags"), elementVar: "t"))
        #expect(try q(.quantified(inner)).count > 0)
    }

    @Test("quantifier `all` with filters but no body emits non-empty check")
    func quantifierAllWithoutBody() throws {
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
        #expect(try e.emitExpr(.quantified(q)).contains("isEmpty"))
    }

    @Test("value-context tableLookup and env-var use the Value bridges")
    func valueContextTableLookupAndEnv() throws {
        let lookup = IRExpression.tableLookup(
            table: "prices",
            keyColumn: "sku",
            key: .literal(.string("A1")),
            valueColumn: "price"
        )
        #expect(try e.emitValueExpr(lookup).contains("?? .null"))
        #expect(try e.emitValueExpr(.envVar(name: "HOME")).contains("ProcessInfo"))
    }

    @Test("interpolation with shell-escaped holes uses meridianShellQuote")
    func shellEscapedInterpolation() throws {
        let segs: [IRInterpolationSegment] = [
            .literal("curl "),
            .shellEscapedExpression(.identifierRef(name: "host")),
        ]
        #expect(try e.emitValueExpr(.interpolatedString(segs)).contains("meridianShellQuote"))
    }

    @Test("definition helper reads the loop variable from the closure parameter")
    func elementValueExprLoopVar() throws {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_stale",
            subjectVar: "page",
            body: .comparison(
                .identifierRef(name: "page"),
                .equal,
                .literal(.string("open"))
            )
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("__subject"))
        #expect(out.contains("meridianDef_Page_stale"))
    }

    @Test("definition helper element-context comparisons cover withinFuture/withinDuration/matchesPattern/startsWith/endsWith/oneOf")
    func elementExprRemainingComparisonOps() throws {
        func emitted(_ op: ComparisonOp, _ rhs: IRExpression) throws -> String {
            let def = LoweredDefinition(
                functionName: "meridianDef_Page_check",
                subjectVar: "page",
                body: .comparison(.identifierRef(name: "page"), op, rhs)
            )
            return try e.emit(workflows: [], definitions: [def]).combined
        }
        #expect(try emitted(.withinFuture, .literal(.duration(.seconds(60)))).contains("MeridianComparison.isWithinFuture"))
        #expect(try emitted(.withinDuration, .literal(.duration(.seconds(60)))).contains("MeridianComparison.isWithin("))
        #expect(try emitted(.matchesPattern, .literal(.string("^a.*"))).contains("meridianRegexMatches"))
        #expect(try emitted(.startsWith, .literal(.string("a"))).contains("hasPrefix"))
        #expect(try emitted(.endsWith, .literal(.string("a"))).contains("hasSuffix"))
        #expect(try emitted(.oneOf, .literal(.string("a"))).contains(".contains("))
    }

    @Test("definition helper element-context logical operators cover empty and/or/not operand lists")
    func elementExprEmptyLogicalOperands() throws {
        func emitted(_ op: LogicalOp) throws -> String {
            let def = LoweredDefinition(
                functionName: "meridianDef_Page_check",
                subjectVar: "page",
                body: .logical(op, [])
            )
            return try e.emit(workflows: [], definitions: [def]).combined
        }
        let andOut = try emitted(.and)
        let orOut = try emitted(.or)
        let notOut = try emitted(.not)
        #expect(andOut.contains(" true"), Comment(rawValue: andOut))
        #expect(orOut.contains(" false"), Comment(rawValue: orOut))
        #expect(notOut.contains("!(true)"), Comment(rawValue: notOut))
    }

    @Test("a nested quantifier inside a definition's element context reuses emitElementExpr recursively")
    func elementExprNestedQuantifier() throws {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_check",
            subjectVar: "page",
            body: .quantified(QuantifierIR(
                kind: .all,
                description: DescriptionIR(
                    collection: .propertyAccess(.identifierRef(name: "page"), propertyName: "tags"),
                    elementVar: "tag"
                ),
                body: .comparison(.identifierRef(name: "tag"), .equal, .literal(.string("urgent")))
            ))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("meridianDef_Page_check"), Comment(rawValue: out))
        #expect(out.contains(".allSatisfy") || out.contains(".contains"), Comment(rawValue: out))
    }

    @Test("emitElementOperand recurses through a nested property-access base that isn't itself a bound identifier")
    func elementOperandNestedPropertyAccess() throws {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_check",
            subjectVar: "page",
            body: .comparison(
                .propertyAccess(.propertyAccess(.identifierRef(name: "page"), propertyName: "owner"), propertyName: "name"),
                .equal,
                .literal(.string("x"))
            )
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("__subject.member(\"owner\")?.member(\"name\")"), Comment(rawValue: out))
    }

    @Test("emitNonOptionalElementOperand falls back for a definition-predicate subject unbound in env, and for a non-identifier default")
    func nonOptionalElementOperandUnboundAndDefault() throws {
        let unboundOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_check",
            subjectVar: "page",
            body: .definitionPredicate(functionName: "meridianDef_Other_thing", subject: .identifierRef(name: "other"))
        ))
        #expect(unboundOut.contains("meridianDef_Other_thing(state.get(\"other\"))"), Comment(rawValue: unboundOut))

        let literalSubject = LoweredDefinition(
            functionName: "meridianDef_Page_check2",
            subjectVar: "page",
            body: .definitionPredicate(functionName: "meridianDef_Other_thing", subject: .literal(.boolean(true)))
        )
        let literalOut = try e.emit(workflows: [], definitions: [literalSubject]).combined
        #expect(literalOut.contains("meridianDef_Other_thing(true)"), Comment(rawValue: literalOut))
    }

    /// Each of these bodies references an identifier outside `[subjectVar]`
    /// (`other`/`tags`), so `definitionRequiresState` is true and the def has
    /// no standalone helper — it only lowers via `emitDefinitionPredicate`'s
    /// inline path (`emitElementExpr(def.body, env: [subjectVar: …])`) at an
    /// actual `.definitionPredicate` call site inside a workflow.
    private func inlinedElementBody(_ def: LoweredDefinition) throws -> String {
        let workflow = IRWorkflow(
            name: "check \(def.subjectVar)",
            parameters: [IRParameter(name: def.subjectVar, kind: KindRef("Value"))],
            body: IRBlock(statements: [
                .assert(AssertIR(condition: .definitionPredicate(
                    functionName: def.functionName, subject: .identifierRef(name: def.subjectVar)
                ))),
            ])
        )
        return try e.emit(workflows: [workflow], definitions: [def]).combined
    }

    @Test("emitElementValueExpr covers an unbound operand, an aggregate list, and a nested comparison RHS")
    func elementValueExprUnboundAggregateAndNestedComparison() throws {
        let unboundOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_unbound",
            subjectVar: "page",
            body: .comparison(.identifierRef(name: "page"), .equal, .identifierRef(name: "other"))
        ))
        #expect(unboundOut.contains("state.get(\"other\") ?? .null"), Comment(rawValue: unboundOut))

        let aggregateOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_aggregate",
            subjectVar: "page",
            body: .comparison(
                .identifierRef(name: "page"),
                .equal,
                .aggregate(.list, DescriptionIR(collection: .identifierRef(name: "tags"), elementVar: "tag"))
            )
        ))
        #expect(aggregateOut.contains("Value.list("), Comment(rawValue: aggregateOut))

        let nestedOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_nested",
            subjectVar: "page",
            body: .comparison(
                .identifierRef(name: "page"),
                .equal,
                .comparison(.identifierRef(name: "other"), .equal, .literal(.string("x")))
            )
        ))
        #expect(nestedOut.contains("Value.from("), Comment(rawValue: nestedOut))
    }

    @Test("workflow invoke coerces Value-typed property arguments to the target kind")
    func workflowCallArgCoercion() throws {
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
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [callee, caller], domainDecl: domain).combined
        #expect(out.contains("coerce(to: Order.self)"))
    }

    @Test("declared multi-word parameter kinds preserve Swift-cased IR names")
    func declaredMultiWordParameterKindPreservesCasing() throws {
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
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [callee, caller], domainDecl: domain).combined

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
    func workflowCallIdentifierCoercion() throws {
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
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [callee, caller], domainDecl: domain).combined
        #expect(out.contains("Value.from(scratch).coerce(to: Order.self)"))
    }

    @Test("workflow invoke passes non-identifier arguments through direct emission")
    func workflowCallLiteralArgumentEmission() throws {
        let callee = IRWorkflow(
            name: "target",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [.complete(CompleteIR())]),
            explicitStructName: "Target"
        )
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:Target",
                    arguments: [InvokeArg("order", .literal(.string("manual")))]
                )),
            ])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [callee, caller]).combined
        #expect(out.contains("order: \"manual\""), Comment(rawValue: out))
    }

    @Test("workflow invoke with a result binding assigns `let <name> =` instead of discarding")
    func workflowCallWithResultBinding() throws {
        let callee = IRWorkflow(
            name: "target",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR())]),
            explicitStructName: "Target"
        )
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(toolID: "workflow:Target", resultBinding: "outcome")),
            ])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [callee, caller]).combined
        #expect(out.contains("let outcome = try await Target(runtime: runtime).run()"), Comment(rawValue: out))
    }

    @Test("a property-access workflow-call argument with no known target kind falls back to bare emission")
    func workflowCallArgPropertyAccessWithoutTargetKind() throws {
        // "Unknown" isn't a declared workflow, so `ctx.workflowParamTypes["Unknown"]`
        // is empty and `targetKind` resolves to nil for every argument key —
        // `emitWorkflowCallArg`'s `.propertyAccess` branch must fall back to
        // the bare coerced expression instead of wrapping in `.coerce(to:)`.
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:Unknown",
                    arguments: [InvokeArg("order", .propertyAccess(.identifierRef(name: "scratch"), propertyName: "nestedOrder"))]
                )),
            ])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [caller]).combined
        #expect(out.contains("order: state.get(\"scratch.nestedOrder\") ?? .null"), Comment(rawValue: out))
        #expect(!out.contains("coerce(to:"), Comment(rawValue: out))
    }

    @Test("an identifier workflow-call argument with no known target kind falls through the nil-target guard")
    func workflowCallArgIdentifierWithoutTargetKind() throws {
        let caller = IRWorkflow(
            name: "caller",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(
                    toolID: "workflow:Unknown",
                    arguments: [InvokeArg("order", .identifierRef(name: "scratch"))]
                )),
            ])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [caller]).combined
        #expect(out.contains("order: scratch"), Comment(rawValue: out))
        #expect(!out.contains("coerce(to:"), Comment(rawValue: out))
    }

    @Test("emitTruthValueExpr covers logical and/or/not over indeterminate operands, and the plain-comparison default arm")
    func truthValueExprLogicalAndDefaultArms() throws {
        let statistical = IRExpression.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .runs
        ))

        func assertOut(_ condition: IRExpression) throws -> String {
            let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: []))
            return e.emitAssert(
                AssertIR(condition: condition),
                ctx: Ctx(depth: 0, options: .init()),
                workflow: wf
            ).toString(separator: "\n")
        }

        let andOut = try assertOut(.logical(.and, [statistical, statistical]))
        #expect(andOut.contains(").and("), Comment(rawValue: andOut))

        let orOut = try assertOut(.logical(.or, [statistical, statistical]))
        #expect(orOut.contains(").or("), Comment(rawValue: orOut))

        let notOut = try assertOut(.logical(.not, [statistical]))
        #expect(notOut.contains(").not()"), Comment(rawValue: notOut))

        // A bare comparison wrapping an indeterminate operand isn't itself one
        // of emitTruthValueExpr's three special-cased kinds, so it falls to
        // the `default: TruthValue.from(emitExprUnchecked(expr))` arm.
        let comparisonOut = try assertOut(.comparison(.identifierRef(name: "x"), .equal, statistical))
        #expect(comparisonOut.contains("TruthValue.from(MeridianComparison.eq("), Comment(rawValue: comparisonOut))
    }

    @Test("emitTruthValueExpr covers empty nested logical fallbacks under an indeterminate outer logical")
    func truthValueExprEmptyNestedLogicalFallbacks() throws {
        let statistical = IRExpression.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .runs
        ))

        func assertOut(_ condition: IRExpression) throws -> String {
            let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: []))
            return e.emitAssert(
                AssertIR(condition: condition),
                ctx: Ctx(depth: 0, options: .init()),
                workflow: wf
            ).toString(separator: "\n")
        }

        let andOut = try assertOut(.logical(.and, [statistical, .logical(.and, [])]))
        #expect(andOut.contains(".and(.true)"), Comment(rawValue: andOut))

        let orOut = try assertOut(.logical(.or, [statistical, .logical(.or, [])]))
        #expect(orOut.contains(".or(.false)"), Comment(rawValue: orOut))

        let notOut = try assertOut(.logical(.and, [statistical, .logical(.not, [])]))
        #expect(notOut.contains("(.true).not()"), Comment(rawValue: notOut))
    }

    @Test("a bare assert with an indeterminate condition routes through emitTruthValueExpr, not emitExprUnchecked")
    func bareAssertIndeterminateCondition() throws {
        let statistical = IRExpression.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .runs
        ))
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: statistical)),
        ]))
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains("try await runtime.assert(try await runtime.evaluateTrace("), Comment(rawValue: out))
    }

    @Test("emitCollectionArray covers a nested aggregate(.list) collection and an identifierRef bound in env")
    func collectionArrayNestedAggregateAndBoundIdentifier() throws {
        // `x` itself (bound to `__subject` in env) used directly as a
        // collection → the `.identifierRef(name) where env[name] != nil` arm.
        let innermost = DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "y")
        // A description whose *collection* is itself `.aggregate(.list, …)`
        // → the `.aggregate(.list, let d)` arm in `emitCollectionArray`.
        let middle = DescriptionIR(collection: .aggregate(.list, innermost), elementVar: "z")
        let def = LoweredDefinition(
            functionName: "meridianDef_X_check",
            subjectVar: "x",
            body: .comparison(.literal(.number(0)), .equal, .aggregate(.count, middle))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("meridianDef_X_check"), Comment(rawValue: out))
        #expect(out.contains("__subject"), Comment(rawValue: out))
    }

    @Test("emitCollectionArray covers a propertyAccess(identifierRef) collection bound in env")
    func collectionArrayBoundPropertyAccess() throws {
        // `x.items` where `x` is bound in env → the
        // `.propertyAccess(.identifierRef(name), _) where env[name] != nil` arm.
        let items = DescriptionIR(collection: .propertyAccess(.identifierRef(name: "x"), propertyName: "items"), elementVar: "y")
        let def = LoweredDefinition(
            functionName: "meridianDef_X_hasItems",
            subjectVar: "x",
            body: .comparison(.literal(.number(0)), .equal, .aggregate(.count, items))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains(".member(\"items\")"), Comment(rawValue: out))
    }

    @Test("emitDescriptionList's filterEnv merge covers a nested description whose elementVar collides with the outer subject")
    func descriptionListFilterEnvCollidesWithOuterSubject() throws {
        // The description's own elementVar ("x") is the same name as the
        // outer subject bound in env, so `env.merging([ev: param]) { _, new
        // in new }` must resolve the collision (picking the fresh param).
        let shadowed = DescriptionIR(
            collection: .identifierRef(name: "x"),
            elementVar: "x",
            filters: [.comparison(.identifierRef(name: "x"), .equal, .literal(.string("ok")))]
        )
        let def = LoweredDefinition(
            functionName: "meridianDef_X_hasOk",
            subjectVar: "x",
            body: .comparison(.literal(.number(0)), .equal, .aggregate(.count, shadowed))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains(".filter { __e1 in"), Comment(rawValue: out))
    }

    @Test("definitionRequiresAsyncTrace covers relationTraversal with a trace-bearing target, and with no target")
    func definitionRequiresAsyncTraceRelationTraversal() throws {
        let temporal = IRExpression.traceTemporal(TraceTemporalIR(kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .succeeded))))
        // Base isn't trace-bearing but `target` is → the `target.map(...)` arm must return true.
        let withTraceTarget = IRExpression.relationTraversal(.identifierRef(name: "x"), relationName: "owner", target: temporal)
        #expect(e.definitionRequiresAsyncTrace(withTraceTarget))
        // No target at all → `target.map(...) ?? false` must fall back to false.
        let noTarget = IRExpression.relationTraversal(.identifierRef(name: "x"), relationName: "owner", target: nil)
        #expect(!e.definitionRequiresAsyncTrace(noTarget))
        // Trace-bearing base, nil target → the base-side `||` operand is what wins.
        let traceBase = IRExpression.relationTraversal(temporal, relationName: "owner", target: nil)
        #expect(e.definitionRequiresAsyncTrace(traceBase))
    }

    @Test("emitConstants covers typeOfLiteral/emitLiteral for boolean/date/dateTime/enumValue entries")
    func constantsBooleanDateDateTimeEnum() throws {
        let now = Date(timeIntervalSince1970: 0)
        let decl = SwiftEmitter.ConstantsDecl(entries: [
            .init("is active", .boolean(true)),
            .init("launch date", .date(now)),
            .init("last seen", .dateTime(now)),
            .init("stage", .enumValue("open", kind: "DealStage")),
        ])
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let out = try e.emit(workflows: [wf], constantsDecl: decl).combined
        #expect(out.contains("let isActive: Bool = true"), Comment(rawValue: out))
        #expect(out.contains("let launchDate: Date = Date(timeIntervalSince1970:"), Comment(rawValue: out))
        #expect(out.contains("let lastSeen: Date = Date(timeIntervalSince1970:"), Comment(rawValue: out))
        #expect(out.contains("let stage: DealStage = DealStage.open"), Comment(rawValue: out))
    }

    @Test("emitValueExpr covers emitValueLiteral for money/date/dateTime literal kinds")
    func valueLiteralMoneyDateDateTime() throws {
        let now = Date(timeIntervalSince1970: 0)
        #expect(try e.emitValueExpr(.literal(.money(5000, currency: "USD"))).contains("Money(amount:"))
        #expect(try e.emitValueExpr(.literal(.date(now))).contains(".date(Date(timeIntervalSince1970:"))
        #expect(try e.emitValueExpr(.literal(.dateTime(now))).contains(".date(Date(timeIntervalSince1970:"))
    }

    @Test("emitLoopComparison covers every non-relational ComparisonOp inside a for-each string-interpolation conditional")
    func loopComparisonRemainingOps() throws {
        let loopVar = "item"
        func cmp(_ op: ComparisonOp, _ rhs: IRExpression = .literal(.string("x"))) -> IRExpression {
            .comparison(.propertyAccess(.identifierRef(name: loopVar), propertyName: "tag"), op, rhs)
        }
        func branch(_ op: ComparisonOp, _ rhs: IRExpression = .literal(.string("x"))) -> IRInterpolationSegment {
            .conditional(condition: cmp(op, rhs), then: [.literal("A")], otherwise: [.literal("B")])
        }
        let body: [IRInterpolationSegment] = [
            branch(.withinDuration, .literal(.duration(.seconds(60)))),
            branch(.withinPast, .literal(.duration(.seconds(60)))),
            branch(.withinFuture, .literal(.duration(.seconds(60)))),
            branch(.matchesPattern, .literal(.string("^a"))),
            branch(.isEmpty),
            branch(.isNotEmpty),
            branch(.identifies, .literal(.string("id"))),
            branch(.contains),
            branch(.startsWith),
            branch(.endsWith),
            branch(.oneOf),
        ]
        let seg = IRInterpolationSegment.forEach(variable: loopVar, collection: .identifierRef(name: "items"), body: body)
        let out = try e.emitExpr(.interpolatedString([seg]))
        #expect(out.contains("MeridianComparison.isWithin("), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.isWithinPast("), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.isWithinFuture("), Comment(rawValue: out))
        #expect(out.contains("meridianRegexMatches("), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.isEmpty("), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.isNotEmpty("), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.identifies("), Comment(rawValue: out))
        #expect(out.contains(".description).contains("), Comment(rawValue: out))
        #expect(out.contains(".description).hasPrefix("), Comment(rawValue: out))
        #expect(out.contains(".description).hasSuffix("), Comment(rawValue: out))
        // `.contains` and `.oneOf` both render as `.contains(...)`, just with
        // the needle/haystack swapped — two occurrences confirms both fired.
        #expect(out.components(separatedBy: ").contains(").count - 1 >= 2, Comment(rawValue: out))
    }

    @Test("emitTraceTemporalQuery covers countInWindow's .atMost/.exactly comparators, a subjectKeyExpr, and a payload predicate")
    func traceTemporalCountInWindowAtMostExactlySubjectKeyPayload() throws {
        let payload = IRExpression.comparison(.identifierRef(name: "env"), .equal, .literal(.string("prod")))
        let atMostPattern = EventPatternIR(subject: .step("deploy"), outcome: .failed, payloadPredicate: payload)
        let atMost = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .countInWindow(atMostPattern, comparator: .atMost(3), duration: .seconds(3600)),
            subjectKeyExpr: .identifierRef(name: "orderId")
        ))
        let exactly = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .countInWindow(EventPatternIR(subject: .step("deploy"), outcome: .failed), comparator: .exactly(2), duration: .seconds(60))
        ))
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: atMost)),
            .assert(AssertIR(condition: exactly)),
        ]))
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains(".atMost(3)"), Comment(rawValue: out))
        #expect(out.contains(".exactly(2)"), Comment(rawValue: out))
        #expect(out.contains("subjectKey: meridianStringify("), Comment(rawValue: out))
        #expect(out.contains("payloadContains: [\"env\":"), Comment(rawValue: out))
    }

    @Test("emitTraceStatisticalQuery covers .acrossAllRuns scope, a .named subject, and a subjectKeyExpr")
    func traceStatisticalAcrossAllRunsNamedSubjectKey() throws {
        let stat = IRExpression.traceStatistical(TraceStatisticalIR(
            scope: .acrossAllRuns,
            pattern: TraceStatisticalPatternIR(subject: .named("checkout")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .runs,
            subjectKeyExpr: .identifierRef(name: "tenantId")
        ))
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [.assert(AssertIR(condition: stat))]))
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains("scope: .acrossAllRuns"), Comment(rawValue: out))
        #expect(out.contains(".named(\"checkout\")"), Comment(rawValue: out))
        #expect(out.contains("subjectKey: meridianStringify("), Comment(rawValue: out))
    }

    @Test("emitTraceEventPattern covers a named temporal event pattern subject")
    func traceTemporalNamedEventPatternSubject() throws {
        let temporal = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .ever(EventPatternIR(subject: .named("checkout"), outcome: .succeeded))
        ))
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: temporal)),
        ]))
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains(".named(\"checkout\")"), Comment(rawValue: out))
    }

    @Test("stableStepPath falls back to progressLabel for every IRPrimitive case that is never checkpoint-guarded")
    func stableStepPathFallbackForNonCheckpointedPrimitives() throws {
        // Only .invoke/.emit/.wait/.assert/.commit ever route through
        // `checkpointLabel`/`stableStepPath` in normal emission
        // (`shouldCheckpointAfter`) — the other 8 cases are exercised here
        // directly, since the switch must still stay exhaustive.
        let primitives: [IRPrimitive] = [
            .bind(BindIR(name: "x", expression: .literal(.number(1)))),
            .branch(BranchIR(condition: .predicate(.literal(.boolean(true))), thenBlock: IRBlock(statements: []))),
            .iterate(IterateIR(mode: .overCollection(parameter: "x", kind: KindRef("Thing"), collection: .identifierRef(name: "xs")), body: IRBlock(statements: []))),
            .recover(RecoverIR(pattern: .anyError, handler: IRBlock(statements: []), attachedTo: IRBlock(statements: []))),
            .simultaneously(SimultaneouslyIR(branches: [IRBlock(statements: [])])),
            .aiJudgment(AIJudgmentIR(text: "decide")),
            .aiAutonomy(AIAutonomyIR(text: "repair")),
            .complete(CompleteIR()),
        ]
        for p in primitives {
            let out = e.stableStepPath(for: p, fallbackPath: "wf.0")
            #expect(out.hasPrefix("progress:wf.0:L"), Comment(rawValue: out))
        }
    }

    @Test("a nested quantifier whose own elementVar collides with the outer subject exercises the element-closure's merge collision resolver")
    func nestedQuantifierElementVarCollidesWithOuterSubject() throws {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_check2",
            subjectVar: "page",
            body: .quantified(QuantifierIR(
                kind: .all,
                description: DescriptionIR(
                    collection: .propertyAccess(.identifierRef(name: "page"), propertyName: "tags"),
                    elementVar: "page"
                ),
                body: .comparison(.identifierRef(name: "page"), .equal, .literal(.string("urgent")))
            ))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains(".allSatisfy"), Comment(rawValue: out))
    }

    @Test("emitExprUnchecked's env-blind .logical(.not, []) and .eventPattern arms are reachable through an inlined definition operand, which bypasses IRValidator")
    func exprUncheckedLogicalNotEmptyAndEventPatternViaDefinition() throws {
        // `LoweredDefinition` bodies are never walked by `IRValidator` (only
        // `IRWorkflow`s and `emitExpr`/`emitValueExpr`'s own argument are), so
        // a comparison operand here can be a shape the validator would
        // otherwise reject — the operand still reaches `emitExprUnchecked`
        // (via `emitElementExpr`'s comparison case, which shells out to it
        // for the non-relational ops), exercising its env-blind `.logical`/
        // `.eventPattern` arms that no validated workflow can ever produce.
        let notEmptyOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_checkNot",
            subjectVar: "page",
            body: .comparison(.identifierRef(name: "page"), .withinPast, .logical(.not, []))
        ))
        #expect(notEmptyOut.contains("MeridianComparison.isWithinPast(") && notEmptyOut.contains("!(true)"), Comment(rawValue: notEmptyOut))

        let eventPatternOut = try inlinedElementBody(LoweredDefinition(
            functionName: "meridianDef_Page_checkEvent",
            subjectVar: "page",
            body: .comparison(.identifierRef(name: "page"), .withinPast, .eventPattern(EventPatternIR(subject: .step("x"), outcome: .succeeded)))
        ))
        #expect(eventPatternOut.contains("MeridianComparison.isWithinPast(") && eventPatternOut.contains(", false)"), Comment(rawValue: eventPatternOut))
    }

    @Test("emitElementValueExpr covers the .description case directly (not wrapped in an .aggregate)")
    func elementValueExprDirectDescription() throws {
        let listed = DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "y")
        let def = LoweredDefinition(
            functionName: "meridianDef_X_hasList",
            subjectVar: "x",
            body: .comparison(.identifierRef(name: "x"), .equal, .description(listed))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("Value.list("), Comment(rawValue: out))
    }

    @Test("a nested quantifier whose collection is itself a nested noun-phrase description exercises emitQuantifier's own .description/.aggregate(.list) branch")
    func quantifierCollectionIsNestedDescription() throws {
        let inner = DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "y")
        let outerColl = DescriptionIR(collection: .description(inner), elementVar: "z")
        let def = LoweredDefinition(
            functionName: "meridianDef_X_any",
            subjectVar: "x",
            body: .quantified(QuantifierIR(kind: .any, description: outerColl))
        )
        let out = try e.emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("meridianDef_X_any"), Comment(rawValue: out))
        // The doc comment on this switch warns that taking the `default:`
        // branch here for a `.description`/`.aggregate(.list, _)` collection
        // would double-wrap it as `Value.list(...)?.asList` — confirm that
        // invalid shape never appears.
        #expect(!out.contains("Value.list(") || !out.contains(")?.asList"), Comment(rawValue: out))
    }

    @Test("emitNonOptionalComparisonOperand's default arm fires for a top-level (env-blind) definitionPredicate with a non-identifier subject")
    func nonOptionalComparisonOperandDefaultArm() throws {
        let helper = LoweredDefinition(
            functionName: "meridianDef_Other_isTrue",
            subjectVar: "s",
            body: .comparison(.identifierRef(name: "s"), .equal, .literal(.boolean(true)))
        )
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: .definitionPredicate(functionName: "meridianDef_Other_isTrue", subject: .literal(.boolean(true))))),
        ]))
        let out = try e.emit(workflows: [wf], definitions: [helper]).combined
        #expect(out.contains("meridianDef_Other_isTrue(.boolean(true))"), Comment(rawValue: out))
    }

    @Test("emitRuntimeTraceConfiguration covers the .full tool capture policy case")
    func runtimeTraceConfigurationFullPolicy() throws {
        let wf = IRWorkflow(
            name: "inspect",
            parameters: [],
            body: IRBlock(statements: []),
            runtimeTraceConfiguration: RuntimeTraceConfiguration(
                store: .memory,
                trace: TraceConfiguration(payloadLimit: 8192, profile: .production, storeFailurePolicy: .auto),
                skillIdentity: TraceSkillIdentity(name: "trace me", versionHash: "abc123"),
                toolCapturePolicies: ["validateOrder": .full]
            )
        )
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains("\"validateOrder\": .full"), Comment(rawValue: out))
    }

    @Test("needsValueComparison covers .superlative and .description operands directly (not just .aggregate)")
    func needsValueComparisonSuperlativeAndDescription() throws {
        let superlative = IRExpression.superlative(SuperlativeIR(
            description: DescriptionIR(collection: .identifierRef(name: "services"), elementVar: "s"),
            sortPath: "score",
            ascending: false
        ))
        let description = IRExpression.description(DescriptionIR(collection: .identifierRef(name: "services"), elementVar: "s"))
        let wf = IRWorkflow(name: "check", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: .comparison(superlative, .equal, .literal(.string("x"))))),
            .assert(AssertIR(condition: .comparison(description, .equal, .literal(.string("y"))))),
        ]))
        let out = try e.emit(workflows: [wf]).combined
        #expect(out.contains("MeridianComparison.eq("), Comment(rawValue: out))
    }

    @Test("definitionRequiresState covers relationTraversal/quantified/superlative/always-stateful branches directly")
    func definitionRequiresStateRemainingBranches() throws {
        let bound: Set<String> = ["x"]

        // .relationTraversal: base bound + no target → false.
        #expect(!e.definitionRequiresState(.relationTraversal(.identifierRef(name: "x"), relationName: "owner", target: nil), bound: bound))
        // .relationTraversal: base bound + a stateful target → true (the `target.map` arm).
        #expect(e.definitionRequiresState(.relationTraversal(.identifierRef(name: "x"), relationName: "owner", target: .identifierRef(name: "unbound")), bound: bound))
        // .relationTraversal: an unbound base short-circuits the `||` before the target is even consulted.
        #expect(e.definitionRequiresState(.relationTraversal(.identifierRef(name: "unbound"), relationName: "owner", target: nil), bound: bound))

        // .quantified: a filter that references an unbound identifier.
        let quantifiedWithStatefulFilter = IRExpression.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "x"),
                elementVar: "e",
                filters: [.identifierRef(name: "unbound")]
            )
        ))
        #expect(e.definitionRequiresState(quantifiedWithStatefulFilter, bound: bound))
        // .quantified: filters are clean, but the body references an unbound identifier.
        let quantifiedWithStatefulBody = IRExpression.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "e"),
            body: .identifierRef(name: "unbound")
        ))
        #expect(e.definitionRequiresState(quantifiedWithStatefulBody, bound: bound))
        // .quantified: everything bound → false.
        let quantifiedAllBound = IRExpression.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "e", filters: [.identifierRef(name: "e")]),
            body: .identifierRef(name: "e")
        ))
        #expect(!e.definitionRequiresState(quantifiedAllBound, bound: bound))

        // .superlative: collection bound, a filter that references an unbound identifier.
        let superlativeWithStatefulFilter = IRExpression.superlative(SuperlativeIR(
            description: DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "e", filters: [.identifierRef(name: "unbound")]),
            sortPath: "score",
            ascending: true
        ))
        #expect(e.definitionRequiresState(superlativeWithStatefulFilter, bound: bound))
        // .superlative: the collection itself references state → early true.
        let superlativeWithStatefulCollection = IRExpression.superlative(SuperlativeIR(
            description: DescriptionIR(collection: .identifierRef(name: "unbound"), elementVar: "e", filters: [.identifierRef(name: "e")]),
            sortPath: "score",
            ascending: true
        ))
        #expect(e.definitionRequiresState(superlativeWithStatefulCollection, bound: bound))
        // .superlative: collection and filters all bound → false.
        let superlativeAllBound = IRExpression.superlative(SuperlativeIR(
            description: DescriptionIR(collection: .identifierRef(name: "x"), elementVar: "e", filters: [.identifierRef(name: "e")]),
            sortPath: "score",
            ascending: true
        ))
        #expect(!e.definitionRequiresState(superlativeAllBound, bound: bound))

        // The always-stateful leaf kinds.
        #expect(e.definitionRequiresState(.envVar(name: "HOME"), bound: bound))
        #expect(e.definitionRequiresState(.nowExpression, bound: bound))
        #expect(e.definitionRequiresState(.eventPattern(EventPatternIR(subject: .step("x"), outcome: .succeeded)), bound: bound))
    }

    @Test("literal relational comparisons cover the remaining compOp spellings")
    func literalRelationalComparisonOperators() throws {
        #expect(try e.emitExpr(.comparison(.literal(.number(1)), .equal, .literal(.number(1)))).contains(" == "))
        #expect(try e.emitExpr(.comparison(.literal(.number(1)), .notEqual, .literal(.number(2)))).contains(" != "))
        #expect(try e.emitExpr(.comparison(.literal(.number(1)), .lessOrEqual, .literal(.number(2)))).contains(" <= "))
    }

    @Test("value-context invocation throws instead of using Value.init fallback")
    func valueContextInvocationFallback() throws {
        let inv = InvokeIR(toolID: "demo.tool", arguments: [])
        let exprError = #expect(throws: CompilerError.self) {
            _ = try SwiftEmitter().emitExpr(.invocation(inv))
        }
        #expect(try #require(exprError).diagnostics.contains { $0.code == .invalidIR })

        let error = #expect(throws: CompilerError.self) {
            _ = try SwiftEmitter().emitValueExpr(.invocation(inv))
        }
        #expect(try #require(error).diagnostics.contains { $0.code == .invalidIR })
    }

    @Test("unchecked internal emitters still render inline invocation syntax")
    func uncheckedInlineInvocationEmission() {
        let inline = InvokeIR(
            toolID: "demo.tool",
            arguments: [InvokeArg("value", .literal(.string("x")))]
        )
        let ctx = Ctx(depth: 0, options: .init())

        let bind = e.emitBind(
            BindIR(name: "result", expression: .invocation(inline)),
            ctx: ctx
        ).toString(separator: "\n")
        #expect(bind.contains("runtime.invoke(tool: \"demo.tool\""), Comment(rawValue: bind))

        let invoke = e.emitInvoke(
            InvokeIR(toolID: "outer.tool", arguments: [InvokeArg("payload", .invocation(inline))]),
            ctx: ctx
        ).toString(separator: "\n")
        #expect(invoke.contains("\"payload\": try await runtime.invoke"), Comment(rawValue: invoke))
    }

    @Test("definition helpers read the loop variable as a Value operand")
    func elementValueExprUsesLoopVariableOperand() throws {
        let def = LoweredDefinition(
            functionName: "meridianDef_Page_open",
            subjectVar: "page",
            body: .comparison(
                .propertyAccess(.identifierRef(name: "page"), propertyName: "status"),
                .equal,
                .identifierRef(name: "page")
            )
        )
        let out = try SwiftEmitter().emit(workflows: [], definitions: [def]).combined
        #expect(out.contains("__subject"))
        #expect(out.contains("meridianDef_Page_open"))
    }

    /// Composition-Gallery-3 shape ("a service is troubled if it is flaky and
    /// at least 1 critical alert whose service name is its name is fresh"):
    /// a `Definition:` whose body quantifies over a collection that is *not*
    /// the subject's own property (`alerts`, a separate `bind`-produced
    /// workflow variable). `emitDefinitionFunction`'s free `private func …
    /// (_ __subjectValue: Value?) -> Bool` has no `state` in scope, so such a
    /// definition must skip the standalone-helper emission and instead inline
    /// its body wherever `.definitionPredicate` references it — the real call
    /// site (inside a workflow body) always has `state` available. Regression
    /// coverage for `definitionRequiresState` / `emitDefinitionPredicate`.
    @Test("a Definition: quantifying over an external bound collection inlines at its call site instead of a broken free function")
    func definitionRequiringStateInlinesAtCallSite() throws {
        let criticalDef = LoweredDefinition(
            functionName: "meridianDef_Alert_critical",
            subjectVar: "alert",
            body: .comparison(
                .propertyAccess(.identifierRef(name: "alert"), propertyName: "status"),
                .equal, .literal(.string("critical"))
            )
        )
        let troubledBody: IRExpression = .logical(.and, [
            .comparison(
                .propertyAccess(.identifierRef(name: "service"), propertyName: "status"),
                .equal, .literal(.string("flaky"))
            ),
            .quantified(QuantifierIR(
                kind: .atLeast(1),
                description: DescriptionIR(
                    collection: .identifierRef(name: "alerts"),
                    elementVar: "alert",
                    filters: [
                        .definitionPredicate(functionName: "meridianDef_Alert_critical", subject: .identifierRef(name: "alert")),
                        .comparison(
                            .propertyAccess(.identifierRef(name: "alert"), propertyName: "serviceName"),
                            .equal,
                            .propertyAccess(.identifierRef(name: "service"), propertyName: "name")
                        ),
                    ]
                )
            )),
        ])
        let troubledDef = LoweredDefinition(functionName: "meridianDef_Service_troubled", subjectVar: "service", body: troubledBody)

        let workflow = IRWorkflow(
            name: "sweep a service",
            parameters: [IRParameter(name: "service", kind: KindRef("Service"))],
            body: IRBlock(statements: [
                .assert(AssertIR(condition: .definitionPredicate(
                    functionName: "meridianDef_Service_troubled", subject: .identifierRef(name: "service")
                ))),
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emit(workflows: [workflow], definitions: [criticalDef, troubledDef]).combined

        // "troubled" needs `state` for `alerts` — must NOT become a standalone
        // free function (that would reference `state` from a context where it
        // doesn't exist and fail to compile).
        #expect(!out.contains("func meridianDef_Service_troubled"), Comment(rawValue: out))
        // "critical" only reads its own subject — stays a normal helper.
        #expect(out.contains("func meridianDef_Alert_critical"), Comment(rawValue: out))
        // The assert's condition inlines "troubled"'s body directly at the
        // real call site, where `state` is in scope.
        #expect(out.contains("state.get(\"alerts\")"), Comment(rawValue: out))
        // Nested inside the inlined "troubled" body (whose own subject
        // already occupies slot 0 of the element-param env), the quantifier's
        // filter closure param is nesting-depth-numbered `__e1` — never the
        // bare `__e` a non-nested filter would get — so it can never shadow
        // the outer scope (see `freshElementParam`).
        #expect(out.contains("meridianDef_Alert_critical(__e1)"), Comment(rawValue: out))
        // The nested quantifier's own filter still resolves the *outer*
        // definition's subject ("service") to the substituted call-site
        // text, not to a `state.get("service")` shadowed by the quantifier's
        // own elementVar — `.member("name")` is only valid on that rebased,
        // non-optional text.
        #expect(out.contains(".member(\"name\")"), Comment(rawValue: out))
    }

    @Test("nested for-each interpolation segments inside a loop body are dropped")
    func nestedForEachInterpolationInLoopBody() throws {
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
        #expect(try SwiftEmitter().emitValueExpr(.interpolatedString(segs)).contains("for __item in"))
    }

    @Test("loop interpolation shell-escaped holes use loop-relative value emission")
    func loopInterpolationShellEscapedExpression() throws {
        let segs: [IRInterpolationSegment] = [
            .forEach(
                variable: "item",
                collection: .identifierRef(name: "items"),
                body: [
                    .shellEscapedExpression(.propertyAccess(.identifierRef(name: "item"), propertyName: "path")),
                ]
            ),
        ]
        let out = try SwiftEmitter().emitValueExpr(.interpolatedString(segs))
        #expect(out.contains("meridianShellQuote"))
        #expect(out.contains("__item.member(\"path\")"), Comment(rawValue: out))
    }

    @Test("loop interpolation conditionals lower non-comparison predicates via emitExpr")
    func loopInterpolationConditionalLogical() throws {
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
        let out = try SwiftEmitter().emitValueExpr(.interpolatedString(segs))
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

@Suite("SwiftEmitter — block constructs via emit(_:)")
struct SwiftEmitterBlockCoverageTests {

    @Test("while loop and match branch with literal/enum/wildcard patterns")
    func whileAndMatch() throws {
        let cap = ParserTrace.capturing(categories: [.codegen])
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
                    BranchCase(pattern: .enumValue("pending", kind: ""), block: IRBlock(statements: [.complete(CompleteIR(reason: nil))])),
                    BranchCase(pattern: .wildcard, block: IRBlock(statements: [.complete(CompleteIR(reason: nil))])),
                ]
            ),
            thenBlock: IRBlock(statements: [])
        ))
        let wf = IRWorkflow(name: "run the loop", parameters: [], body: IRBlock(statements: [whileLoop, match]))
        let out = try SwiftEmitter(trace: cap.trace).emit(workflows: [wf]).combined
        #expect(out.contains("while "))
        #expect(out.contains("switch "))
        #expect(out.contains("case \"open\""))
        #expect(out.contains("case .approved"))
        #expect(out.contains("case .pending"))
        #expect(out.contains("default:"))
        let trace = cap.lines().joined(separator: "\n")
        #expect(trace.contains("literal("), Comment(rawValue: trace))
        #expect(trace.contains("enum(Verdict.approved)"), Comment(rawValue: trace))
        #expect(trace.contains("enum(pending)"), Comment(rawValue: trace))
        #expect(trace.contains("wildcard"), Comment(rawValue: trace))
    }

    @Test("emit's namespace trace line and every primitiveTraceName arm log under an active .codegen trace")
    func namespaceTraceAndEveryPrimitiveTraceName() throws {
        // `trace.log`'s message is `@autoclosure`, so a silent trace never
        // evaluates `namespace.map { … }` or `primitiveTraceName(_:)` at all —
        // both need an *active* `.codegen` category to execute their bodies.
        let cap = ParserTrace.capturing(categories: [.codegen])
        let body = IRBlock(statements: [
            .bind(BindIR(name: "again", expression: .literal(.number(1)), isRebind: true)),
            .commit(CommitIR()),
            .recover(RecoverIR(pattern: .anyError, handler: IRBlock(statements: []), attachedTo: IRBlock(statements: []))),
            .simultaneously(SimultaneouslyIR(branches: [IRBlock(statements: [])])),
            .aiJudgment(AIJudgmentIR(text: "decide")),
            .aiAutonomy(AIAutonomyIR(text: "repair")),
            .complete(CompleteIR()),
        ])
        let wf = IRWorkflow(name: "cover every primitive", parameters: [], body: body)
        let out = try SwiftEmitter(options: .init(namespaceEnum: "CoverageDemo"), trace: cap.trace)
            .emit(workflows: [wf]).combined
        #expect(out.contains("public enum CoverageDemo {"), Comment(rawValue: out))
        let trace = cap.lines().joined(separator: "\n")
        #expect(trace.contains("namespace CoverageDemo"), Comment(rawValue: trace))
        #expect(trace.contains("emit rebind"), Comment(rawValue: trace))
        #expect(trace.contains("emit commit"), Comment(rawValue: trace))
        #expect(trace.contains("emit recover"), Comment(rawValue: trace))
        #expect(trace.contains("emit simultaneously"), Comment(rawValue: trace))
        #expect(trace.contains("emit aiJudgment"), Comment(rawValue: trace))
        #expect(trace.contains("emit aiAutonomy"), Comment(rawValue: trace))
        #expect(trace.contains("emit complete"), Comment(rawValue: trace))
    }

    @Test("a match branch with a non-empty default arm traces 'present', not 'absent'")
    func matchBranchWithDefaultArmTraces() throws {
        let cap = ParserTrace.capturing(categories: [.codegen])
        let match = IRPrimitive.branch(BranchIR(
            condition: .match(
                .identifierRef(name: "status"),
                [BranchCase(pattern: .literal(.string("open")), block: IRBlock(statements: [.complete(CompleteIR())]))]
            ),
            thenBlock: IRBlock(statements: [.complete(CompleteIR(reason: "fallback"))])
        ))
        let wf = IRWorkflow(name: "run the match", parameters: [], body: IRBlock(statements: [match]))
        let out = try SwiftEmitter(trace: cap.trace).emit(workflows: [wf]).combined
        #expect(out.contains("default:"), Comment(rawValue: out))
        let trace = cap.lines().joined(separator: "\n")
        #expect(trace.contains("default present"), Comment(rawValue: trace))
        #expect(trace.contains(".default: match otherwise"), Comment(rawValue: trace))
    }

    @Test("until loop emits a negated while")
    func untilLoop() throws {
        let cond = IRExpression.comparison(.identifierRef(name: "done"), .equal, .literal(.boolean(true)))
        let loop = IRPrimitive.iterate(IterateIR(
            mode: .untilCondition(cond),
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        ))
        let wf = IRWorkflow(name: "spin until done", parameters: [], body: IRBlock(statements: [loop]))
        let out = try SwiftEmitter().emit(workflows: [wf]).combined
        #expect(out.contains("while "))
    }
}
