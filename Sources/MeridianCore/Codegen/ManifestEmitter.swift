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
            rules: [RuleManifestEntry] = []
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
        // B1: Embed frontmatter as skill-discovery metadata.
        if input.metadata != nil || !input.outline.isEmpty {
            var skillDict: [String: Any] = [:]
            if let md = input.metadata {
                for (k, v) in md.entries {
                    skillDict[k.replacingOccurrences(of: "-", with: "_")] = v
                }
            }
            if !input.outline.isEmpty {
                skillDict["outline"] = input.outline.map(outlineEntry)
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

    private func outlineEntry(_ entry: HeadingEntry) -> [String: Any] {
        ["level": entry.level, "text": entry.text, "line": entry.line, "kind": entry.kind]
    }

    private func constantValue(_ lit: IRLiteral) -> Any {
        switch lit {
        case .string(let s): return s
        case .number(let n): return (n as NSDecimalNumber).doubleValue
        case .boolean(let b): return b
        case .money(let amount, let currency): return ["amount": (amount as NSDecimalNumber).doubleValue, "currency": currency]
        case .duration(let d): return d.components.seconds
        case .date(let d): return ISO8601DateFormatter().string(from: d)
        case .dateTime(let d): return ISO8601DateFormatter().string(from: d)
        case .enumValue(let v, let kind): return ["value": v, "kind": kind]
        }
    }
}
