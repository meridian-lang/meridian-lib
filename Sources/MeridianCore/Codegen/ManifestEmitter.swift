import Foundation
import MeridianRuntime

// MARK: - ManifestEmitter
//
// Emits the {name}.meridian.manifest.json alongside the generated .swift file.
// See docs/05_CODEGEN_SPEC.md §7 for the manifest schema.

public struct ManifestEmitter {

    public struct Input {
        public let sourceFiles: [String]
        public let workflows: [IRWorkflow]
        public let constantsDecl: SwiftEmitter.ConstantsDecl?
        public let toolsUsed: [String]
        public let kindsUsed: [String]
        public let instancesRequired: [InstanceManifestEntry]
        public let sourceMap: [SourceMapEntry]
        /// B1: Optional file-level frontmatter metadata. When present, emitted
        /// as `meridian_skill` in the manifest JSON.
        public let metadata: FileMetadataAST?
        public let outline: [HeadingEntry]
        /// C5: Rule manifest entries derived from parsed rules.
        public let rules: [RuleManifestEntry]
        /// Universal sections: every markdown section of a sectioned document,
        /// executable and non-executable alike. Mandatory carrier — guaranteed
        /// to reach `meridian_skill.sections` so nothing is silently dropped.
        public let skillSections: [SkillSectionEntry]
        /// 2B: Checkable adjective definitions (`Definition: a <kind> is <adj>
        /// if …`). Emitted as `meridian_definitions` when non-empty.
        public let definitions: [DefinitionManifestEntry]
        /// 3A: Relations + their evaluation backing. `meridian_relations`.
        public let relations: [RelationManifestEntry]
        /// 3B: Verbs + conjugation + bound relation. `meridian_verbs`.
        public let verbs: [VerbManifestEntry]

        public init(
            sourceFiles: [String] = [],
            workflows: [IRWorkflow],
            constantsDecl: SwiftEmitter.ConstantsDecl? = nil,
            toolsUsed: [String] = [],
            kindsUsed: [String] = [],
            instancesRequired: [InstanceManifestEntry] = [],
            sourceMap: [SourceMapEntry] = [],
            metadata: FileMetadataAST? = nil,
            outline: [HeadingEntry] = [],
            rules: [RuleManifestEntry] = [],
            skillSections: [SkillSectionEntry] = [],
            definitions: [DefinitionManifestEntry] = [],
            relations: [RelationManifestEntry] = [],
            verbs: [VerbManifestEntry] = []
        ) {
            self.sourceFiles = sourceFiles
            self.workflows = workflows
            self.constantsDecl = constantsDecl
            self.toolsUsed = toolsUsed
            self.kindsUsed = kindsUsed
            self.instancesRequired = instancesRequired
            self.sourceMap = sourceMap
            self.metadata = metadata
            self.outline = outline
            self.rules = rules
            self.skillSections = skillSections
            self.definitions = definitions
            self.relations = relations
            self.verbs = verbs
        }
    }

    /// 3A: One relation + backing recorded for the manifest.
    public struct RelationManifestEntry: Encodable {
        public let name: String
        public let leftKind: String
        public let leftCardinality: String
        public let rightKind: String
        public let rightCardinality: String
        /// "property" or "tool".
        public let backing: String
        /// For a property backing: "<kind>.<path>"; for a tool backing: the tool id.
        public let via: String
        public let line: Int
        public init(name: String, leftKind: String, leftCardinality: String,
                    rightKind: String, rightCardinality: String,
                    backing: String, via: String, line: Int) {
            self.name = name; self.leftKind = leftKind; self.leftCardinality = leftCardinality
            self.rightKind = rightKind; self.rightCardinality = rightCardinality
            self.backing = backing; self.via = via; self.line = line
        }
    }

    /// 3B: One verb + conjugation + bound relation recorded for the manifest.
    public struct VerbManifestEntry: Encodable {
        public let base: String
        public let thirdPerson: String
        public let pastParticiple: String
        public let relation: String
        public let line: Int
        public init(base: String, thirdPerson: String, pastParticiple: String,
                    relation: String, line: Int) {
            self.base = base; self.thirdPerson = thirdPerson
            self.pastParticiple = pastParticiple; self.relation = relation; self.line = line
        }
    }

    /// 2B: One checkable adjective definition recorded for the manifest.
    public struct DefinitionManifestEntry: Encodable {
        public let adjective: String
        public let kind: String
        public let function: String
        public let line: Int
        public init(adjective: String, kind: String, function: String, line: Int) {
            self.adjective = adjective; self.kind = kind
            self.function = function; self.line = line
        }
    }

    /// One markdown section recorded for the manifest. `role` is the resolved
    /// executable role, the explicit `role:` of a marked-inert section, or
    /// `"inert"` for a bare `(( inert ))` heading. `executes` is false for any
    /// non-executable (documentation) section.
    public struct SkillSectionEntry: Encodable {
        public let heading: String
        public let role: String
        public let executes: Bool
        public let lines: [String]
        public let line: Int
        public init(heading: String, role: String, executes: Bool, lines: [String], line: Int) {
            self.heading = heading; self.role = role; self.executes = executes
            self.lines = lines; self.line = line
        }
    }

    public struct InstanceManifestEntry: Encodable {
        public let name: String
        public let kind: String
        public let properties: [String: PropertyManifestValue]
        public init(name: String, kind: String, properties: [String: PropertyManifestValue] = [:]) {
            self.name = name; self.kind = kind; self.properties = properties
        }
    }

    public struct PropertyManifestValue: Encodable {
        public let type: String
        public let value: String
        public init(type: String, value: String) { self.type = type; self.value = value }
    }

    public struct SourceMapEntry: Encodable {
        public let meridianLine: Int
        public let swiftLine: Int
        public init(meridianLine: Int, swiftLine: Int) {
            self.meridianLine = meridianLine; self.swiftLine = swiftLine
        }
        enum CodingKeys: String, CodingKey {
            case meridianLine = "meridian_line"
            case swiftLine = "swift_line"
        }
    }

    /// C5: Manifest entry for a single rule statement, recording its
    /// classification and whether it produces executable IR.
    public struct RuleManifestEntry: Encodable {
        public let text: String
        /// One of: "invariant", "parameterGuard", "precondition", "trigger",
        /// "permission", "unknown".
        public let kind: String
        /// true when the rule was classified and injected into one or more
        /// workflow bodies (or synthesised as a trigger workflow).
        public let executes: Bool
        public let source: SourceInfo

        public struct SourceInfo: Encodable {
            public let file: String
            public let line: Int
        }

        public init(text: String, kind: String, executes: Bool, source: SourceInfo) {
            self.text = text; self.kind = kind
            self.executes = executes; self.source = source
        }
    }

    public init() {}

    /// Emit the manifest as a pretty-printed JSON string.
    public func emit(_ input: Input) throws -> String {
        let dict = buildDict(input)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func buildDict(_ input: Input) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["meridian_ir_version"] = MERIDIAN_IR_VERSION
        dict["source_files"] = input.sourceFiles
        // B1: Embed frontmatter as skill-discovery metadata. The gate widens to
        // include recorded sections so a sectioned document's section table is
        // always emitted (mandatory, not best-effort).
        if input.metadata != nil || !input.outline.isEmpty || !input.skillSections.isEmpty {
            var skillDict: [String: Any] = [:]
            if let md = input.metadata {
                for (k, v) in md.entries {
                    skillDict[k.replacingOccurrences(of: "-", with: "_")] = v
                }
            }
            // `outline[].kind` follows the resolved role of the section it heads.
            let roleByLine = Dictionary(input.skillSections.map { ($0.line, $0.role) },
                                        uniquingKeysWith: { first, _ in first })
            if !input.outline.isEmpty {
                skillDict["outline"] = input.outline.map { outlineEntry($0, roleByLine: roleByLine) }
            }
            if !input.skillSections.isEmpty {
                skillDict["sections"] = input.skillSections.map { sec -> [String: Any] in
                    ["heading": sec.heading, "role": sec.role, "executes": sec.executes,
                     "lines": sec.lines, "line": sec.line]
                }
            }
            dict["meridian_skill"] = skillDict
        }
        dict["tools_used"] = input.toolsUsed
        dict["kinds_used"] = input.kindsUsed
        dict["instances_required"] = input.instancesRequired.map { inst -> [String: Any] in
            var d: [String: Any] = ["name": inst.name, "kind": inst.kind]
            if !inst.properties.isEmpty {
                d["properties"] = inst.properties.mapValues { ["type": $0.type, "value": $0.value] }
            }
            return d
        }
        if let c = input.constantsDecl {
            var consts: [String: Any] = [:]
            for e in c.entries {
                consts[e.name] = constantValue(e.value)
            }
            dict["constants"] = consts
        }
        dict["source_map"] = input.sourceMap.map { ["meridian_line": $0.meridianLine, "swift_line": $0.swiftLine] }
        if !input.definitions.isEmpty {
            dict["meridian_definitions"] = input.definitions.map { d -> [String: Any] in
                ["adjective": d.adjective, "kind": d.kind, "function": d.function, "line": d.line]
            }
        }
        if !input.relations.isEmpty {
            dict["meridian_relations"] = input.relations.map { r -> [String: Any] in
                [
                    "name": r.name,
                    "left_kind": r.leftKind, "left_cardinality": r.leftCardinality,
                    "right_kind": r.rightKind, "right_cardinality": r.rightCardinality,
                    "backing": r.backing, "via": r.via, "line": r.line
                ]
            }
        }
        if !input.verbs.isEmpty {
            dict["meridian_verbs"] = input.verbs.map { v -> [String: Any] in
                [
                    "base": v.base, "third_person": v.thirdPerson,
                    "past_participle": v.pastParticiple, "relation": v.relation, "line": v.line
                ]
            }
        }
        if !input.rules.isEmpty {
            dict["meridian_rules"] = input.rules.map { r -> [String: Any] in
                [
                    "text": r.text,
                    "kind": r.kind,
                    "executes": r.executes,
                    "source": ["file": r.source.file, "line": r.source.line]
                ]
            }
        }
        dict["workflows"] = input.workflows.map { wf -> [String: Any] in
            var d: [String: Any] = [
                "swift_struct": wf.structName,
                "source_name": wf.name,
                "mode": wf.mode == .strict ? "strict" : "lenient"
            ]
            d["parameters"] = wf.parameters.map { ["name": $0.name, "kind": $0.kind.name] }
            return d
        }
        return dict
    }

    private func outlineEntry(_ entry: HeadingEntry, roleByLine: [Int: String]) -> [String: Any] {
        ["level": entry.level, "text": entry.text, "line": entry.line,
         "kind": roleByLine[entry.line] ?? entry.kind]
    }

    private func constantValue(_ lit: IRLiteral) -> Any {
        switch lit {
        case .string(let s): return s
        case .number(let n): return (n as NSDecimalNumber).doubleValue
        case .boolean(let b): return b
        case .money(let amount, let currency): return ["amount": (amount as NSDecimalNumber).doubleValue, "currency": currency]
        case .duration(let d): return d.components.seconds
        case .date(let d): return ISO8601DateFormatter.meridianFormatter.string(from: d)
        case .dateTime(let d): return ISO8601DateFormatter.meridianFormatter.string(from: d)
        case .enumValue(let v, let kind): return ["value": v, "kind": kind]
        }
    }
}
