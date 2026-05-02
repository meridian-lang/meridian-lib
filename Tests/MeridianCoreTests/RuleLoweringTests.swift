import Testing
import Foundation
@testable import MeridianCore

@Suite("Rule Lowering Tests (Phase C)")
struct RuleLoweringTests {

    let analyzer = RuleAnalyzer()

    @Test("must not → invariant")
    func mustNotInvariant() {
        let rule = RuleAST(text: "A customer with status suspended must not place orders.", sourceLine: 8)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil")
            return
        }
        if case .invariant(let kind, _, let action, _, _) = parsed {
            #expect(kind == "customer")
            #expect(action.lowercased().contains("order"))
        } else {
            Issue.record("expected .invariant, got: \(parsed)")
        }
    }

    @Test("must not whose → parameterGuard")
    func mustNotWhoseGuard() {
        let rule = RuleAST(text: "A customer must not place an order whose total amount is more than their credit limit.", sourceLine: 10)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil"); return
        }
        if case .parameterGuard(let kind, let action, _, _, _) = parsed {
            #expect(kind == "customer")
            #expect(action.lowercased().contains("order"))
        } else {
            Issue.record("expected .parameterGuard, got: \(parsed)")
        }
    }

    @Test("must be … by … before → precondition")
    func mustBeApprovedBefore() {
        let rule = RuleAST(text: "An order with total amount more than the high value threshold must be approved by an account manager before fulfillment.", sourceLine: 12)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil"); return
        }
        if case .precondition(_, _, _, let gate, _, _) = parsed {
            if case .approval(let role) = gate {
                #expect(role.lowercased().contains("account manager") || role.lowercased().contains("manager"))
            } else {
                Issue.record("expected .approval gate, got: \(gate)")
            }
        } else {
            Issue.record("expected .precondition, got: \(parsed)")
        }
    }

    @Test("when … → trigger")
    func whenTrigger() {
        let rule = RuleAST(text: "When an order has been on hold for more than 7 days, escalate the order to the account manager of the customer who placed the order.", sourceLine: 14)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil"); return
        }
        if case .trigger(let cond, let action, _, _) = parsed {
            #expect(cond.lowercased().contains("order") || cond.lowercased().contains("hold"))
            #expect(action.lowercased().contains("escalate") || action.lowercased().contains("order"))
        } else {
            Issue.record("expected .trigger, got: \(parsed)")
        }
    }

    @Test("may → permission")
    func mayPermission() {
        let rule = RuleAST(text: "A customer with status verified may place orders.", sourceLine: 20)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil"); return
        }
        if case .permission(let kind, _, let action, let conditions, let bounded, _, _) = parsed {
            #expect(kind == "customer")
            #expect(action.lowercased().contains("order"))
            #expect(!bounded)
            #expect(conditions == nil)
        } else {
            Issue.record("expected .permission, got: \(parsed)")
        }
    }

    @Test("garbled rule → nil")
    func garbledRule() {
        let rule = RuleAST(text: "This is completely unparseable random text without structure.", sourceLine: 99)
        let result = analyzer.classify(rule)
        #expect(result == nil)
    }

    @Test("bounded may → permission with isBounded=true")
    func boundedPermission() {
        let rule = RuleAST(text: "An account manager may approve any order whose total amount is at most $10000.", sourceLine: 20)
        guard let parsed = analyzer.classify(rule) else {
            Issue.record("expected ParsedRule, got nil"); return
        }
        if case .permission(_, _, _, _, let bounded, _, _) = parsed {
            #expect(bounded, "Expected bounded=true for 'at most' clause")
        } else {
            Issue.record("expected .permission, got: \(parsed)")
        }
    }

    @Test("bounded permission injects an AssertIR gate into matching workflows")
    func boundedPermissionInjectsGate() throws {
        // Define a workflow `approve an order` and a bounded permission
        // capping at $10,000. The compiler must inject an assert at the
        // start of the workflow that fails when the order's total amount
        // exceeds $10,000.
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        An account manager may approve any order whose total amount is at most $10000.

        To approve an order:
          complete with reason "approved".
        """
        let cfg = """
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          total_amount: Money.
        account manager is a kind of thing.
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meridian",
            merconfigSource: cfg, merconfigFile: "test.merconfig"
        )
        // The bounded gate should be emitted as a runtime.assert near the
        // beginning of the workflow body, with the cap value visible.
        #expect(out.contains("runtime.assert"),
                Comment(rawValue: "Expected a runtime.assert (gate) in:\n\(String(out.prefix(3000)))"))
        #expect(out.contains("10000") || out.contains("10_000"),
                Comment(rawValue: "Expected the $10000 cap to appear in:\n\(String(out.prefix(3000)))"))
        // The gate's message documents which permission it represents.
        #expect(out.contains("Permission required"),
                Comment(rawValue: "Expected 'Permission required' message in:\n\(String(out.prefix(3000)))"))
    }

    @Test("order_processing rules all lower with invariants injected")
    func orderProcessingRulesInjectAsserts() throws {
        let merURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("examples/order_processing.meridian")
        let cfgURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("examples/ecommerce.merconfig")
        let mer = try String(contentsOf: merURL, encoding: .utf8)
        let cfg = try String(contentsOf: cfgURL, encoding: .utf8)
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "order_processing.meridian",
            merconfigSource: cfg, merconfigFile: "ecommerce.merconfig"
        )
        #expect(out.contains("assert") || out.contains("Assert") || out.contains("MeridianRuntimeError"),
                Comment(rawValue: "Expected assert in:\n\(String(out.prefix(2000)))"))
    }

    @Test("permission rule that matches no workflow still parses (may with no must-not)")
    func standalonePermissionRule() {
        let rule = RuleAST(text: "A customer with status premium may place orders.", sourceLine: 25)
        let parsed = analyzer.classify(rule)
        #expect(parsed != nil, "Expected permission to parse")
        if case .permission(let kind, _, let action, _, let bounded, _, _) = parsed! {
            #expect(kind == "customer")
            #expect(action.lowercased().contains("order"))
            #expect(!bounded)
        } else {
            Issue.record("expected .permission, got: \(String(describing: parsed))")
        }
    }

    @Test("trigger synthesizes a workflow with WaitIR — strict mode, action resolves to a workflow")
    func triggerSynthesizesWorkflow() throws {
        // Strict mode: trigger action `notify the customer` resolves to the
        // workflow `To notify a customer:` defined in the .meridian file.
        // No fallbacks needed.
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        When an order has been on hold for more than 7 days, notify the customer.

        To notify a customer:
          complete.
        """
        let cfg = """
        === vocabulary ===
        customer is a kind of thing.
        order is a kind of thing.
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meridian",
            merconfigSource: cfg, merconfigFile: "test.merconfig"
        )
        #expect(out.contains("wait") || out.contains("Wait"),
                Comment(rawValue: "Expected wait in:\n\(String(out.prefix(3000)))"))
        // Confirm the trigger workflow really lowers the action — should
        // include a NotifyCustomer struct call (or similar).
        #expect(out.contains("NotifyCustomer") || out.contains("notify"),
                Comment(rawValue: "Expected trigger to lower notify-action in:\n\(String(out.prefix(3000)))"))
    }

    @Test("trigger with unresolved action throws by default")
    func triggerWithUnresolvedActionThrows() {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        When an order has been on hold for more than 7 days, do something completely unknown.
        """
        let cfg = """
        === vocabulary ===
        order is a kind of thing.
        """
        #expect(throws: (any Error).self) {
            try Compiler(options: .init()).compile(
                meridianSource: mer, meridianFile: "test.meridian",
                merconfigSource: cfg, merconfigFile: "test.merconfig"
            )
        }
    }

    @Test("trigger with unresolved action falls back when frontmatter opts in")
    func triggerWithUnresolvedActionFallsBack() throws {
        let mer = """
        ---
        name: test
        allow-fallbacks: unresolved-trigger-actions
        vocabulary: test.merconfig
        ---

        When an order has been on hold for more than 7 days, do something completely unknown.
        """
        let cfg = """
        === vocabulary ===
        order is a kind of thing.
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meridian",
            merconfigSource: cfg, merconfigFile: "test.merconfig"
        )
        // With the new emit-based trigger lowering, the trigger workflow
        // still compiles (waits for the event, fans out a `trigger.X.fired`
        // event) — but only because the policy allowed the unresolved action
        // check to be skipped. Without the fallback opt-in this would have
        // thrown. Confirm the trigger struct + fan-out emit are present.
        #expect(out.contains("WhenAnOrder") || out.contains("WhenOrderHas"),
                Comment(rawValue: "Expected trigger struct in:\n\(String(out.prefix(3000)))"))
        #expect(out.contains("trigger.") && out.contains(".fired"),
                Comment(rawValue: "Expected trigger fan-out event in:\n\(String(out.prefix(3000)))"))
    }
}
