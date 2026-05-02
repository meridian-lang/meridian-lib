import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Value coercion")
struct ValueCoercionTests {

    @Test("string → String")
    func stringToString() throws {
        let v = Value.string("hello")
        #expect(try v.coerce(to: String.self) == "hello")
    }

    @Test("number → Int")
    func numberToInt() throws {
        let v = Value.number(42)
        #expect(try v.coerce(to: Int.self) == 42)
    }

    @Test("number → Double")
    func numberToDouble() throws {
        let v = Value.number(Decimal(3.14))
        let d = try v.coerce(to: Double.self)
        #expect(abs(d - 3.14) < 0.001)
    }

    @Test("boolean → Bool")
    func booleanToBool() throws {
        #expect(try Value.boolean(true).coerce(to: Bool.self) == true)
        #expect(try Value.boolean(false).coerce(to: Bool.self) == false)
    }

    @Test("money → Money")
    func moneyToMoney() throws {
        let m = Money(amount: 100, currency: "USD")
        let v = Value.money(m)
        let result = try v.coerce(to: Money.self)
        #expect(result.amount == 100)
        #expect(result.currency == "USD")
    }

    @Test("enumValue → String")
    func enumValueToString() throws {
        let v = Value.enumValue("approved", kind: "ApprovalVerdict")
        #expect(try v.coerce(to: String.self) == "approved")
    }

    @Test("reference → String")
    func referenceToString() throws {
        let v = Value.reference("obj-123")
        #expect(try v.coerce(to: String.self) == "obj-123")
    }

    @Test("opaque unwrap via coerce")
    func opaqueCoerce() throws {
        struct MyType: Hashable, Sendable { let x: Int }
        let t = MyType(x: 7)
        let v = Value.opaque(AnyHashableSendable(t))
        let result = try v.coerce(to: MyType.self)
        #expect(result.x == 7)
    }

    @Test("mismatched coerce throws ValueError")
    func mismatchedCoerce() throws {
        let v = Value.boolean(true)
        #expect(throws: ValueError.self) {
            try v.coerce(to: Int.self)
        }
    }

    @Test("Value equality")
    func valueEquality() throws {
        #expect(Value.string("a") == Value.string("a"))
        #expect(Value.string("a") != Value.string("b"))
        #expect(Value.number(1) == Value.number(1))
        #expect(Value.null == Value.null)
    }

    @Test("Value construction helpers")
    func constructionHelpers() throws {
        let s = Value.string("hi")
        if case .string(let str) = s { #expect(str == "hi") }

        let n = Value.number(5 as Int)
        if case .number(let dec) = n { #expect(dec == 5) }

        let m = Value.money(Decimal(50), currency: "EUR")
        if case .money(let money) = m {
            #expect(money.amount == 50)
            #expect(money.currency == "EUR")
        }
    }
}
