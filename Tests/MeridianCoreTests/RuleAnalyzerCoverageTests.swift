import Testing
import Foundation
@testable import MeridianCore

/// Targets `RuleAnalyzer` branches the compile-only corpus does not reach:
/// predicate qualification edges and multi-word subject-filter greedy splits.
@Suite("RuleAnalyzer — coverage gaps")
struct RuleAnalyzerCoverageTests {

    private let analyzer = RuleAnalyzer(trace: .silent(), symbols: nil)

    @Test("parameter-guard predicates qualify nested property accesses")
    func parameterGuardQualifiesPropertyAccess() {
        let rule = RuleAST(
            text: "A customer must not place an order whose order.status is suspended.",
            sourceLine: 4
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected parameter guard"); return
        }
        guard case .parameterGuard(_, _, let predicate, _, _) = parsed else {
            Issue.record("expected parameterGuard"); return
        }
        guard case .comparison(let lhs, .equal, _) = predicate else {
            Issue.record("expected comparison predicate"); return
        }
        guard case .propertyAccess(let base, let prop) = lhs else {
            Issue.record("expected qualified property access on lhs"); return
        }
        #expect(prop.lowercased().contains("status"))
        if case .identifierRef(let kind) = base {
            #expect(kind == "order")
        } else {
            Issue.record("expected order base")
        }
    }

    @Test("predicate identifiers containing possessive markers stay unqualified")
    func possessiveMarkerIdentifierStaysBare() {
        let rule = RuleAST(
            text: "A customer must not place an order whose owner of record is blank.",
            sourceLine: 5
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected parameter guard"); return
        }
        guard case .parameterGuard(_, _, let predicate, _, _) = parsed else {
            Issue.record("expected parameterGuard"); return
        }
        guard case .comparison(let lhs, _, _) = predicate else {
            Issue.record("expected comparison"); return
        }
        guard case .identifierRef(let name) = lhs else {
            Issue.record("expected bare identifier lhs, got \(lhs)"); return
        }
        #expect(name.lowercased().contains("owner"))
    }

    @Test("subject filters fall back to first-token property splitting")
    func subjectFilterFallbackSplit() {
        let rule = RuleAST(
            text: "A customer with alpha beta {{ must not place orders.",
            sourceLine: 6
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(let kind, let filter, _, _, _) = parsed else {
            Issue.record("expected invariant"); return
        }
        #expect(kind == "customer")
        guard let filter, case .comparison = filter else {
            Issue.record("expected comparison subject filter"); return
        }
    }

    @Test("single-token subject filters lower to truthiness property access")
    func singleTokenSubjectFilter() {
        let rule = RuleAST(
            text: "A customer with suspended must not place orders.",
            sourceLine: 7
        )
        guard let parsed = analyzer.classify(rule),
              case .invariant(_, let filter, _, _, _) = parsed,
              let filter else {
            Issue.record("expected invariant with filter"); return
        }
        guard case .propertyAccess(let base, let prop) = filter else {
            Issue.record("expected truthiness property access"); return
        }
        if case .identifierRef(let subject) = base {
            #expect(subject == "customer")
        }
        #expect(prop == "suspended")
    }

    @Test("malformed trigger rules without a comma separator classify as nil")
    func triggerWithoutCommaIsNil() {
        let rule = RuleAST(text: "When payment clears do nothing.", sourceLine: 8)
        #expect(analyzer.classify(rule) == nil)
    }

    @Test("trigger rules with a blank condition or action classify as nil, not a garbage event")
    func triggerWithBlankConditionOrActionIsNil() {
        // A leading comma leaves the condition empty; without the
        // non-emptiness guard, `buildTriggerWorkflow` would happily mint a
        // `trigger..fired` event from an empty condition instead of this
        // routing to the real `MER1004: unparseable rule` diagnostic.
        #expect(analyzer.classify(RuleAST(text: "When , escalate the request.", sourceLine: 10)) == nil)
        #expect(analyzer.classify(RuleAST(text: "When the request is stale,.", sourceLine: 11)) == nil)
    }

    @Test("subject filters accept possessive multi-word values via greedy split")
    func subjectFilterPossessiveMultiWordValue() {
        let rule = RuleAST(
            text: "A customer with note order's id must not place orders.",
            sourceLine: 9
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(_, let filter, _, _, _) = parsed,
              let filter,
              case .comparison(let lhs, .equal, let rhs) = filter else {
            Issue.record("expected comparison subject filter"); return
        }
        guard case .propertyAccess(_, let prop) = lhs else {
            Issue.record("expected property access lhs"); return
        }
        #expect(prop == "note order's")
        guard case .identifierRef(let value) = rhs else {
            Issue.record("expected identifier rhs, got \(rhs)"); return
        }
        #expect(value == "id")
    }

    @Test("with a real symbol table, a relation-traversal subject filter becomes a rejectable verbPredicate, not a silently-wrong shorthand split")
    func subjectFilterWithSymbolsRecognizesRelationTraversal() throws {
        // "active prescriptions include a contraindicated drug" is a relation
        // traversal over the declared `include` verb — 6 words with a
        // mid-clause article, exactly the gotcha #7 shape. Without a symbol
        // table (`analyzer`, built with `symbols: nil`), `buildSubjectFilter`
        // has no way to recognize this and its guard rail correctly declines
        // (see `subjectFilterFallsBackToFirstTokenPropertySplitting`-style
        // cases). WITH a symbol table that declares the `include` verb,
        // `ActiveVerbParser` recognizes the whole clause as a genuine
        // `.verbPredicate` — a form `RuleInjector.lowerExprSimple` explicitly
        // rejects with `MER3016` — instead of `buildSubjectFilter` guessing a
        // meaningless `patient.active_prescriptions_include_a_contraindicated
        // == drug` comparison that would have silently compiled.
        let cfg = """
        === vocabulary ===
        A patient is a kind of thing.
        A prescription is a kind of thing.
        A prescription has a drug, which is a String.
        Inclusion relates one prescription to one drug.
        Inclusion is read from the prescription's drug.
        The verb to include (it includes, it is included) means the inclusion relation.
        """
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig")
        let symbolAwareAnalyzer = RuleAnalyzer(trace: .silent(), symbols: symbols)
        let rule = RuleAST(
            text: "A patient whose active prescriptions include a contraindicated drug must not receive the new order.",
            sourceLine: 20
        )
        guard let parsed = symbolAwareAnalyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(_, let filter, _, _, _) = parsed, let filter else {
            Issue.record("expected a subject filter"); return
        }
        guard case .verbPredicate = filter else {
            Issue.record("expected a rejectable verbPredicate form, got \(filter)"); return
        }
    }

    @Test("compound parameter guards qualify each property-access arm")
    func compoundParameterGuardPropertyAccess() {
        let rule = RuleAST(
            text: "A customer must not place an order whose order's status is suspended and order's total amount is more than 1000.",
            sourceLine: 10
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected parameter guard"); return
        }
        guard case .parameterGuard(_, _, let predicate, _, _) = parsed,
              case .logical(.and, let arms) = predicate else {
            Issue.record("expected logical predicate"); return
        }
        #expect(arms.count >= 2)
    }

    @Test("parameter guards pass literal predicates through qualifyPredicate default")
    func literalPredicateParameterGuard() {
        let rule = RuleAST(
            text: "A customer must not place an order whose true.",
            sourceLine: 11
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected parameter guard"); return
        }
        guard case .parameterGuard(_, _, let predicate, _, _) = parsed else {
            Issue.record("expected parameterGuard"); return
        }
        guard case .literal = predicate else {
            Issue.record("expected literal predicate, got \(predicate)"); return
        }
    }

    @Test("\"without\" subject filter negates the clause")
    func withoutSubjectFilterNegates() {
        let rule = RuleAST(
            text: "A user without clearance must not access classified resources.",
            sourceLine: 11
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(let kind, let filter, let action, _, _) = parsed else {
            Issue.record("expected invariant"); return
        }
        #expect(kind == "user")
        #expect(action == "access classified resources")
        guard case .logical(.not, let inner) = filter else {
            Issue.record("expected negated filter, got \(String(describing: filter))"); return
        }
        guard case .propertyAccess(.identifierRef("user"), "clearance") = inner.first else {
            Issue.record("expected negated user.clearance property access"); return
        }
    }

    @Test("whitespace-only subject filters lower to nil")
    func whitespaceOnlySubjectFilter() {
        let rule = RuleAST(
            text: "A customer with    must not place orders.",
            sourceLine: 12
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(_, let filter, _, _, _) = parsed else {
            Issue.record("expected invariant"); return
        }
        #expect(filter == nil)
    }

    @Test("bounded permissions parse trailing whose conditions")
    func boundedPermissionWithConditions() {
        let rule = RuleAST(
            text: "A customer with active may place orders whose total amount is less than 100.",
            sourceLine: 13
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected permission"); return
        }
        guard case .permission(_, _, let action, let conditions, let isBounded, _, _) = parsed else {
            Issue.record("expected permission"); return
        }
        #expect(isBounded)
        #expect(conditions != nil)
        #expect(action.lowercased().contains("order"))
    }

    @Test("bounded permissions parse trailing if conditions")
    func boundedPermissionWithIfCondition() {
        let rule = RuleAST(
            text: "A customer may place orders if ALLOW_CHECKOUT is set.",
            sourceLine: 14
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected permission"); return
        }
        guard case .permission(_, _, let action, let conditions, let isBounded, _, _) = parsed else {
            Issue.record("expected permission"); return
        }
        #expect(isBounded)
        #expect(conditions != nil)
        #expect(action == "place orders")
    }

    @Test("bounded permissions parse trailing up to conditions")
    func boundedPermissionWithUpToCondition() {
        let rule = RuleAST(
            text: "A customer may place orders up to five times per day.",
            sourceLine: 15
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected permission"); return
        }
        guard case .permission(_, _, let action, let conditions, let isBounded, _, _) = parsed else {
            Issue.record("expected permission"); return
        }
        #expect(isBounded)
        #expect(conditions != nil)
        #expect(action == "place orders")
    }

    @Test("parameter guards qualify possessive-chain predicate bases")
    func possessiveChainPredicateQualification() {
        let rule = RuleAST(
            text: "A customer must not place an order whose order's status is suspended.",
            sourceLine: 16
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected parameter guard"); return
        }
        guard case .parameterGuard(_, _, let predicate, _, _) = parsed else {
            Issue.record("expected parameterGuard"); return
        }
        guard case .comparison(let lhs, .equal, _) = predicate else {
            Issue.record("expected comparison"); return
        }
        guard case .propertyAccess(let base, let prop) = lhs else {
            Issue.record("expected property access lhs"); return
        }
        #expect(prop == "status")
        if case .propertyAccess(let orderBase, let orderProp) = base {
            #expect(orderProp == "order")
            if case .identifierRef(let kind) = orderBase {
                #expect(kind == "order")
            } else {
                Issue.record("expected order identifier base")
            }
        } else {
            Issue.record("expected nested property access base")
        }
    }

    @Test("unrecognized rules log unclassified and return nil")
    func unclassifiedRuleLogsAndReturnsNil() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        let traced = RuleAnalyzer(trace: cap.trace, symbols: nil)
        let rule = RuleAST(text: "A customer should place orders freely.", sourceLine: 17)
        #expect(traced.classify(rule) == nil)
        #expect(cap.lines().contains { $0.contains("unclassified") })
    }

    @Test("subject filters parse comparison shorthand without a copula")
    func comparisonShorthandSubjectFilter() {
        let rule = RuleAST(
            text: "A customer with risk score more than 80 must not place an order.",
            sourceLine: 18
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected invariant"); return
        }
        guard case .invariant(_, let filter, _, _, _) = parsed,
              let filter,
              case .comparison(let lhs, .greaterThan, let rhs) = filter else {
            Issue.record("expected greater-than subject filter"); return
        }
        guard case .propertyAccess(_, let prop) = lhs else {
            Issue.record("expected property access lhs"); return
        }
        #expect(prop == "risk score")
        guard case .literal = rhs else {
            Issue.record("expected numeric rhs"); return
        }
    }

    @Test("preconditions parse subject filters on the leading clause")
    func preconditionWithSubjectFilter() {
        let rule = RuleAST(
            text: "An order with status submitted must be approved by an account manager before fulfillment.",
            sourceLine: 19
        )
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected precondition"); return
        }
        guard case .precondition(let kind, let filter, _, let gate, _, _) = parsed else {
            Issue.record("expected precondition"); return
        }
        #expect(kind == "order")
        guard let filter, case .comparison = filter else {
            Issue.record("expected comparison filter"); return
        }
        guard case .approval(let role) = gate else {
            Issue.record("expected approval gate"); return
        }
        #expect(role.lowercased().contains("account manager"))
    }
}
