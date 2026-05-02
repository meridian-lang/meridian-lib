import Testing
import Foundation
@testable import MeridianRuntime

// MARK: - State tests

@Suite("State")
struct StateTests {

    @Test("bind and get a string value")
    func bindAndGetString() throws {
        var state = State()
        state.bind("name", .string("Alice"))
        let v = state.get("name")
        #expect(v == .string("Alice"))
    }

    @Test("bind a typed value directly")
    func bindTypedValue() throws {
        var state = State()
        state.bind("count", 42 as Int)
        let v = state.get("count")
        #expect(v != nil)
    }

    @Test("rebind replaces existing binding")
    func rebind() throws {
        var state = State()
        state.bind("x", .number(1))
        state.rebind("x", .number(2))
        let v = state.get("x")
        #expect(v == .number(2))
    }

    @Test("get returns nil for unknown key")
    func getMissing() throws {
        let state = State()
        #expect(state.get("nonexistent") == nil)
    }

    @Test("require throws for missing key")
    func requireMissing() throws {
        let state = State()
        #expect(throws: StateError.self) {
            try state.require("missing", as: String.self)
        }
    }

    @Test("require succeeds for present key")
    func requirePresent() throws {
        var state = State()
        state.bind("msg", .string("hello"))
        let v = try state.require("msg", as: String.self)
        #expect(v == "hello")
    }

    @Test("snapshot and restore round-trips bindings")
    func snapshotRestore() throws {
        var state = State()
        state.bind("a", .string("foo"))
        state.bind("b", .number(99))
        let snap = state.snapshot()

        var state2 = State()
        state2.restore(from: snap)
        #expect(state2.get("a") == .string("foo"))
        #expect(state2.get("b") == .number(99))
    }

    @Test("allBindings returns all keys")
    func allBindings() throws {
        var state = State()
        state.bind("x", .boolean(true))
        state.bind("y", .string("z"))
        let all = state.allBindings()
        #expect(all.count == 2)
        #expect(all["x"] == .boolean(true))
    }

    // MARK: - Opaque traversal (Phase 4 invariant)

    /// Domain types are bound as opaque and dotted lookups go through Codable.
    /// Generated codegen relies on `state.get("order.totalAmount")` returning
    /// the underlying scalar (or a Money-shaped record), and then
    /// `MeridianComparison.numeric` extracting the number out of either form.
    @Test("opaque traversal yields a value for nested Codable fields")
    func opaqueTraversalDottedLookup() throws {
        struct Order: Hashable, Codable, Sendable {
            var id: String
            var totalAmount: Money
        }
        var state = State()
        state.bind("order", Order(id: "o-1", totalAmount: Money(amount: 250, currency: "USD")))

        // Top-level scalar field.
        #expect(state.get("order.id") != nil)
        // Nested struct field — the prior implementation lost the Encodable
        // conformance through `Any as? Encodable` and silently returned nil
        // here, breaking every generated `state.get("order.totalAmount")`.
        #expect(state.get("order.totalAmount") != nil)
    }

    @Test("opaque-traversed Money compares numerically against a bare number")
    func opaqueMoneyComparison() throws {
        struct Order: Hashable, Codable, Sendable {
            var id: String
            var totalAmount: Money
        }
        var state = State()
        state.bind("order", Order(id: "o-1", totalAmount: Money(amount: 250, currency: "USD")))
        state.bind("available", Value.number(100))

        // The traversal exposes Money as a `Value.record` (Codable default
        // encoding); the comparison helper still treats it as numeric.
        #expect(MeridianComparison.lt(state.get("available"), state.get("order.totalAmount")))
        #expect(MeridianComparison.gt(state.get("order.totalAmount"), state.get("available")))
    }
}
