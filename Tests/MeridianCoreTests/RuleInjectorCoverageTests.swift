import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

/// Direct `RuleInjector` coverage for branches the full-compile corpus does
/// not reach: precondition gating shapes, approval deduplication, permission
/// object-matching + softening, trigger action validation, and the
/// `lowerExprSimple` / interpolation lowering arms used by rule predicates.
@Suite("RuleInjector — direct coverage")
struct RuleInjectorCoverageTests {

    private let sr = SourceRange(file: "t.meridian", line: 2, column: 0)

    private func symbols() throws -> SymbolTable {
        let cfg = """
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          status: String.
        order has a status, which is one of (open, closed).
        customer is a kind of thing.
        account manager is a kind of thing.
        === constants ===
        The default currency is "USD".
        === instances ===
        There is a payment processor called stripe:
          api endpoint = "https://api.stripe.com/v1"
        """
        let parsed = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        return SymbolTable.build(from: parsed, sourceFile: "t.merconfig", trace: .silent())
    }

    private func workflow(
        name: String,
        params: [(String, String)] = [],
        body: [IRPrimitive]
    ) -> IRWorkflow {
        IRWorkflow(
            name: name,
            parameters: params.map { IRParameter(name: $0.0, kind: KindRef($0.1)) },
            body: IRBlock(statements: body)
        )
    }

    private func approvalWait(subject: String = "order") -> IRPrimitive {
        .wait(WaitIR(condition: .approval(of: .identifierRef(name: subject), by: "manager"), sourceRange: sr))
    }

    private func inject(
        rules: [ParsedRule],
        into workflows: [IRWorkflow],
        symbols: SymbolTable? = nil,
        fallbackPolicy: FallbackPolicy = .strict,
        lowerAction: ((String, SourceRange) throws -> [IRPrimitive])? = nil
    ) throws -> [IRWorkflow] {
        let sym = try symbols ?? self.symbols()
        var injector = RuleInjector(
            symbols: sym,
            trace: .silent(),
            lowerAction: lowerAction,
            fallbackPolicy: fallbackPolicy,
            sourceFile: "t.meridian"
        )
        return try injector.inject(rules: rules, into: workflows, sourceFile: "t.meridian")
    }

    // MARK: - Preconditions

    @Test("precondition without subject filter prepends a bare wait")
    func preconditionBareWait() throws {
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: nil,
                actionText: "an order",
                gate: .approval(by: "manager"),
                sourceLine: 2,
                originalText: "An order must be approved by a manager before fulfillment."
            )
        ]
        let wf = workflow(name: "fulfill an order", params: [("order", "order")], body: [.complete(CompleteIR())])
        let out = try inject(rules: rules, into: [wf])
        guard case .wait = out[0].body.statements.first else {
            Issue.record("expected bare wait prepended"); return
        }
    }

    @Test("precondition with subject filter wraps the wait in a branch")
    func preconditionFilteredWait() throws {
        let filter = ExpressionAST.comparison(
            .propertyAccess(.identifierRef("order"), "status"),
            .equal,
            .literal(.string("open"))
        )
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: filter,
                actionText: "an order",
                gate: .approval(by: "manager"),
                sourceLine: 2,
                originalText: "An open order must be approved by a manager before fulfillment."
            )
        ]
        let wf = workflow(name: "fulfill an order", params: [("order", "order")], body: [.complete(CompleteIR())])
        let out = try inject(rules: rules, into: [wf])
        guard case .branch(let br) = out[0].body.statements.first else {
            Issue.record("expected filtered branch"); return
        }
        guard case .wait = br.thenBlock.statements.first else {
            Issue.record("expected wait inside branch"); return
        }
    }

    @Test("event-gate preconditions lower to wait(.event)")
    func eventGatePrecondition() throws {
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: nil,
                actionText: "an order",
                gate: .event(named: "paymentCleared"),
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let wf = workflow(name: "ship an order", params: [("order", "order")], body: [.complete(CompleteIR())])
        let out = try inject(rules: rules, into: [wf])
        guard case .wait(let w) = out[0].body.statements.first else {
            Issue.record("expected wait"); return
        }
        guard case .event(let name, nil) = w.condition else {
            Issue.record("expected event gate"); return
        }
        #expect(name == "paymentCleared")
    }

    @Test("precondition skips injection when the workflow already waits for approval")
    func preconditionSkipsDuplicateApprovalWait() throws {
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: nil,
                actionText: "an order",
                gate: .approval(by: "manager"),
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order")],
            body: [approvalWait(), .complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        #expect(out[0].body.statements.count == 2)
        guard case .wait = out[0].body.statements.first else {
            Issue.record("expected original approval wait only"); return
        }
    }

    @Test("approval deduplication detects invoke ids containing approve")
    func preconditionSkipsInvokeApprove() throws {
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: nil,
                actionText: "an order",
                gate: .approval(by: "manager"),
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order")],
            body: [.invoke(InvokeIR(toolID: "billing.approve")), .complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        #expect(out[0].body.statements.count == 2)
    }

    @Test("approval deduplication walks nested branch, iterate, and recover blocks")
    func preconditionSkipsNestedApproval() throws {
        let rules: [ParsedRule] = [
            .precondition(
                subjectKind: "order",
                subjectFilter: nil,
                actionText: "an order",
                gate: .approval(by: "manager"),
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let nestedWait = IRBlock(statements: [approvalWait()])
        let bodies: [[IRPrimitive]] = [
            [.branch(BranchIR(
                condition: .predicate(.literal(.boolean(true))),
                thenBlock: nestedWait
            )), .complete(CompleteIR())],
            [.iterate(IterateIR(
                mode: .whileCondition(.literal(.boolean(true))),
                body: nestedWait
            )), .complete(CompleteIR())],
            [.recover(RecoverIR(
                pattern: .anyError,
                handler: IRBlock(statements: []),
                attachedTo: nestedWait
            )), .complete(CompleteIR())],
        ]
        for body in bodies {
            let wf = workflow(name: "approve an order", params: [("order", "order")], body: body)
            let out = try inject(rules: rules, into: [wf])
            #expect(out[0].body.statements.count == body.count)
        }
    }

    // MARK: - Permissions

    @Test("object-driven permission matches a workflow that only takes the action object")
    func permissionObjectDrivenMatch() throws {
        let rules: [ParsedRule] = [
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: nil,
                allowedActionText: "approve any order",
                conditions: nil,
                isBounded: false,
                sourceLine: 2,
                originalText: "stub"
            ))
        ]
        let wf = workflow(name: "approve an order", params: [("order", "order")], body: [.complete(CompleteIR())])
        var injector = RuleInjector(symbols: try symbols(), trace: .silent(), sourceFile: "t.meridian")
        _ = try injector.inject(rules: rules, into: [wf], sourceFile: "t.meridian")
        #expect(injector.unattachedRules.isEmpty)
    }

    @Test("applyPermissions softens invariant asserts with matching permission OR-terms")
    func permissionSoftening() throws {
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "customer",
                subjectFilter: .comparison(.identifierRef("customer"), .equal, .literal(.boolean(true))),
                forbiddenActionText: "place an order",
                sourceLine: 2,
                originalText: "A customer must not place an order."
            ),
            .permission(PermissionRule(
                subjectKind: "customer",
                subjectFilter: .comparison(.identifierRef("customer"), .equal, .literal(.boolean(true))),
                allowedActionText: "place an order",
                conditions: .envVar("ALLOW_GUEST_CHECKOUT"),
                isBounded: false,
                sourceLine: 3,
                originalText: "A customer may place an order when ALLOW_GUEST_CHECKOUT is set."
            )),
        ]
        let wf = workflow(
            name: "place an order",
            params: [("customer", "customer"), ("order", "order")],
            body: [.complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        guard case .assert(let a) = out[0].body.statements.first else {
            Issue.record("expected softened assert"); return
        }
        guard case .logical(.or, _) = a.condition else {
            Issue.record("expected OR-softened assert"); return
        }
    }

    @Test("invariant with a multi-word kind subject attaches, and its predicate identifier is camelCased (not a raw space)")
    func multiWordKindSubjectAttachesAndCamelCases() throws {
        // Regression for a sharp edge: a workflow parameter's `KindRef.name`
        // is always a concatenated Swift type name ("MedicationOrder"), but
        // a rule's subject/object kind text is space-separated prose
        // ("medication order") straight out of `parseSubject`/`extractObjectKind`.
        // `hasParameter`/`actionStemOverlap` must decamelize the kind name
        // before tokenizing, or a multi-word subject can never match its own
        // parameter. Separately, `lowerExprSimple` must camelCase a bare
        // identifier exactly like the main `ASTToIR.lowerExpr` path does, or
        // the emitted `state.get(...)` key (built from `propertyAccess`'s
        // base) contains a literal space and can never resolve at runtime.
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "medication order",
                subjectFilter: .comparison(
                    .propertyAccess(.identifierRef("medication order"), "allergy check"),
                    .equal,
                    .literal(.string("conflict"))
                ),
                forbiddenActionText: "be administered",
                sourceLine: 2,
                originalText: "A medication order with allergy check \"conflict\" must not be administered."
            )
        ]
        let wf = workflow(
            name: "administer a medication order for a patient by a nurse",
            params: [("medicationOrder", "MedicationOrder"), ("patient", "Patient"), ("nurse", "Nurse")],
            body: [.complete(CompleteIR())]
        )
        var injector = RuleInjector(symbols: try symbols(), trace: .silent(), sourceFile: "t.meridian")
        let out = try injector.inject(rules: rules, into: [wf], sourceFile: "t.meridian")
        #expect(injector.unattachedRules.isEmpty)
        guard case .assert(let a) = out[0].body.statements.first else {
            Issue.record("expected an injected assert; rule did not attach"); return
        }
        guard case .logical(.not, let inner) = a.condition, case .comparison(let lhs, _, _) = inner.first else {
            Issue.record("expected a negated comparison condition, got \(a.condition)"); return
        }
        guard case .propertyAccess(let base, let prop) = lhs else {
            Issue.record("expected the comparison LHS to be a property access, got \(lhs)"); return
        }
        guard case .identifierRef(let name) = base else {
            Issue.record("expected the property access base to be a bare identifier, got \(base)"); return
        }
        #expect(name == "medicationOrder", "expected a camelCased identifier, got '\(name)' (a raw space can never match a bound state key)")
        #expect(prop == "allergy check")
    }

    @Test("IdentifierNaming.decamelize recovers word boundaries from a concatenated KindRef name")
    func decamelizeRecoversWordBoundaries() {
        #expect(IdentifierNaming.decamelize("MedicationOrder") == "Medication Order")
        #expect(IdentifierNaming.decamelize("AccessRequest") == "Access Request")
        #expect(IdentifierNaming.decamelize("Order") == "Order")
        #expect(IdentifierNaming.decamelize("SLO") == "SLO")
        #expect(IdentifierNaming.decamelize("") == "")
    }

    @Test("bounded permission injects a gate assert built from conditions")
    func boundedPermissionGate() throws {
        let rules: [ParsedRule] = [
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: nil,
                allowedActionText: "approve any order",
                conditions: .comparison(
                    .propertyAccess(.identifierRef("order"), "status"),
                    .equal,
                    .literal(.string("open"))
                ),
                isBounded: true,
                sourceLine: 2,
                originalText: "stub"
            ))
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order"), ("account manager", "account manager")],
            body: [.complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        guard case .assert = out[0].body.statements.first else {
            Issue.record("expected permission gate assert"); return
        }
    }

    // MARK: - lowerExprSimple arms (via permission conditions)

    @Test("lowerExprSimple covers env/now/constant/instance/enum/invoke/interpolation/decide arms")
    func lowerExprSimpleExpressionShapes() throws {
        let conditions = ExpressionAST.logical(.and, [
            .envVar("HOME"),
            .now,
            .identifierRef("default currency"),
            .identifierRef("stripe"),
            .identifierRef("open"),
            .invoke("demo.tool", [("note", .literal(.string("hi")))]),
            .interpolatedString([
                .literal("prefix-"),
                .expression(.identifierRef("order")),
                .conditional(
                    condition: .literal(.boolean(true)),
                    then: [.literal("yes")],
                    otherwise: [.literal("no")]
                ),
                .forEach(variable: "item", collection: .identifierRef("order"), body: [.literal("-")]),
                .formatted(.literal(.string("2020-01-01")), formatter: "short date"),
            ]),
            .decideWhether(question: "proceed?"),
        ])
        let rules: [ParsedRule] = [
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: .literal(.boolean(true)),
                allowedActionText: "approve any order",
                conditions: conditions,
                isBounded: false,
                sourceLine: 2,
                originalText: "stub"
            )),
            .invariant(
                subjectKind: "account manager",
                subjectFilter: nil,
                forbiddenActionText: "approve any order",
                sourceLine: 3,
                originalText: "stub invariant"
            ),
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order"), ("account manager", "account manager")],
            body: [.complete(CompleteIR())]
        )
        _ = try inject(rules: rules, into: [wf])
    }

    @Test("lowerExprSimple rejects quantified predicates in parameter guards")
    func lowerExprSimpleRejectsQuantified() throws {
        let rules: [ParsedRule] = [
            .parameterGuard(
                subjectKind: "customer",
                actionText: "place an order",
                predicate: .quantified(QuantifierAST(
                    kind: .all,
                    description: DescriptionAST(noun: "orders"),
                    body: .literal(.boolean(true))
                )),
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let wf = workflow(
            name: "place an order",
            params: [("customer", "customer"), ("order", "order")],
            body: [.complete(CompleteIR())]
        )
        #expect(throws: CompilerError.self) {
            _ = try inject(rules: rules, into: [wf])
        }
    }

    /// `lowerExprSimple`'s rejection arm covers eight structurally rich
    /// `ExpressionAST` shapes a rule body cannot express (see its doc
    /// comment and `corpora/GENERATING_A_CORPUS.md` gotcha #7). The
    /// `quantified` case above and the `relationTraversal` end-to-end case
    /// in `RuleLoweringTests` each exercise one arm through a different
    /// entry point; this covers the remaining six directly so every arm of
    /// the switch's rejection branch is actually exercised, not just
    /// reachable in principle.
    @Test("lowerExprSimple rejects every other structurally-rich predicate shape",
          arguments: [
            ExpressionAST.relationTraversal(.identifierRef("order"), relation: "line items", navKind: "all"),
            ExpressionAST.description(DescriptionAST(noun: "orders")),
            ExpressionAST.aggregate(.count, DescriptionAST(noun: "orders")),
            ExpressionAST.superlative(SuperlativeAST(
                description: DescriptionAST(noun: "orders"), property: "createdAt", ascending: false)),
            ExpressionAST.tableLookup(
                table: "shipping_rates", keyColumn: "region", key: .literal(.string("west")), valueColumn: "rate"),
            ExpressionAST.verbPredicate(
                subject: .identifierRef("order"), verb: "contains", object: .identifierRef("contraband")),
            ExpressionAST.malformed("garbled predicate"),
            ExpressionAST.recordList(fields: ["a"], rows: [[.literal(.integer(1))]]),
          ])
    func lowerExprSimpleRejectsOtherRichShapes(_ predicate: ExpressionAST) throws {
        let rules: [ParsedRule] = [
            .parameterGuard(
                subjectKind: "customer",
                actionText: "place an order",
                predicate: predicate,
                sourceLine: 2,
                originalText: "stub"
            )
        ]
        let wf = workflow(
            name: "place an order",
            params: [("customer", "customer"), ("order", "order")],
            body: [.complete(CompleteIR())]
        )
        #expect(throws: CompilerError.self) {
            _ = try inject(rules: rules, into: [wf])
        }
    }

    @Test("lowerInterpolationSegmentSimple rejects unknown formatters")
    func lowerExprSimpleRejectsUnknownFormatter() throws {
        let rules: [ParsedRule] = [
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: nil,
                allowedActionText: "approve any order",
                conditions: .interpolatedString([
                    .formatted(.literal(.string("x")), formatter: "not_a_real_formatter"),
                ]),
                isBounded: true,
                sourceLine: 2,
                originalText: "stub"
            )),
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order"), ("account manager", "account manager")],
            body: [.complete(CompleteIR())]
        )
        #expect(throws: CompilerError.self) {
            _ = try inject(rules: rules, into: [wf])
        }
    }

    // MARK: - Trigger synthesis

    @Test("trigger synthesis throws on unresolved actions in strict mode")
    func triggerUnresolvedStrict() throws {
        var injector = RuleInjector(
            symbols: try symbols(),
            trace: .silent(),
            lowerAction: { _, _ in
                throw CompilerError.diagnostics([
                    Diagnostic.error(.unresolvedPhrase, message: "no such workflow", range: .unknown)
                ])
            },
            fallbackPolicy: .strict,
            sourceFile: "t.meridian"
        )
        let rules: [ParsedRule] = [
            .trigger(
                conditionText: "payment received",
                actionText: "frobnicate the order",
                sourceLine: 2,
                originalText: "When payment received, frobnicate the order."
            )
        ]
        #expect(throws: CompilerError.self) {
            _ = try injector.synthesizeTriggers(rules, sourceFile: "t.meridian")
        }
    }

    @Test("trigger synthesis tolerates unresolved actions when the fallback is allowed")
    func triggerUnresolvedLenient() throws {
        var injector = RuleInjector(
            symbols: try symbols(),
            trace: .silent(),
            lowerAction: { _, _ in
                throw CompilerError.diagnostics([
                    Diagnostic.error(.unresolvedPhrase, message: "no such workflow", range: .unknown)
                ])
            },
            fallbackPolicy: FallbackPolicy(allowed: [.unresolvedTriggerActions]),
            sourceFile: "t.meridian"
        )
        let rules: [ParsedRule] = [
            .trigger(
                conditionText: "payment received",
                actionText: "frobnicate the order",
                sourceLine: 2,
                originalText: "When payment received, frobnicate the order."
            )
        ]
        let triggers = try injector.synthesizeTriggers(rules, sourceFile: "t.meridian")
        #expect(triggers.count == 1)
        #expect(triggers[0].name.hasPrefix("when "))
    }

    // MARK: - applyPermissions / lowerExprSimple AST arms

    @Test("applyPermissions ORs filter-only and condition-only permission parts")
    func permissionSofteningFilterOnly() throws {
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "customer",
                subjectFilter: .comparison(.identifierRef("customer"), .equal, .literal(.boolean(true))),
                forbiddenActionText: "place an order",
                sourceLine: 2,
                originalText: "stub"
            ),
            .permission(PermissionRule(
                subjectKind: "customer",
                subjectFilter: .envVar("ALLOW_CHECKOUT"),
                allowedActionText: "place an order",
                conditions: nil,
                isBounded: false,
                sourceLine: 3,
                originalText: "stub filter-only"
            )),
        ]
        let wf = workflow(
            name: "place an order",
            params: [("customer", "customer"), ("order", "order")],
            body: [.complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        guard case .assert(let a) = out[0].body.statements.first,
              case .logical(.or, let arms) = a.condition else {
            Issue.record("expected softened assert"); return
        }
        #expect(arms.count >= 2)
    }

    @Test("lowerExprSimple lowers explicit constant/instance refs and interpolation segment arms")
    func lowerExprSimpleExplicitRefsAndSegments() throws {
        let conditions = ExpressionAST.logical(.and, [
            .constantRef("default currency"),
            .instanceRef("stripe"),
            .interpolatedString([
                .conditional(
                    condition: .literal(.boolean(true)),
                    then: [.literal("yes")],
                    otherwise: [.literal("no")]
                ),
                .forEach(variable: "item", collection: .identifierRef("order"), body: [.literal("-")]),
                .formatted(.literal(.string("2020-01-01")), formatter: "short date"),
            ]),
        ])
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "account manager",
                subjectFilter: .comparison(.identifierRef("account manager"), .equal, .literal(.boolean(true))),
                forbiddenActionText: "approve any order",
                sourceLine: 2,
                originalText: "stub"
            ),
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: nil,
                allowedActionText: "approve any order",
                conditions: conditions,
                isBounded: false,
                sourceLine: 3,
                originalText: "stub"
            )),
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order"), ("account manager", "account manager")],
            body: [.complete(CompleteIR())]
        )
        _ = try inject(rules: rules, into: [wf])
    }

    @Test("applyPermissions treats unbounded permissions with no filter/conditions as always-true OR arms")
    func permissionSofteningUnconditional() throws {
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "customer",
                subjectFilter: .comparison(.identifierRef("customer"), .equal, .literal(.boolean(true))),
                forbiddenActionText: "place an order",
                sourceLine: 2,
                originalText: "stub"
            ),
            .permission(PermissionRule(
                subjectKind: "customer",
                subjectFilter: nil,
                allowedActionText: "place an order",
                conditions: nil,
                isBounded: false,
                sourceLine: 3,
                originalText: "stub unconditional"
            )),
        ]
        let wf = workflow(
            name: "place an order",
            params: [("customer", "customer"), ("order", "order")],
            body: [.complete(CompleteIR())]
        )
        let out = try inject(rules: rules, into: [wf])
        guard case .assert(let a) = out[0].body.statements.first,
              case .logical(.or, let arms) = a.condition else {
            Issue.record("expected OR-softened assert"); return
        }
        #expect(arms.contains { if case .literal(.boolean(true)) = $0 { return true }; return false })
    }

    @Test("lowerExprSimple lowers now, invoke, and decide-whether in permission conditions")
    func lowerExprSimpleNowInvokeDecide() throws {
        let conditions = ExpressionAST.logical(.and, [
            .now,
            .invoke("demo.tool", [("note", .literal(.string("hi")))]),
            .decideWhether(question: "proceed?"),
        ])
        let rules: [ParsedRule] = [
            .invariant(
                subjectKind: "account manager",
                subjectFilter: .comparison(.identifierRef("account manager"), .equal, .literal(.boolean(true))),
                forbiddenActionText: "approve any order",
                sourceLine: 2,
                originalText: "stub"
            ),
            .permission(PermissionRule(
                subjectKind: "account manager",
                subjectFilter: nil,
                allowedActionText: "approve any order",
                conditions: conditions,
                isBounded: false,
                sourceLine: 3,
                originalText: "stub"
            )),
        ]
        let wf = workflow(
            name: "approve an order",
            params: [("order", "order"), ("account manager", "account manager")],
            body: [.complete(CompleteIR())]
        )
        _ = try inject(rules: rules, into: [wf])
    }
}
