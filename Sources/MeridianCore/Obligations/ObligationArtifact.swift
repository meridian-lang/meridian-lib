import Foundation
import MeridianRuntime

public let OBLIGATION_ARTIFACT_SCHEMA_VERSION = "1"
public let OBLIGATION_SEMANTICS_VERSION = "0.3"
public let PROOF_IR_VERSION = "1"

public enum ObligationProofKind: String, Sendable, Codable {
    case unreachability
    case invariant
    case coverage
    case statisticalMonitor = "statistical-monitor"
}

public enum ObligationStatus: String, Sendable, Codable {
    case active
}

public enum ObligationDischargeStatus: String, Sendable, Codable, CaseIterable {
    case proved
    case disproved
    case unknown
    case unsupported
}

public struct ObligationSourceSpan: Sendable, Codable {
    public let file: String
    public let line: Int
    public let column: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}

public struct ObligationStableScope: Sendable, Codable {
    public let kind: String
    public let name: String?
    public let stablePath: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case name
        case stablePath = "stable_path"
    }
}

public struct ObligationDischargePlaceholder: Sendable, Codable {
    public let status: ObligationDischargeStatus
    public let witnessSchema: [String: String]
    public let counterexampleSchema: [String: String]

    enum CodingKeys: String, CodingKey {
        case status
        case witnessSchema = "witness_schema"
        case counterexampleSchema = "counterexample_schema"
    }

    public static let placeholder = ObligationDischargePlaceholder(
        status: .unknown,
        witnessSchema: [
            "trace_slice": "ordered trace record ids supporting discharge",
            "event_tags": "closed TraceTag set referenced by the obligation",
            "payload_hashes": "payloadHash values for cited events",
        ],
        counterexampleSchema: [
            "trace_slice": "minimal violating trace slice",
            "violating_event": "first falsifying trace record id",
            "witness_fields": "redacted payload fields per capture policy",
        ]
    )
}

public struct ObligationArtifact: Sendable, Codable {
    public let id: String
    public let sourceSpan: ObligationSourceSpan
    public let scope: ObligationStableScope
    public let kind: ObligationProofKind
    public let status: ObligationStatus
    public let blocking: Bool
    public let canonicalEnglish: String
    public let canonicalIRHash: String
    public let conditionProofIR: String?
    public let actionProofIR: String?
    public let discharge: ObligationDischargePlaceholder
    public let traceEventTags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case sourceSpan = "source_span"
        case scope
        case kind
        case status
        case blocking
        case canonicalEnglish = "canonical_english"
        case canonicalIRHash = "canonical_ir_hash"
        case conditionProofIR = "condition_proof_ir"
        case actionProofIR = "action_proof_ir"
        case discharge
        case traceEventTags = "trace_event_tags"
    }
}

public enum ObligationArtifactBuilder {

    public static func proofKind(for norm: NormIR) -> ObligationProofKind {
        switch norm.kind {
        case .prohibition: return .unreachability
        case .obligation: return .invariant
        case .permission: return .coverage
        }
    }

    public static func proofKind(for assert: AssertIR) -> ObligationProofKind {
        if assert.monitored { return .statisticalMonitor }
        return .invariant
    }

    public static func stableScope(_ scope: NormScope) -> ObligationStableScope {
        switch scope {
        case .skill:
            return ObligationStableScope(kind: "skill", name: nil, stablePath: nil)
        case .workflow(let name):
            return ObligationStableScope(kind: "workflow", name: name, stablePath: nil)
        case .section(let stablePath):
            return ObligationStableScope(kind: "section", name: nil, stablePath: stablePath)
        case .kind(let name):
            return ObligationStableScope(kind: "kind", name: name, stablePath: nil)
        }
    }

    public static func from(
        norm: NormIR,
        verbalizer: Verbalizer,
        sourceFile: String,
        includeProofIR: Bool
    ) throws -> ObligationArtifact {
        let payload = CanonicalIRSerializer.normSemanticPayload(norm)
        let hash = try CanonicalJSON.sha256Hex(for: payload)
        return ObligationArtifact(
            id: norm.id,
            sourceSpan: ObligationSourceSpan(
                file: sourceFile,
                line: norm.sourceRange.startLine,
                column: norm.sourceRange.startColumn
            ),
            scope: stableScope(norm.scope),
            kind: proofKind(for: norm),
            status: .active,
            blocking: norm.blocking,
            canonicalEnglish: verbalizer.verbalize(norm),
            canonicalIRHash: hash,
            conditionProofIR: includeProofIR ? norm.condition.map {
                try? CanonicalIRSerializer.proofIRJSONString(CanonicalIRSerializer.expressionValue($0))
            }.flatMap { $0 } : nil,
            actionProofIR: includeProofIR ? try actionProofIR(for: norm) : nil,
            discharge: .placeholder,
            traceEventTags: traceTags(for: norm)
        )
    }

    public static func from(
        assert: AssertIR,
        obligationId: String,
        scope: NormScope,
        verbalizer: Verbalizer,
        sourceFile: String,
        includeProofIR: Bool
    ) throws -> ObligationArtifact {
        let payload = CanonicalIRSerializer.contractAssertSemanticPayload(
            condition: assert.condition,
            scope: scope,
            monitored: assert.monitored
        )
        let hash = try CanonicalJSON.sha256Hex(for: payload)
        let conditionValue = CanonicalIRSerializer.expressionValue(assert.condition)
        return ObligationArtifact(
            id: obligationId,
            sourceSpan: ObligationSourceSpan(
                file: sourceFile,
                line: assert.sourceRange.startLine,
                column: assert.sourceRange.startColumn
            ),
            scope: stableScope(scope),
            kind: proofKind(for: assert),
            status: .active,
            blocking: assert.blocking,
            canonicalEnglish: verbalizer.verbalize(assert),
            canonicalIRHash: hash,
            conditionProofIR: includeProofIR ? try CanonicalIRSerializer.proofIRJSONString(conditionValue) : nil,
            actionProofIR: nil,
            discharge: .placeholder,
            traceEventTags: traceTags(for: assert.condition)
        )
    }

    private static func actionProofIR(for norm: NormIR) throws -> String? {
        guard let pattern = norm.actionPattern else { return nil }
        let constraints = pattern.argumentConstraints
            .sorted { $0.path < $1.path }
            .map { constraint in
                Value.record([
                    "path": .string(constraint.path),
                    "op": .string(String(describing: constraint.op)),
                    "value": CanonicalIRSerializer.expressionValue(constraint.value),
                ])
            }
        let value: Value = .record([
            "tool_id": .string(IdentifierNaming.methodize(pattern.toolID)),
            "argument_constraints": .list(constraints),
        ])
        return try CanonicalIRSerializer.proofIRJSONString(value)
    }

    private static func traceTags(for norm: NormIR) -> [String] {
        switch norm.kind {
        case .prohibition, .permission:
            return ["invoked", "violated", "prevented"]
        case .obligation:
            return ["asserted", "assert-failed", "violated"]
        }
    }

    private static func traceTags(for expression: IRExpression) -> [String] {
        if case .traceStatistical = expression {
            return ["asserted", "assert-failed", "violated"]
        }
        if containsSinceLast(expression) {
            return ["asserted", "assert-failed", "violated", "committed"]
        }
        return ["asserted", "assert-failed"]
    }

    private static func containsSinceLast(_ expression: IRExpression) -> Bool {
        switch expression {
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind { return true }
            return false
        case .logical(_, let operands):
            return operands.contains(where: containsSinceLast)
        case .quantified(let quantifier):
            return quantifier.body.map(containsSinceLast) ?? false
        default:
            return false
        }
    }
}
