import Foundation
import Testing
@testable import MeridianCore

@Suite("Suggester")
struct SuggesterTests {

    @Test("closest finds a near match within budget")
    func closestWithinBudget() {
        let s = Suggester()
        #expect(s.closest("chargePaymnt", among: ["chargePayment", "refundPayment"]) == "chargePayment")
        #expect(s.closest("validte", among: ["validate", "value"]) == "validate")
    }

    @Test("closest is case-insensitive but returns original spelling")
    func closestCaseInsensitive() {
        let s = Suggester()
        #expect(s.closest("CHARGEPAYMENT", among: ["chargePayment"]) == "chargePayment")
    }

    @Test("closest returns nil when nothing is within budget")
    func closestNilWhenFar() {
        let s = Suggester()
        #expect(s.closest("zzzzzz", among: ["chargePayment", "refund"]) == nil)
    }

    @Test("ranked orders candidates by closeness")
    func rankedOrders() {
        let s = Suggester()
        let ranked = s.ranked("validate order", among: ["validate an order", "refund order", "ship order"], limit: 3)
        #expect(ranked.first == "validate an order")
    }

    @Test("defaultBudget scales with target length")
    func budgetScales() {
        #expect(Suggester.defaultBudget(for: "ab") == 2)
        #expect(Suggester.defaultBudget(for: String(repeating: "x", count: 30)) == 10)
    }

    @Test("closestAmbiguous returns alternates for tied near-misses")
    func closestAmbiguousTies() {
        let s = Suggester()
        let match = s.closestAmbiguous("paymnt", among: ["payment", "paymet"])
        #expect(match?.primary == "payment")
        #expect(match?.alternates.contains("paymet") == true)
    }

    @Test("closestAmbiguous is unambiguous when the leader is clearly closer")
    func closestAmbiguousClearWinner() {
        let s = Suggester()
        let match = s.closestAmbiguous("chargePaymnt", among: ["chargePayment", "refundPayment"])
        #expect(match?.primary == "chargePayment")
        #expect(match?.alternates.isEmpty == true)
    }

    @Test("closestAmbiguous breaks distance ties using token overlap")
    func closestAmbiguousOverlapTiebreak() {
        let s = Suggester()
        let match = s.closestAmbiguous("validate order", among: ["validate or", "validate order or"], budget: 6)
        #expect(match?.primary == "validate order or")
    }

    @Test("ranked prefers higher token overlap before edit distance")
    func rankedOverlapBeforeDistance() {
        let s = Suggester()
        let ranked = s.ranked("validate order", among: ["validate or", "validate order or"], limit: 2)
        #expect(ranked.first == "validate order or")
    }

    @Test("levenshtein basic distances")
    func levenshtein() {
        #expect(Suggester.levenshtein("kitten", "sitting") == 3)
        #expect(Suggester.levenshtein("", "abc") == 3)
        #expect(Suggester.levenshtein("abc", "abc") == 0)
    }
}
