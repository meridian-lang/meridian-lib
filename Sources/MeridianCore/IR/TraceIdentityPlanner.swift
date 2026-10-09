import Foundation
import MeridianRuntime

enum TraceIdentityPlanner {
    static func skillVersionHash(
        meridianSource: String,
        vocabularies: [Compiler.VocabularyInput],
        rulebooks: [RulebookInput]
    ) throws -> String {
        let payload: [String: Value] = [
            "ir_version": .string(MERIDIAN_IR_VERSION),
            "source": .string(normalizeText(meridianSource)),
            "vocabularies": .list(vocabularies.map {
                .record([
                    "name": .string($0.name),
                    "file": .string($0.file),
                    "source": .string(normalizeText($0.source))
                ])
            }),
            "rulebooks": .list(rulebooks.map {
                .record([
                    "name": .string($0.name),
                    "file": .string($0.file),
                    "source": .string(normalizeText($0.source))
                ])
            })
        ]
        return try CanonicalJSON.sha256Hex(for: payload)
    }

    static func runtimeTraceConfiguration(
        from config: MerConfigFile,
        skillName: String,
        skillVersionHash: String,
        workflows: [IRWorkflow] = []
    ) -> RuntimeTraceConfiguration {
        let ast = config.traceConfiguration
        // D8/SEM-4-07: `.auto` resolves at compile time to `.failClosed` so
        // `Runtime` never sees an unresolved `.auto` (which would otherwise
        // behave as fail-open). Explicit `.failOpen` / `.failClosed` are
        // preserved verbatim.
        let declaredPolicy = ast.storeFailurePolicy?.value ?? .auto
        let resolvedPolicy: TraceStoreFailurePolicy = declaredPolicy == .auto
            ? .failClosed
            : declaredPolicy
        let trace = TraceConfiguration(
            retention: ast.retention?.value ?? .seconds(60 * 60 * 24 * 30),
            payloadLimit: ast.payloadLimit?.value,
            usuallyThreshold: ast.usuallyThreshold?.value ?? 0.9,
            rarelyThreshold: ast.rarelyThreshold?.value ?? 0.1,
            sampleFloor: ast.sampleFloor?.value ?? 20,
            defaultMonitorCadence: ast.defaultMonitorCadence?.value ?? .seconds(60 * 60 * 24),
            profile: ast.profile?.value ?? .development,
            storeFailurePolicy: resolvedPolicy,
            deploymentZone: ast.deploymentZone?.value ?? "UTC",
            crossSkillAllowList: ast.crossSkillAllowList?.value ?? [],
            stateHistoryRetention: ast.stateHistoryRetention?.value ?? false
        )
        let toolPolicies = config.tools.reduce(into: ast.toolCapturePolicies.mapValues(\.value)) { result, tool in
            if let capture = tool.capturePolicy {
                result[tool.methodName] = capture
            }
        }
        return RuntimeTraceConfiguration(
            store: ast.store?.value ?? .memory,
            trace: trace,
            skillIdentity: TraceSkillIdentity(name: skillName, versionHash: skillVersionHash),
            toolCapturePolicies: toolPolicies,
            storePath: ast.storePath?.value
        )
    }

    static func annotate(
        workflows: [IRWorkflow],
        skillSections: [SkillSectionRecord],
        runtimeTraceConfiguration: RuntimeTraceConfiguration
    ) throws -> [IRWorkflow] {
        let sectionIndex = SectionIndex(skillSections: skillSections)
        return try workflows.map { workflow in
            var ordinalByCandidate: [String: Int] = [:]
            let body = try annotateBlock(
                workflow.body,
                workflow: workflow,
                sectionIndex: sectionIndex,
                nestedRoles: [],
                ordinalByCandidate: &ordinalByCandidate
            )
            return IRWorkflow(
                name: workflow.name,
                parameters: workflow.parameters,
                body: body,
                mode: workflow.mode,
                sourceFile: workflow.sourceFile,
                sourceRange: workflow.sourceRange,
                explicitStructName: workflow.explicitStructName,
                allowsDiscretion: workflow.allowsDiscretion,
                skillName: runtimeTraceConfiguration.skillIdentity.name,
                skillVersionHash: runtimeTraceConfiguration.skillIdentity.versionHash,
                runtimeTraceConfiguration: runtimeTraceConfiguration,
                norms: workflow.norms
            )
        }
    }

    private static func annotateBlock(
        _ block: IRBlock,
        workflow: IRWorkflow,
        sectionIndex: SectionIndex,
        nestedRoles: [String],
        ordinalByCandidate: inout [String: Int]
    ) throws -> IRBlock {
        let statements = try block.statements.map { primitive in
            let section = sectionIndex.section(for: primitive.sourceRange.startLine)
            let rolePath = [section.role] + nestedRoles
            let fingerprint = try primitiveFingerprint(primitive)
            let base = "/" + ([workflow.structName, section.slug] + rolePath + [fingerprint]).joined(separator: "/")
            let ordinal = ordinalByCandidate[base, default: 0] + 1
            ordinalByCandidate[base] = ordinal
            let stableStepPath = ordinal == 1 ? base : "\(base)~\(ordinal)"
            return try annotatePrimitive(
                primitive,
                workflow: workflow,
                sectionIndex: sectionIndex,
                stableStepPath: stableStepPath,
                ordinalByCandidate: &ordinalByCandidate
            )
        }
        return IRBlock(statements: statements, sourceRange: block.sourceRange)
    }

    private static func annotatePrimitive(
        _ primitive: IRPrimitive,
        workflow: IRWorkflow,
        sectionIndex: SectionIndex,
        stableStepPath: String,
        ordinalByCandidate: inout [String: Int]
    ) throws -> IRPrimitive {
        switch primitive {
        case .invoke(let ir):
            return .invoke(InvokeIR(
                toolID: ir.toolID,
                arguments: ir.arguments,
                resultBinding: ir.resultBinding,
                comment: ir.comment,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .bind(let ir):
            return .bind(BindIR(
                name: ir.name,
                expression: ir.expression,
                isRebind: ir.isRebind,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .branch(let ir):
            let thenBlock = try annotateBlock(
                ir.thenBlock,
                workflow: workflow,
                sectionIndex: sectionIndex,
                nestedRoles: ["branch.then"],
                ordinalByCandidate: &ordinalByCandidate
            )
            let elseBlock = try ir.elseBlock.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["branch.else"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .branch(BranchIR(
                condition: ir.condition,
                thenBlock: thenBlock,
                unknownBlock: try ir.unknownBlock.map {
                    try annotateBlock(
                        $0,
                        workflow: workflow,
                        sectionIndex: sectionIndex,
                        nestedRoles: ["branch.unknown"],
                        ordinalByCandidate: &ordinalByCandidate
                    )
                },
                elseBlock: elseBlock,
                unknownPolicy: ir.unknownPolicy,
                authoredForm: ir.authoredForm,
                deonticGuard: ir.deonticGuard,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .iterate(let ir):
            return .iterate(IterateIR(
                mode: ir.mode,
                body: try annotateBlock(
                    ir.body,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["iterate.body"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                source: ir.source,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .assert(let ir):
            let otherwiseAction = try ir.otherwiseAction.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["assert.otherwise"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .assert(AssertIR(
                condition: ir.condition,
                message: ir.message,
                otherwiseAction: otherwiseAction,
                monitored: ir.monitored,
                cadence: ir.cadence,
                blocking: ir.blocking,
                normID: ir.normID,
                violationDisposition: ir.violationDisposition,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .emit(let ir):
            return .emit(EmitIR(
                eventID: ir.eventID,
                payload: ir.payload,
                strict: ir.strict,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .wait(let ir):
            return .wait(WaitIR(
                condition: ir.condition,
                timeout: ir.timeout,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .commit(let ir):
            return .commit(CommitIR(
                label: ir.label,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .recover(let ir):
            return .recover(RecoverIR(
                pattern: ir.pattern,
                handler: try annotateBlock(
                    ir.handler,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["recover.handler"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                attachedTo: try annotateBlock(
                    ir.attachedTo,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["recover.body"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .simultaneously(let ir):
            let branches = try ir.branches.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["simultaneously.branch"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .simultaneously(SimultaneouslyIR(
                branches: branches,
                detached: ir.detached,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .aiJudgment(let ir):
            return .aiJudgment(AIJudgmentIR(
                text: ir.text,
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                sourceRange: ir.sourceRange,
                guidance: ir.guidance,
                stableStepPath: stableStepPath,
                outputKind: ir.outputKind
            ))
        case .aiAutonomy(let ir):
            return .aiAutonomy(AIAutonomyIR(
                text: ir.text,
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                autonomy: ir.autonomy,
                sourceRange: ir.sourceRange,
                guidance: ir.guidance,
                stableStepPath: stableStepPath,
                outputKind: ir.outputKind
            ))
        case .complete(let ir):
            return .complete(CompleteIR(
                reason: ir.reason,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        }
    }

    private static func primitiveFingerprint(_ primitive: IRPrimitive) throws -> String {
        try IRFingerprint.sha256(of: primitive)
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

private struct SectionIndex {
    private let sections: [SectionEntry]

    init(skillSections: [SkillSectionRecord]) {
        // `SkillSectionRecord.line` is the heading's line, not the only line
        // owned by the section. Markdown section ownership continues through
        // the line before the next heading, so sorting the starts gives us the
        // same half-open ranges without persisting a redundant end line.
        self.sections = skillSections
            .map {
                SectionEntry(
                    slug: Self.slugify($0.heading),
                    role: $0.role.isEmpty ? "procedure" : $0.role,
                    startLine: $0.line
                )
            }
            .sorted { $0.startLine < $1.startLine }
    }

    func section(for line: Int) -> (slug: String, role: String) {
        guard line > 0 else { return ("root", "procedure") }
        if let section = sections.last(where: { $0.startLine <= line }) {
            return (section.slug, section.role)
        }
        return ("root", "procedure")
    }

    private struct SectionEntry {
        let slug: String
        let role: String
        let startLine: Int
    }

    private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let raw = String(scalars)
        let collapsed = raw
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "root" : collapsed
    }
}
