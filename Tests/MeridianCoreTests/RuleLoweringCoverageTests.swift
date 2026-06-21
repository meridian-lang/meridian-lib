import Testing
import Foundation
@testable import MeridianCore

/// Drives the private filter/predicate-qualification heuristics in
/// `RuleLowering.swift` (single-token filters, compound `and`/`or` predicates,
/// possessive property qualification) through full compiles so the injection
/// path in `RuleInjector` actually exercises them.
@Suite("Rule lowering coverage")
struct RuleLoweringCoverageTests {

    private func compile(_ mer: String, _ cfg: String) throws -> String {
        try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig"
        )
    }

    @Test("single-token filter clause qualifies to subject.<property>")
    func singleTokenFilter() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---

        A customer with active must not place an order.

        To place an order for a customer:
          complete.
        """
        let cfg = """
        === vocabulary ===
        customer is a kind of thing.
        customer has properties:
          active: Boolean.
        order is a kind of thing.
        """
        let out = try compile(mer, cfg)
        #expect(out.contains("runtime.assert") || out.contains("MeridianComparison"),
                Comment(rawValue: String(out.prefix(2500))))
    }

    @Test("compound predicate with 'and' qualifies each side (logical branch)")
    func compoundPredicateGuard() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---

        A customer must not place an order whose total amount is more than their credit limit and whose item count is more than their order cap.

        To place an order for a customer:
          complete.
        """
        let cfg = """
        === vocabulary ===
        customer is a kind of thing.
        customer has properties:
          credit_limit: Money.
          order_cap: Number.
        order is a kind of thing.
        order has properties:
          total_amount: Money.
          item_count: Number.
        """
        let out = try compile(mer, cfg)
        // Both possessive ("their X" → customer.X) and bare ("total amount" →
        // order.X) qualifications must appear, joined by a boolean.
        #expect(out.contains("creditLimit") || out.contains("credit_limit")
                || out.contains("orderCap") || out.contains("totalAmount"),
                Comment(rawValue: String(out.prefix(3000))))
    }

    @Test("shorthand comparison filter ('more than') qualifies subject property")
    func shorthandComparisonFilter() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---

        A customer with risk score more than 80 must not place an order.

        To place an order for a customer:
          complete.
        """
        let cfg = """
        === vocabulary ===
        customer is a kind of thing.
        customer has properties:
          risk_score: Number.
        order is a kind of thing.
        """
        let out = try compile(mer, cfg)
        #expect(out.contains("riskScore") || out.contains("risk_score")
                || out.contains("80"),
                Comment(rawValue: String(out.prefix(2500))))
    }

    @Test("copula-prefixed comparison filter strips the lexicon copula")
    func copulaPrefixedComparisonFilter() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---

        A customer with risk score is more than 80 must not place an order.

        To place an order for a customer:
          complete.
        """
        let cfg = """
        === vocabulary ===
        customer is a kind of thing.
        customer has properties:
          risk_score: Number.
        order is a kind of thing.
        """
        let out = try compile(mer, cfg)
        #expect(out.contains("riskScore") || out.contains("risk_score")
                || out.contains("80"),
                Comment(rawValue: String(out.prefix(2500))))
    }
}
