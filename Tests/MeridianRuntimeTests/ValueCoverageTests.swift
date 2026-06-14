import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Value — equality, hashing, descriptions, accessors")
struct ValueCoverageTests {
    @Test("equality across every case and mismatch default")
    func equality() {
        #expect(Value.string("a") == .string("a"))
        #expect(Value.number(1) == .number(1))
        #expect(Value.boolean(true) == .boolean(true))
        #expect(Value.money(Money(amount: 1, currency: "USD")) == .money(Money(amount: 1, currency: "USD")))
        #expect(Value.duration(.seconds(1)) == .duration(.seconds(1)))
        let d = Date()
        #expect(Value.date(d) == .date(d))
        #expect(Value.dateTime(d) == .dateTime(d))
        #expect(Value.enumValue("a", kind: "k") == .enumValue("a", kind: "k"))
        #expect(Value.record(["x": .number(1)]) == .record(["x": .number(1)]))
        #expect(Value.list([.number(1)]) == .list([.number(1)]))
        #expect(Value.reference("r") == .reference("r"))
        #expect(Value.null == .null)
        #expect(Value.wrap(42) == .wrap(42))
        #expect(Value.string("a") != .number(1))   // default mismatch arm
    }

    @Test("hashing is stable and distinguishes cases")
    func hashing() {
        var set: Set<Value> = []
        let all: [Value] = [.string("a"), .number(1), .boolean(true),
                            .money(Money(amount: 1, currency: "USD")), .duration(.seconds(1)),
                            .date(Date(timeIntervalSince1970: 0)), .dateTime(Date(timeIntervalSince1970: 0)),
                            .enumValue("e", kind: "k"), .record(["a": .null]), .list([.null]),
                            .reference("r"), .null, .wrap(7)]
        for v in all { set.insert(v) }
        #expect(set.count == all.count)
    }

    @Test("description, jsonEncodableObject, scalarDescription cover every case")
    func renderings() {
        #expect(Value.string("hi").description == "\"hi\"")
        #expect(Value.string("hi").scalarDescription == "hi")
        #expect(Value.boolean(false).scalarDescription == "false")
        #expect(Value.null.scalarDescription == "")
        #expect(Value.record(["a": .null]).description.hasPrefix("<Record"))
        #expect(Value.list([.null]).description == "<List count=1>")
        #expect(Value.reference("r").description == "<Ref r>")

        #expect(Value.string("s").jsonEncodableObject as? String == "s")
        #expect(Value.boolean(true).jsonEncodableObject as? Bool == true)
        #expect(Value.null.jsonEncodableObject is NSNull)
        let rec = Value.record(["n": .number(2)]).jsonEncodableObject as? [String: Any]
        #expect(rec?["n"] != nil)
        let list = Value.list([.string("x")]).jsonEncodableObject as? [Any]
        #expect(list?.count == 1)
        #expect((Value.money(.init(amount: 3, currency: "EUR")).jsonEncodableObject as? String)?.contains("EUR") == true)
        // scalarDescription default arm (composite)
        #expect(Value.list([]).scalarDescription.hasPrefix("<List"))
    }

    @Test("asList and member dot-path traversal")
    func accessors() {
        #expect(Value.list([.number(1)]).asList?.count == 1)
        #expect(Value.string("x").asList == nil)
        let nested = Value.record(["a": .record(["b": .string("deep")])])
        #expect(nested.member("a.b") == .string("deep"))
        #expect(nested.member("a.missing") == nil)
        #expect(nested.member("") == nested)
        #expect(Value.string("x").member("a") == nil)
    }

    @Test("Money compares and describes")
    func money() {
        #expect(Money(amount: 1, currency: "USD") < Money(amount: 2, currency: "USD"))
        #expect(Money(amount: 5, currency: "GBP").description.contains("GBP"))
    }

    @Test("number/money construction helpers")
    func helpers() {
        #expect(Value.number(Int8(3)) == .number(Decimal(3)))
        #expect(Value.number(Float(1.5)) == .number(Decimal(1.5)))
        if case .money(let m) = Value.money(Decimal(9)) { #expect(m.currency == "USD") }
        else { Issue.record("expected money") }
    }
}

@Suite("AnyHashableSendable + coercion + Value.from + AnyCodable")
struct ValueCoercionCoverageTests {
    @Test("opaque unwrap and Encodable capture")
    func opaque() throws {
        let box = AnyHashableSendable(123)
        #expect(box.unwrap(as: Int.self) == 123)
        #expect(box.unwrap(as: String.self) == nil)
        // Int is Encodable, so the Encodable init is selected and the captured
        // closure round-trips through AnyCodable's encoder.
        let encodableBox = AnyHashableSendable(7)
        let data = try JSONEncoder().encode(AnyCodable(.opaque(encodableBox)))
        #expect(!data.isEmpty)
    }

    @Test("coerce string to String, URL, Date")
    func coerceString() throws {
        #expect(try Value.string("hello").coerce(to: String.self) == "hello")
        #expect(try Value.string("https://x.com").coerce(to: URL.self).scheme == "https")
        let date = try Value.string("2026-01-01T00:00:00Z").coerce(to: Date.self)
        #expect(date.timeIntervalSince1970 > 0)
    }

    @Test("coerce number to Int, Double, Float, Decimal")
    func coerceNumber() throws {
        #expect(try Value.number(42).coerce(to: Int.self) == 42)
        #expect(try Value.number(Decimal(1.5)).coerce(to: Double.self) == 1.5)
        #expect(try Value.number(2).coerce(to: Float.self) == 2)
        #expect(try Value.number(3).coerce(to: Decimal.self) == 3)
    }

    @Test("coerce money, duration, boolean, date, enum, reference")
    func coerceMisc() throws {
        #expect(try Value.money(.init(amount: 5, currency: "USD")).coerce(to: Money.self).amount == 5)
        #expect(try Value.money(.init(amount: 5, currency: "USD")).coerce(to: Decimal.self) == 5)
        #expect(try Value.boolean(true).coerce(to: Bool.self))
        #expect(try Value.duration(.seconds(3)).coerce(to: Double.self) == 3)
        let d = Date()
        #expect(try Value.date(d).coerce(to: Date.self) == d)
        #expect(try Value.dateTime(d).coerce(to: Date.self) == d)
        #expect(try Value.enumValue("open", kind: "status").coerce(to: String.self) == "open")
        #expect(try Value.reference("id1").coerce(to: String.self) == "id1")
    }

    @Test("coerce list and record")
    func coerceComposite() throws {
        #expect(try Value.list([.number(1)]).coerce(to: [Value].self).count == 1)
        struct Pt: Codable, Equatable { let x: Int; let y: Int }
        let rec = Value.record(["x": .number(1), "y": .number(2)])
        #expect(try rec.coerce(to: Pt.self) == Pt(x: 1, y: 2))
    }

    @Test("an impossible coercion throws cannotCoerce")
    func coerceFailure() {
        #expect(throws: ValueError.self) {
            _ = try Value.null.coerce(to: Int.self)
        }
    }

    @Test("Value.from bridges every primitive overload")
    func valueFrom() {
        #expect(Value.from("s") == .string("s"))
        #expect(Value.from(true) == .boolean(true))
        #expect(Value.from(3) == .number(Decimal(3)))
        #expect(Value.from(1.5) == .number(Decimal(1.5)))
        #expect(Value.from(Decimal(7)) == .number(7))
        #expect(Value.from(Money(amount: 1, currency: "USD")) == .money(.init(amount: 1, currency: "USD")))
        #expect(Value.from(.string("x")) == .string("x"))
        // generic opaque overload
        #expect(Value.from(UInt8(9)) == .wrap(UInt8(9)))
    }

    @Test("AnyCodable round-trips scalars, lists, records")
    func anyCodable() throws {
        let original = Value.record([
            "s": .string("hi"), "n": .number(2), "b": .boolean(true),
            "nil": .null, "list": .list([.number(1), .string("a")]),
        ])
        let data = try JSONEncoder().encode(AnyCodable(original))
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        if case .record(let dict) = decoded.value {
            #expect(dict["s"] == .string("hi"))
            #expect(dict["b"] == .boolean(true))
            #expect(dict["nil"] == .null)
        } else {
            Issue.record("expected record round-trip")
        }
    }
}
