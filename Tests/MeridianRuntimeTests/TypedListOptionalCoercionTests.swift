import Testing
@testable import MeridianRuntime

@Suite("Typed list and optional Value coercion")
struct TypedListOptionalCoercionTests {

    @Test("null coerces to Swift Optional.none")
    func nullToOptional() throws {
        #expect(try Value.null.coerce(to: String?.self) == nil)
        #expect(try Value.null.coerce(to: Int?.self) == nil)
    }

    @Test("list coerces to [String] when elements are strings")
    func listToStringArray() throws {
        let v = Value.list([.string("a"), .string("b")])
        #expect(try v.coerce(to: [String].self) == ["a", "b"])
    }

    @Test("list still coerces to [Value]")
    func listToValueArray() throws {
        let items: [Value] = [.string("x")]
        let v = Value.list(items)
        #expect(try v.coerce(to: [Value].self) == items)
    }
}
