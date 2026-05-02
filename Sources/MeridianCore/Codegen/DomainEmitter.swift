import Foundation
import ModelHike

// MARK: - DomainEmitter
//
// Phase 4 deliverable: emit typed Swift structs for each kind declared in the
// merconfig vocabulary. The compiler threads a `DomainDecl` into
// `SwiftEmitter.emitFile`, which delegates here.
//
// Generation rules:
//   * Scalar parents (`String|Number|Money|Date|DateTime|Boolean|Duration|
//     List|Reference`) → emit `public typealias Foo = …`. No protocol —
//     typealiases can't gain conformance.
//   * Semantic parents (`thing|event|action|tool|system|integration|artifact|
//     service|agent|model|dataset|storage|credential|policy|environment|
//     resource|metric|memory|process|message|signal|fact|role|verdict`) and
//     chained user kinds → emit BOTH:
//       1. `public protocol FooKind: <Parent> { var <prop>: T { get } … }`
//          where `<Parent>` is `Meridian<Base>` (e.g. `MeridianThing`,
//          `MeridianEvent`) for kinds whose parent is a semantic base, or
//          `<Parent>Kind` for kinds whose parent is another declared kind.
//          Property requirements list the kind's own properties only —
//          inherited ones come transitively through the parent protocol.
//       2. `public struct Foo: FooKind { var id: String; var <inherited>; …; var <own>; …; init(…) { … } }`
//          Inherited fields are flattened into the struct so a single value
//          can satisfy the entire protocol chain without juggling parent
//          instances.
//   * Properties of the form `which is one of (a, b, c)` become a top-level
//     `KindNameProperty` enum (e.g. `ValidationVerdict`, `CustomerStatus`).
//     Top-level (not nested) so generated code can write `ValidationVerdict.invalid`
//     without pre-pending the owning kind path.
//   * Every kind protocol composes `Hashable`, `Codable`, and `Sendable`
//     transitively via `Thing`, which is enough for `State`'s opaque traversal
//     to JSON-round-trip dotted lookups (`customer.email`).

public extension SwiftEmitter {

    // MARK: - Decl types

    struct DomainDecl {
        public struct Property {
            public let name: String
            public let type: PropertyType
            public init(_ name: String, _ type: PropertyType) {
                self.name = name; self.type = type
            }
        }

        public enum PropertyType {
            case scalar(String)        // "String", "Decimal", "Money", …
            case enumeration(String)   // top-level enum name, e.g. "ValidationVerdict"
            case list                  // "[Value]"
        }

        public struct Kind {
            public let name: String        // natural-language: "validation result"
            public let parent: String      // "thing" or another kind name (lower-cased)
            public let ownProperties: [Property]
            /// Flattened inheritance — all ancestor properties merged in declaration order.
            public let inheritedProperties: [Property]
            public init(name: String, parent: String,
                        ownProperties: [Property], inheritedProperties: [Property]) {
                self.name = name; self.parent = parent
                self.ownProperties = ownProperties
                self.inheritedProperties = inheritedProperties
            }
        }

        public struct Enumeration {
            public let typeName: String       // "ValidationVerdict"
            public let cases: [String]        // ["valid", "invalid"]
            public init(_ typeName: String, _ cases: [String]) {
                self.typeName = typeName; self.cases = cases
            }
        }

        public let kinds: [Kind]              // emit as struct or typealias
        public let enumerations: [Enumeration]
        public init(kinds: [Kind], enumerations: [Enumeration]) {
            self.kinds = kinds
            self.enumerations = enumerations
        }
    }

    // MARK: - Entry

    /// Emit the full Domain section: enums first (so they're visible to
    /// kinds that reference them), then per-kind output. Each kind picks one
    /// of three paths:
    ///
    ///   1. Scalar parent + no own properties → single `typealias`.
    ///   2. Has own properties OR is named as another kind's parent (chain
    ///      anchor) → `<KindName>Kind` protocol + conforming struct.
    ///   3. No own properties AND no descendants → struct only, conforming
    ///      directly to the resolved parent protocol (`Meridian<Base>` or
    ///      `<Parent>Kind`). The `<KindName>Kind` protocol is skipped because
    ///      it would be empty and add nothing the parent doesn't already
    ///      give us.
    func emitDomain(_ d: DomainDecl) -> StringTemplate {
        // Lookup table: enum-type-name → first-case identifier (e.g. "valid").
        // Used to default enum-typed fields in generated initializers.
        let firstCase: [String: String] = Dictionary(uniqueKeysWithValues: d.enumerations.compactMap { e in
            e.cases.first.map { (e.typeName, caseIdentifier($0)) }
        })
        // Set of declared kind names (lowercase, natural-language) so the
        // protocol-emit step can decide whether a parent name refers to
        // another generated kind (-> use its protocol) or to a scalar /
        // semantic built-in.
        let kindNames = Set(d.kinds.map { $0.name.lowercased() })
        // Set of declared kinds that are someone else's `parent`. These
        // **must** keep their protocol declaration even when they have no
        // own properties — descendant kinds chain through `<KindName>Kind`,
        // and structs can't be the inheritance anchor (they're concrete).
        let kindsWithDescendants: Set<String> = Set(
            d.kinds.compactMap { child -> String? in
                let parent = child.parent.lowercased()
                return kindNames.contains(parent) ? parent : nil
            }
        )
        return StringTemplate {
            "// MARK: - Domain types"
            ""
            for e in d.enumerations { emitEnum(e); "" }
            for k in d.kinds        { emitKind(k, enumFirstCase: firstCase, kindNames: kindNames, kindsWithDescendants: kindsWithDescendants);  "" }
        }
    }

    // MARK: - Enums

    private func emitEnum(_ e: DomainDecl.Enumeration) -> StringTemplate {
        let cases = e.cases.map(enumCaseDecl).joined(separator: ", ")
        return StringTemplate {
            "public enum \(e.typeName): String, Hashable, Codable, Sendable {"
            "    case \(cases)"
            "}"
        }
    }

    /// Map a natural-language enum case (`"under review"`) to a valid Swift
    /// case declaration: identifier = camelCase, raw value = original text.
    /// Single-word cases drop the explicit raw value (Swift defaults match).
    private func enumCaseDecl(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(" ") || trimmed.contains("-") {
            let identifier = caseIdentifier(trimmed)
            return "\(identifier) = \"\(trimmed)\""
        }
        return trimmed
    }

    private func caseIdentifier(_ raw: String) -> String {
        let parts = raw.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        guard let first = parts.first else { return raw }
        let head = first.lowercased()
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return ([head] + tail).joined()
    }

    // MARK: - Structs / typealiases

    /// Built-in scalar parents — kinds inheriting from these collapse to a
    /// `typealias` (no protocol, no struct). Reference is included here
    /// because at the value level it's a `String`-typed identifier; the spec
    /// places it alongside `String`/`Number`/etc. as a built-in primitive.
    private static let scalarParents: Set<String> = [
        "string", "number", "money", "date", "datetime", "boolean", "bool",
        "duration", "list", "reference"
    ]

    /// Map a parent name like "Number" to a Swift scalar type.
    private static let scalarTypeMap: [String: String] = [
        "string":    "String",
        "number":    "Decimal",
        "money":     "Money",
        "date":      "Date",
        "datetime":  "Date",
        "boolean":   "Bool",
        "bool":      "Bool",
        "duration":  "Duration",
        "reference": "String",
        // Untyped lists default to `[String]` so the containing struct stays
        // Codable. A typed-list syntax (`A foo has items, which is a list of …`)
        // is deferred to a later phase.
        "list":      "[String]"
    ]

    /// Built-in semantic bases — kinds inheriting from one of these get a
    /// `<KindName>Kind` protocol that composes the matching runtime protocol
    /// (`MeridianThing`, `MeridianEvent`, …). The mapping mirrors
    /// `Sources/MeridianRuntime/Domain/Thing.swift`. Vocabulary authors pick
    /// the base that matches the kind's role; the type system then carries
    /// that role through every workflow that references the kind.
    private static let semanticBases: [String: String] = [
        "thing":       "MeridianThing",
        "event":       "MeridianEvent",
        "action":      "MeridianAction",
        "tool":        "MeridianTool",
        "system":      "MeridianSystem",
        "integration": "MeridianIntegration",
        "artifact":    "MeridianArtifact",
        "service":     "MeridianService",
        "agent":       "MeridianAgent",
        "model":       "MeridianModel",
        "dataset":     "MeridianDataset",
        "storage":     "MeridianStorage",
        "credential":  "MeridianCredential",
        "policy":      "MeridianPolicy",
        "environment": "MeridianEnvironment",
        "resource":    "MeridianResource",
        "metric":      "MeridianMetric",
        "memory":      "MeridianMemory",
        "process":     "MeridianProcess",
        "message":     "MeridianMessage",
        "signal":      "MeridianSignal",
        "fact":        "MeridianFact",
        "role":        "MeridianRole",
        "verdict":     "MeridianVerdict",
    ]

    private func emitKind(_ k: DomainDecl.Kind,
                          enumFirstCase: [String: String],
                          kindNames: Set<String>,
                          kindsWithDescendants: Set<String>) -> StringTemplate {
        let parentLower = k.parent.lowercased()
        if Self.scalarParents.contains(parentLower) && k.ownProperties.isEmpty {
            return emitTypealias(k, scalar: Self.scalarTypeMap[parentLower] ?? "Value")
        }
        // An empty `<KindName>Kind` protocol adds nothing the parent doesn't
        // already give us — but we **must** keep it when descendants exist,
        // because `<DescendantKind>Kind: <KindName>Kind` needs a protocol to
        // chain through (structs can't be the inheritance anchor).
        let needsProtocol = !k.ownProperties.isEmpty
            || kindsWithDescendants.contains(k.name.lowercased())
        return emitProtocolAndStruct(
            k,
            enumFirstCase: enumFirstCase,
            kindNames: kindNames,
            emitProtocolDecl: needsProtocol
        )
    }

    private func emitTypealias(_ k: DomainDecl.Kind, scalar: String) -> StringTemplate {
        StringTemplate {
            "public typealias \(typeName(k.name)) = \(scalar)"
        }
    }

    /// Resolve the inherited protocol for a kind. Three cases:
    ///
    ///   1. The parent is one of the built-in semantic bases (`thing`,
    ///      `event`, `action`, …) → use the matching `Meridian<Base>` runtime
    ///      protocol so the type system carries the kind's role.
    ///   2. The parent is another declared kind → chain through its
    ///      `<ParentKind>Kind` protocol so the natural-language `is a kind of`
    ///      graph maps one-for-one onto Swift protocol inheritance.
    ///   3. The parent is unrecognised (e.g. a misspelt or unsupported word)
    ///      → fall back to `MeridianThing`. The compile still succeeds and
    ///      the kind picks up the runtime conformances; the diagnostic
    ///      surface is a separate concern handled at validation time.
    private func parentProtocol(for k: DomainDecl.Kind, kindNames: Set<String>) -> String {
        let parent = k.parent.lowercased()
        if let base = Self.semanticBases[parent] { return base }
        if kindNames.contains(parent) { return "\(typeName(k.parent))Kind" }
        return "MeridianThing"
    }

    private func emitProtocolAndStruct(_ k: DomainDecl.Kind,
                                       enumFirstCase: [String: String],
                                       kindNames: Set<String>,
                                       emitProtocolDecl: Bool) -> StringTemplate {
        let typeName       = typeName(k.name)
        let protocolName   = "\(typeName)Kind"
        let parentProto    = parentProtocol(for: k, kindNames: kindNames)
        // When the protocol is skipped (no own props, no descendants) the
        // struct conforms directly to the resolved parent — `Meridian<Base>`
        // for semantic-base parents, `<Parent>Kind` for chained kinds.
        let structConforms = emitProtocolDecl ? protocolName : parentProto
        let allProps       = k.inheritedProperties + k.ownProperties

        // Protocol requirements list **own** properties only — inherited
        // requirements come transitively through `parentProto`. This keeps the
        // generated protocol declarations a one-line-per-own-property summary
        // of the kind, which matches how the merconfig is written.
        let protoLines = k.ownProperties.map { p in
            "    var \(snakeToCamel(p.name)): \(swiftType(p.type)) { get }"
        }

        // Struct declares every flattened property (so a single instance
        // satisfies the protocol chain in one place) and gets a default-arg
        // init for terse construction in tests/fixtures.
        let propLines = allProps.map { "    public var \(snakeToCamel($0.name)): \(swiftType($0.type))" }
        let initParams = (["id: String = \"\""] + allProps.map { initParamDecl($0, enumFirstCase: enumFirstCase) })
            .joined(separator: ",\n        ")
        let initAssigns = (["self.id = id"] + allProps.map { "self.\(snakeToCamel($0.name)) = \(snakeToCamel($0.name))" })

        return StringTemplate {
            if emitProtocolDecl {
                "public protocol \(protocolName): \(parentProto) {"
                for line in protoLines { line }
                "}"
                ""
            }
            "public struct \(typeName): \(structConforms) {"
            "    public var id: String"
            for line in propLines { line }
            ""
            "    public init("
            "        \(initParams)"
            "    ) {"
            for assign in initAssigns { "        \(assign)" }
            "    }"
            "}"
        }
    }

    private func initParamDecl(_ p: DomainDecl.Property, enumFirstCase: [String: String]) -> String {
        "\(snakeToCamel(p.name)): \(swiftType(p.type)) = \(defaultExpr(p.type, enumFirstCase: enumFirstCase))"
    }

    private func swiftType(_ t: DomainDecl.PropertyType) -> String {
        switch t {
        case .scalar(let s):       return s
        case .enumeration(let e):  return e
        case .list:                return "[String]"
        }
    }

    /// Default expression for a typed property — keeps generated init signatures
    /// callable with the bare minimum, useful in fixtures/tests.
    private func defaultExpr(_ t: DomainDecl.PropertyType, enumFirstCase: [String: String]) -> String {
        switch t {
        case .scalar(let s):
            switch s {
            case "String":      return "\"\""
            case "Decimal":     return "Decimal(0)"
            case "Money":       return "Money(amount: 0, currency: \"USD\")"
            case "Date":        return "Date()"
            case "Bool":        return "false"
            case "Duration":    return "Duration.seconds(0)"
            case "[String]":    return "[]"
            default:            return "\(s)()"
            }
        case .enumeration(let e):
            // Use the first declared case (declaration order is preserved).
            if let first = enumFirstCase[e] { return ".\(first)" }
            return ".init(rawValue: \"\")!"
        case .list:             return "[]"
        }
    }

    /// "validation result" → "ValidationResult"
    private func typeName(_ raw: String) -> String {
        raw.split(whereSeparator: { $0 == " " || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
    }
}
