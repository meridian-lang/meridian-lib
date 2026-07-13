import Foundation
import Testing
@testable import MeridianCore

@Suite("BuiltinScalarTypes coverage")
struct BuiltinScalarTypesCoverageTests {

    @Test("swiftTypeName resolves known scalars and rejects unknown")
    func swiftTypeNameLookup() {
        #expect(BuiltinScalarTypes.swiftTypeName(for: "String") == "String")
        #expect(BuiltinScalarTypes.swiftTypeName(for: "boolean") == "Bool")
        #expect(BuiltinScalarTypes.swiftTypeName(for: "money") == "Money")
        #expect(BuiltinScalarTypes.swiftTypeName(for: "widget") == nil)
        #expect(BuiltinScalarTypes.scalarParents.contains("duration"))
    }

    @Test("resolvePropertySwiftType covers defaulted/list/optional/explicit/kind")
    func resolvePropertySwiftTypeMatrix() {
        let kinds: Set<String> = ["order", "page"]
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(.defaulted, knownKindNames: kinds) == "String")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(.explicit("text"), knownKindNames: kinds) == "String")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(.explicit("list"), knownKindNames: kinds) == "[String]")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(.explicit("order"), knownKindNames: kinds) == "Order")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(.explicit("Widget"), knownKindNames: kinds) == "Widget")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(
            .listOf(.explicit("string")), knownKindNames: kinds) == "[String]")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(
            .optional(.explicit("boolean")), knownKindNames: kinds) == "Bool?")
        #expect(BuiltinScalarTypes.resolvePropertySwiftType(
            .optional(.optional(.explicit("string"))), knownKindNames: kinds) == "String?")
    }
}
