import CryptoKit
import Foundation
import MeridianRuntime

public let NORM_ID_PREFIX_LENGTH = 16

public struct NormIdRegistry: Sendable {
    private var prefixToFullHash: [String: String] = [:]

    public init() {}

    public mutating func register(id: String, fullHash: String) throws {
        let prefix = String(id.dropFirst("OBL-".count))
        guard prefix.count == NORM_ID_PREFIX_LENGTH else { return }
        if let existing = prefixToFullHash[prefix], existing != fullHash {
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .normIdCollision,
                    message: "norm id prefix collision: \(id)",
                    range: .unknown,
                    help: "Two distinct norms hashed to the same OBL- prefix. Reword one norm's scope or condition so the semantic hash differs.")
            ])
        }
        prefixToFullHash[prefix] = fullHash
    }
}

public enum NormId {

    public static func make(from payload: [String: Value], registry: inout NormIdRegistry) throws -> String {
        let data = try CanonicalJSON.data(for: payload)
        let fullHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let prefix = String(fullHash.prefix(NORM_ID_PREFIX_LENGTH))
        let id = "OBL-\(prefix)"
        try registry.register(id: id, fullHash: fullHash)
        return id
    }

    public static func make(from norm: NormIR, registry: inout NormIdRegistry) throws -> String {
        try make(from: CanonicalIRSerializer.normSemanticPayload(norm), registry: &registry)
    }

    public static func finalize(_ norms: [NormIR]) throws -> [NormIR] {
        var registry = NormIdRegistry()
        return try norms.map { norm in
            let id = try make(from: norm, registry: &registry)
            return NormIR(
                id: id,
                kind: norm.kind,
                scope: norm.scope,
                actionPattern: norm.actionPattern,
                condition: norm.condition,
                blocking: norm.blocking,
                sourceRange: norm.sourceRange,
                originalText: norm.originalText
            )
        }
    }

    public static func forDefaultDeny(
        toolID: String,
        scope: NormScope,
        registry: inout NormIdRegistry
    ) throws -> String {
        try make(
            from: CanonicalIRSerializer.defaultDenySemanticPayload(toolID: toolID, scope: scope),
            registry: &registry
        )
    }

    public static func forContractAssert(
        condition: IRExpression,
        scope: NormScope,
        monitored: Bool,
        registry: inout NormIdRegistry
    ) throws -> String {
        try make(
            from: CanonicalIRSerializer.contractAssertSemanticPayload(
                condition: condition,
                scope: scope,
                monitored: monitored
            ),
            registry: &registry
        )
    }
}

public enum ContractAssertDetector {

    public static func isContractAssert(_ assert: AssertIR) -> Bool {
        if assert.monitored { return true }
        return expressionQualifies(assert.condition)
    }

    private static func expressionQualifies(_ expression: IRExpression) -> Bool {
        switch expression {
        case .comparison(_, let op, _):
            if case .matchesPattern = op { return true }
            return false
        case .logical(_, let operands):
            return operands.contains(where: expressionQualifies)
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind { return true }
            return false
        case .quantified(let quantifier):
            if let body = quantifier.body { return expressionQualifies(body) }
            return false
        case .definitionPredicate(_, let subject):
            return expressionQualifies(subject)
        default:
            return false
        }
    }
}

public enum NormIdStamper {

    public static func stampContractAsserts(in workflows: [IRWorkflow]) throws -> [IRWorkflow] {
        var registry = NormIdRegistry()
        var seenNormIDs = Set<String>()
        for workflow in workflows {
            for norm in workflow.norms {
                seenNormIDs.insert(norm.id)
                let fullHash = try CanonicalJSON.sha256Hex(for: CanonicalIRSerializer.normSemanticPayload(norm))
                try registry.register(id: norm.id, fullHash: fullHash)
            }
        }
        return try workflows.map { workflow in
            let scope: NormScope = .workflow(workflow.structName)
            let body = try stampBlock(workflow.body, scope: scope, seenNormIDs: seenNormIDs, registry: &registry)
            return IRWorkflow(
                name: workflow.name,
                parameters: workflow.parameters,
                body: body,
                mode: workflow.mode,
                sourceFile: workflow.sourceFile,
                sourceRange: workflow.sourceRange,
                explicitStructName: workflow.explicitStructName,
                allowsDiscretion: workflow.allowsDiscretion,
                skillName: workflow.skillName,
                skillVersionHash: workflow.skillVersionHash,
                runtimeTraceConfiguration: workflow.runtimeTraceConfiguration,
                norms: workflow.norms
            )
        }
    }

    private static func stampBlock(
        _ block: IRBlock,
        scope: NormScope,
        seenNormIDs: Set<String>,
        registry: inout NormIdRegistry
    ) throws -> IRBlock {
        let statements = try block.statements.map { stmt in
            try stampPrimitive(stmt, scope: scope, seenNormIDs: seenNormIDs, registry: &registry)
        }
        return IRBlock(statements: statements, sourceRange: block.sourceRange)
    }

    private static func stampPrimitive(
        _ primitive: IRPrimitive,
        scope: NormScope,
        seenNormIDs: Set<String>,
        registry: inout NormIdRegistry
    ) throws -> IRPrimitive {
        switch primitive {
        case .assert(var assertIR):
            if assertIR.normID == nil || !seenNormIDs.contains(assertIR.normID ?? ""),
               ContractAssertDetector.isContractAssert(assertIR) {
                let id = try NormId.forContractAssert(
                    condition: assertIR.condition,
                    scope: scope,
                    monitored: assertIR.monitored,
                    registry: &registry
                )
                assertIR = AssertIR(
                    condition: assertIR.condition,
                    message: assertIR.message,
                    otherwiseAction: assertIR.otherwiseAction,
                    monitored: assertIR.monitored,
                    cadence: assertIR.cadence,
                    blocking: assertIR.blocking,
                    normID: id,
                    violationDisposition: assertIR.violationDisposition,
                    sourceRange: assertIR.sourceRange,
                    stableStepPath: assertIR.stableStepPath
                )
            }
            if let otherwise = assertIR.otherwiseAction {
                return .assert(AssertIR(
                    condition: assertIR.condition,
                    message: assertIR.message,
                    otherwiseAction: try stampBlock(
                        otherwise, scope: scope, seenNormIDs: seenNormIDs, registry: &registry
                    ),
                    monitored: assertIR.monitored,
                    cadence: assertIR.cadence,
                    blocking: assertIR.blocking,
                    normID: assertIR.normID,
                    violationDisposition: assertIR.violationDisposition,
                    sourceRange: assertIR.sourceRange,
                    stableStepPath: assertIR.stableStepPath
                ))
            }
            return .assert(assertIR)
        case .branch(let branch):
            return .branch(BranchIR(
                condition: branch.condition,
                thenBlock: try stampBlock(branch.thenBlock, scope: scope, seenNormIDs: seenNormIDs, registry: &registry),
                unknownBlock: try branch.unknownBlock.map {
                    try stampBlock($0, scope: scope, seenNormIDs: seenNormIDs, registry: &registry)
                },
                elseBlock: try branch.elseBlock.map {
                    try stampBlock($0, scope: scope, seenNormIDs: seenNormIDs, registry: &registry)
                },
                unknownPolicy: branch.unknownPolicy,
                authoredForm: branch.authoredForm,
                deonticGuard: branch.deonticGuard,
                sourceRange: branch.sourceRange,
                stableStepPath: branch.stableStepPath
            ))
        case .iterate(let iterate):
            return .iterate(IterateIR(
                mode: iterate.mode,
                body: try stampBlock(iterate.body, scope: scope, seenNormIDs: seenNormIDs, registry: &registry),
                source: iterate.source,
                sourceRange: iterate.sourceRange,
                stableStepPath: iterate.stableStepPath
            ))
        case .recover(let recover):
            return .recover(RecoverIR(
                pattern: recover.pattern,
                handler: try stampBlock(recover.handler, scope: scope, seenNormIDs: seenNormIDs, registry: &registry),
                attachedTo: try stampBlock(recover.attachedTo, scope: scope, seenNormIDs: seenNormIDs, registry: &registry),
                sourceRange: recover.sourceRange,
                stableStepPath: recover.stableStepPath
            ))
        case .simultaneously(let sim):
            return .simultaneously(SimultaneouslyIR(
                branches: try sim.branches.map {
                    try stampBlock($0, scope: scope, seenNormIDs: seenNormIDs, registry: &registry)
                },
                detached: sim.detached,
                sourceRange: sim.sourceRange,
                stableStepPath: sim.stableStepPath
            ))
        default:
            return primitive
        }
    }
}
