import Foundation

/// Companion IR metadata emitted beside generated Swift (`*.meridian.ir.json`).
public struct IRSidecarEmitter {
    private let trace: ParserTrace

    public init(trace: ParserTrace = .shared) {
        self.trace = trace
    }

    public struct Entry: Codable, Sendable, Equatable {
        public let meridianLine: Int
        public let swiftLine: Int?
        public let stableStepPath: String?
        public let primitive: String
        public let canonical: String

        enum CodingKeys: String, CodingKey {
            case meridianLine = "meridian_line"
            case swiftLine = "swift_line"
            case stableStepPath = "stable_step_path"
            case primitive
            case canonical
        }
    }

    public struct Document: Codable, Sendable {
        public let irVersion: String
        public let sourceFile: String
        public let swiftFile: String
        public let entries: [Entry]

        enum CodingKeys: String, CodingKey {
            case irVersion = "ir_version"
            case sourceFile = "source_file"
            case swiftFile = "swift_file"
            case entries
        }
    }

    public func emit(
        workflows: [IRWorkflow],
        verbalizer: Verbalizer,
        sourceFile: String,
        swiftFile: String,
        sourceMap: [ManifestEmitter.SourceMapEntry]
    ) throws -> String {
        try trace.phase("irSidecar") {
            trace.log(.codegen, "emit IR sidecar for \(sourceFile) → \(swiftFile)")
            var mapByMeridianLine: [Int: Int] = [:]
            for entry in sourceMap {
                mapByMeridianLine[entry.meridianLine] = entry.swiftLine
            }
            var entries: [Entry] = []
            for workflow in workflows {
                try collectEntries(
                    from: workflow.body,
                    workflow: workflow,
                    verbalizer: verbalizer,
                    mapByMeridianLine: mapByMeridianLine,
                    into: &entries
                )
            }
            entries.sort {
                if $0.meridianLine != $1.meridianLine { return $0.meridianLine < $1.meridianLine }
                return ($0.stableStepPath ?? "") < ($1.stableStepPath ?? "")
            }
            let document = Document(
                irVersion: MERIDIAN_IR_VERSION,
                sourceFile: sourceFile,
                swiftFile: swiftFile,
                entries: entries
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            guard let text = String(data: data, encoding: .utf8) else {
                throw CompilerError.diagnostics([
                    Diagnostic.error(.internalError, message: "failed to encode IR sidecar", range: .init(file: sourceFile, line: 1, column: 1))
                ])
            }
            trace.log(.codegen, "IR sidecar: \(entries.count) entr\(entries.count == 1 ? "y" : "ies")")
            return text
        }
    }

    private func collectEntries(
        from block: IRBlock,
        workflow: IRWorkflow,
        verbalizer: Verbalizer,
        mapByMeridianLine: [Int: Int],
        into entries: inout [Entry]
    ) throws {
        for primitive in block.statements {
            let line = primitive.sourceRange.startLine
            let canonical: String
            switch primitive {
            case .assert(let ir):
                canonical = verbalizer.verbalize(ir)
            default:
                canonical = verbalizer.verbalize(primitive)
            }
            entries.append(Entry(
                meridianLine: line,
                swiftLine: mapByMeridianLine[line],
                stableStepPath: primitive.stableStepPath,
                primitive: primitiveKind(primitive),
                canonical: canonical
            ))
            switch primitive {
            case .branch(let ir):
                try collectEntries(from: ir.thenBlock, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                if let elseBlock = ir.elseBlock {
                    try collectEntries(from: elseBlock, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                }
                if let unknownBlock = ir.unknownBlock {
                    try collectEntries(from: unknownBlock, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                }
            case .iterate(let ir):
                try collectEntries(from: ir.body, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
            case .assert(let ir):
                if let otherwise = ir.otherwiseAction {
                    try collectEntries(from: otherwise, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                }
            case .recover(let ir):
                try collectEntries(from: ir.handler, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                try collectEntries(from: ir.attachedTo, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
            case .simultaneously(let ir):
                for branch in ir.branches {
                    try collectEntries(from: branch, workflow: workflow, verbalizer: verbalizer, mapByMeridianLine: mapByMeridianLine, into: &entries)
                }
            default:
                break
            }
        }
    }

    private func primitiveKind(_ primitive: IRPrimitive) -> String {
        switch primitive {
        case .invoke: return "invoke"
        case .bind(let ir): return ir.isRebind ? "rebind" : "bind"
        case .branch: return "branch"
        case .emit: return "emit"
        case .complete: return "complete"
        case .commit: return "commit"
        case .iterate: return "iterate"
        case .assert: return "assert"
        case .recover: return "recover"
        case .wait: return "wait"
        case .simultaneously: return "simultaneously"
        case .aiJudgment: return "aiJudgment"
        case .aiAutonomy: return "aiAutonomy"
        }
    }
}

/// Explain generated Swift using a companion `.meridian.ir.json` sidecar.
public enum ExplainSwiftRunner {
    public static func explain(swiftSource: String, sidecarJSON: String) throws -> String {
        let decoder = JSONDecoder()
        guard let data = sidecarJSON.data(using: .utf8) else {
            throw ExplainSwiftError.invalidSidecar("sidecar is not UTF-8")
        }
        let document = try decoder.decode(IRSidecarEmitter.Document.self, from: data)
        let entriesBySwiftLine = Dictionary(grouping: document.entries.compactMap { entry -> (Int, IRSidecarEmitter.Entry)? in
            guard let swiftLine = entry.swiftLine else { return nil }
            return (swiftLine, entry)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }

        var lines: [String] = []
        let swiftLines = swiftSource.components(separatedBy: "\n")
        for (index, line) in swiftLines.enumerated() {
            let swiftLine = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("// L"),
                  let meridianLine = Int(trimmed.dropFirst(4).split(separator: " ").first ?? "")
            else { continue }
            let matches = entriesBySwiftLine[swiftLine]
                ?? document.entries.filter { $0.meridianLine == meridianLine && $0.swiftLine == nil }
            guard let entry = matches.first else { continue }
            lines.append("L\(entry.meridianLine) swift:\(swiftLine) [\(entry.primitive)]: \(entry.canonical)")
        }
        if lines.isEmpty {
            throw ExplainSwiftError.noMappings("no Swift provenance comments matched IR sidecar entries")
        }
        return lines.joined(separator: "\n")
    }
}

public enum ExplainSwiftError: Error, Sendable {
    case invalidSidecar(String)
    case noMappings(String)
}
