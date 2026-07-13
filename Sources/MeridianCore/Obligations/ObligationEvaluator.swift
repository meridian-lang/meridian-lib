import Foundation
import MeridianRuntime

public enum ObligationCompliance: String, Sendable, Codable, Equatable {
    case compliant
    case violated
    case indeterminate
}

public struct ObligationEvaluationResult: Sendable, Equatable {
    public let obligationId: String
    public let compliance: ObligationCompliance
    public let witnessEventIDs: [String]
    public let disposition: String?

    public init(
        obligationId: String,
        compliance: ObligationCompliance,
        witnessEventIDs: [String],
        disposition: String? = nil
    ) {
        self.obligationId = obligationId
        self.compliance = compliance
        self.witnessEventIDs = witnessEventIDs.sorted()
        self.disposition = disposition
    }
}

/// Independent second path: evaluates obligation artifacts against a stored trace
/// per SEM-7-01 trace meaning. Does not consult generated guard decisions.
public enum ObligationEvaluator {

    public static func evaluate(
        document: ObligationDocument,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [ObligationEvaluationResult] {
        var results: [ObligationEvaluationResult] = []
        for artifact in document.obligations {
            results.append(try await evaluate(
                artifact: artifact,
                document: document,
                store: store,
                context: context
            ))
        }
        return results.sorted { $0.obligationId < $1.obligationId }
    }

    public static func evaluate(
        artifact: ObligationArtifact,
        document: ObligationDocument,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> ObligationEvaluationResult {
        switch artifact.kind {
        case .unreachability:
            return try await evaluateUnreachability(artifact: artifact, store: store, context: context)
        case .invariant:
            return try await evaluateInvariant(artifact: artifact, store: store, context: context)
        case .coverage:
            return try await evaluateCoverage(artifact: artifact, document: document, store: store, context: context)
        case .statisticalMonitor:
            return try await evaluateStatisticalMonitor(artifact: artifact, store: store, context: context)
        }
    }

    // MARK: - Unreachability (prohibition)

    private static func evaluateUnreachability(
        artifact: ObligationArtifact,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> ObligationEvaluationResult {
        guard let pattern = ProofIRReader.actionPattern(from: artifact.actionProofIR) else {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .indeterminate,
                witnessEventIDs: []
            )
        }
        let invokes = try await matchingInvokes(pattern: pattern, store: store, context: context)
        if !invokes.isEmpty {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .violated,
                witnessEventIDs: invokes.map(\.id),
                disposition: "observed"
            )
        }
        let prevented = try await preventedViolations(
            targetObligationId: artifact.id,
            toolID: pattern.toolID,
            store: store,
            context: context
        )
        return ObligationEvaluationResult(
            obligationId: artifact.id,
            compliance: .compliant,
            witnessEventIDs: prevented.map(\.id),
            disposition: prevented.isEmpty ? nil : ViolationDisposition.prevented.rawValue
        )
    }

    // MARK: - Invariant (obligation / contract assert)

    private static func evaluateInvariant(
        artifact: ObligationArtifact,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> ObligationEvaluationResult {
        if let query = ProofIRReader.traceStatisticalQuery(from: artifact.conditionProofIR) {
            let replay = try await TraceEvaluator.replay(statistical: query, store: store, context: context)
            return resultFromTruthValue(artifact.id, replay)
        }
        if let query = ProofIRReader.traceTemporalQuery(from: artifact.conditionProofIR) {
            let replay = try await TraceEvaluator.replay(temporal: query, store: store, context: context)
            return resultFromTruthValue(artifact.id, replay)
        }

        let observed = try await observedViolations(
            targetObligationId: artifact.id,
            store: store,
            context: context
        )
        if !observed.isEmpty {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .violated,
                witnessEventIDs: observed.map(\.id),
                disposition: ViolationDisposition.observed.rawValue
            )
        }

        let assertFailures = try await assertFailures(
            matching: artifact,
            store: store,
            context: context
        )
        if !assertFailures.isEmpty {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .violated,
                witnessEventIDs: assertFailures.map(\.id),
                disposition: ViolationDisposition.observed.rawValue
            )
        }

        let asserted = try await assertedPasses(
            matching: artifact,
            store: store,
            context: context
        )
        return ObligationEvaluationResult(
            obligationId: artifact.id,
            compliance: .compliant,
            witnessEventIDs: asserted.map(\.id)
        )
    }

    // MARK: - Coverage (permission / default-deny)

    private static func evaluateCoverage(
        artifact: ObligationArtifact,
        document: ObligationDocument,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> ObligationEvaluationResult {
        let permissionPatterns = document.obligations
            .filter { $0.kind == .coverage }
            .compactMap { ProofIRReader.actionPattern(from: $0.actionProofIR) }

        guard !permissionPatterns.isEmpty else {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .indeterminate,
                witnessEventIDs: []
            )
        }

        let invokes = try await allInvokes(store: store, context: context)
        var uncovered: [TraceRecord] = []
        for invoke in invokes {
            let covered = permissionPatterns.contains { coversInvoke(pattern: $0, record: invoke) }
            if !covered {
                uncovered.append(invoke)
            }
        }

        if uncovered.isEmpty {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .compliant,
                witnessEventIDs: []
            )
        }

        var stillViolating: [TraceRecord] = []
        for invoke in uncovered {
            let tool = payloadToolID(from: invoke) ?? invoke.subject ?? ""
            let prevented = try await preventedViolations(
                targetObligationId: artifact.id,
                toolID: tool,
                store: store,
                context: context
            )
            if prevented.isEmpty {
                stillViolating.append(invoke)
            }
        }

        if stillViolating.isEmpty {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .compliant,
                witnessEventIDs: uncovered.map(\.id),
                disposition: ViolationDisposition.prevented.rawValue
            )
        }

        return ObligationEvaluationResult(
            obligationId: artifact.id,
            compliance: .violated,
            witnessEventIDs: stillViolating.map(\.id),
            disposition: ViolationDisposition.observed.rawValue
        )
    }

    // MARK: - Statistical monitor

    private static func evaluateStatisticalMonitor(
        artifact: ObligationArtifact,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> ObligationEvaluationResult {
        guard let query = ProofIRReader.traceStatisticalQuery(from: artifact.conditionProofIR) else {
            return ObligationEvaluationResult(
                obligationId: artifact.id,
                compliance: .indeterminate,
                witnessEventIDs: []
            )
        }
        let replay = try await TraceEvaluator.replay(statistical: query, store: store, context: context)
        return resultFromTruthValue(artifact.id, replay)
    }

    // MARK: - Trace helpers

    private static func resultFromTruthValue(
        _ obligationId: String,
        _ replay: TraceReplayResult
    ) -> ObligationEvaluationResult {
        switch replay.truthValue {
        case .true:
            return ObligationEvaluationResult(
                obligationId: obligationId,
                compliance: .compliant,
                witnessEventIDs: replay.witnessEventIDs
            )
        case .false:
            return ObligationEvaluationResult(
                obligationId: obligationId,
                compliance: .violated,
                witnessEventIDs: replay.witnessEventIDs,
                disposition: ViolationDisposition.observed.rawValue
            )
        case .indeterminate:
            return ObligationEvaluationResult(
                obligationId: obligationId,
                compliance: .indeterminate,
                witnessEventIDs: replay.witnessEventIDs
            )
        }
    }

    private static func matchingInvokes(
        pattern: ActionPatternIR,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let invokes = try await allInvokes(store: store, context: context)
        return invokes.filter { coversInvoke(pattern: pattern, record: $0) }
    }

    private static func allInvokes(
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.invoked])
        )
    }

    private static func preventedViolations(
        targetObligationId: String,
        toolID: String,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.violated])
        )
        return records.filter { record in
            guard isPreventedViolation(record) else { return false }
            if let id = payloadObligationId(from: record), id == targetObligationId { return true }
            if let tool = payloadToolID(from: record), normalizeToolID(tool) == normalizeToolID(toolID) { return true }
            if let subject = record.subject, normalizeToolID(subject) == normalizeToolID(toolID) { return true }
            return false
        }
    }

    private static func observedViolations(
        targetObligationId: String,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.violated])
        )
        return records.filter { record in
            guard !isPreventedViolation(record) else { return false }
            return payloadObligationId(from: record) == targetObligationId
        }
    }

    private static func assertFailures(
        matching artifact: ObligationArtifact,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.assertFailed])
        )
        return records.filter { record in
            if payloadObligationId(from: record) == artifact.id { return true }
            if let message = record.payload?["message"]?.scalarDescription {
                return message == artifact.canonicalEnglish
            }
            return false
        }
    }

    private static func assertedPasses(
        matching artifact: ObligationArtifact,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.asserted])
        )
        return records.filter { record in
            if let message = record.payload?["message"]?.scalarDescription {
                return message == artifact.canonicalEnglish
            }
            return false
        }
    }

    static func coversInvoke(pattern: ActionPatternIR, record: TraceRecord) -> Bool {
        guard record.tag == .invoked else { return false }
        let tool = payloadToolID(from: record) ?? record.subject ?? ""
        guard normalizeToolID(pattern.toolID) == normalizeToolID(tool) else { return false }
        guard !pattern.argumentConstraints.isEmpty else { return true }
        guard let payload = record.payload else { return false }
        for constraint in pattern.argumentConstraints {
            guard let actual = payload[constraint.path] ?? payload[IdentifierNaming.camelPreservingCase(constraint.path)] else {
                return false
            }
            if case .literal(let expected) = constraint.value,
               !literalMatchesValue(expected, actual) {
                return false
            }
        }
        return true
    }

    static func isPreventedViolation(_ record: TraceRecord) -> Bool {
        guard record.tag == .violated else { return false }
        if record.payload?["disposition"] == .string(ViolationDisposition.prevented.rawValue) {
            return true
        }
        return record.operationalDetail?.localizedCaseInsensitiveContains("prevented") ?? false
    }

    static func payloadObligationId(from record: TraceRecord) -> String? {
        record.payload?["obligation_id"]?.scalarDescription
    }

    static func payloadToolID(from record: TraceRecord) -> String? {
        record.payload?["tool_id"]?.scalarDescription
    }

    private static func literalMatchesValue(_ literal: IRLiteral, _ value: Value) -> Bool {
        switch (literal, value) {
        case (.string(let expected), .string(let actual)):
            return expected == actual
        case (.number(let expected), .number(let actual)):
            return expected == actual
        case (.boolean(let expected), .boolean(let actual)):
            return expected == actual
        default:
            return false
        }
    }

    static func normalizeToolID(_ id: String) -> String {
        IdentifierNaming.methodize(id.trimmingCharacters(in: .whitespaces))
    }
}
