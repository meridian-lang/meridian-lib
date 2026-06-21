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
        // Untyped lists default to `[String]` so generated domain structs stay
        // Codable. A typed-list syntax is deferred to a later phase.
        "list": "[String]",
    ]

    static let scalarParents: Set<String> = Set(swiftTypeNames.keys)

    static func swiftTypeName(for raw: String) -> String? {
        swiftTypeNames[raw.lowercased()]
    }
}
