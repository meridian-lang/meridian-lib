import Foundation

enum BuiltinScalarTypes {
    static let swiftTypeNames: [String: String] = [
        "string": "String",
        "text": "String",
        "number": "Decimal",
        "money": "Money",
        "date": "Date",
        "datetime": "Date",
        "boolean": "Bool",
        "bool": "Bool",
        "duration": "Duration",
        "reference": "String",
        "list": "[String]",
    ]

    static let scalarParents: Set<String> = Set(swiftTypeNames.keys)

    static func swiftTypeName(for raw: String) -> String? {
        swiftTypeNames[raw.lowercased()]
    }

    /// Resolve a merconfig property type AST to a Swift type string for domain
    /// emission (`[Order]`, `Order?`, `String`, …).
    static func resolvePropertySwiftType(
        _ type: PropertyTypeAST,
        knownKindNames: Set<String>
    ) -> String {
        switch type {
        case .defaulted:
            return "String"
        case .enumeration:
            preconditionFailure("internal: enumeration property routed through propertyToDecl")
        case .explicit(let raw):
            return resolveTypePhrase(raw, knownKindNames: knownKindNames)
        case .listOf(let element):
            let elem = resolvePropertySwiftType(element, knownKindNames: knownKindNames)
            return "[\(elem)]"
        case .optional(let inner):
            let innerSwift = resolvePropertySwiftType(inner, knownKindNames: knownKindNames)
            if innerSwift.hasSuffix("?") { return innerSwift }
            return "\(innerSwift)?"
        }
    }

    private static func resolveTypePhrase(_ raw: String, knownKindNames: Set<String>) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if lower == "list" {
            return "[String]"
        }
        if let scalar = swiftTypeName(for: trimmed) {
            return scalar
        }
        if knownKindNames.contains(lower) {
            return IdentifierNaming.pascalCase(trimmed)
        }
        return IdentifierNaming.pascalCase(trimmed)
    }
}
