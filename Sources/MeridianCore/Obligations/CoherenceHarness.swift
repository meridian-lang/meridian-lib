import Foundation
import MeridianRuntime

public struct CoherenceDisagreement: Sendable, Equatable {
    public let obligationId: String
    public let runtimeEventIDs: [String]
    public let evaluatorCompliance: ObligationCompliance
    public let message: String

    public init(
        obligationId: String,
        runtimeEventIDs: [String],
        evaluatorCompliance: ObligationCompliance,
        message: String
    ) {
        self.obligationId = obligationId
        self.runtimeEventIDs = runtimeEventIDs.sorted()
        self.evaluatorCompliance = evaluatorCompliance
        self.message = message
    }
}

public struct CoherenceReport: Sendable, Equatable {
    public let disagreements: [CoherenceDisagreement]
    public let evaluationResults: [ObligationEvaluationResult]

    public var isCoherent: Bool { disagreements.isEmpty }

    public init(disagreements: [CoherenceDisagreement], evaluationResults: [ObligationEvaluationResult]) {
        self.disagreements = disagreements
        self.evaluationResults = evaluationResults
    }
}

/// Differential coherence harness (SEM-8-01): exec trace witnesses must agree with
/// independent obligation evaluation over the same trace.
public enum CoherenceHarness {

    public static func check(
        document: ObligationDocument,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> CoherenceReport {
        let results = try await ObligationEvaluator.evaluate(
            document: document,
            store: store,
            context: context
        )
        let byID = Dictionary(uniqueKeysWithValues: results.map { ($0.obligationId, $0) })
        var disagreements: [CoherenceDisagreement] = []

        let falsifying = try await falsifyingRuntimeEvents(
            document: document,
            store: store,
            context: context
        )

        for (obligationId, eventIDs) in falsifying.sorted(by: { $0.key < $1.key }) {
            guard let evaluation = byID[obligationId] else {
                disagreements.append(CoherenceDisagreement(
                    obligationId: obligationId,
                    runtimeEventIDs: eventIDs,
                    evaluatorCompliance: .indeterminate,
                    message: "runtime violation event(s) \(eventIDs.joined(separator: ", ")) cite obligation \(obligationId) but no matching artifact was evaluated"
                ))
                continue
            }
            if evaluation.compliance != .violated {
                disagreements.append(CoherenceDisagreement(
                    obligationId: obligationId,
                    runtimeEventIDs: eventIDs,
                    evaluatorCompliance: evaluation.compliance,
                    message: "runtime violation event(s) \(eventIDs.joined(separator: ", ")) falsify obligation \(obligationId) but evaluator reports \(evaluation.compliance.rawValue)"
                ))
            }
        }

        for result in results where result.compliance == .violated {
            let runtimeIDs = falsifying[result.obligationId] ?? []
            if runtimeIDs.isEmpty {
                disagreements.append(CoherenceDisagreement(
                    obligationId: result.obligationId,
                    runtimeEventIDs: result.witnessEventIDs,
                    evaluatorCompliance: result.compliance,
                    message: "evaluator reports violated for obligation \(result.obligationId) (witness \(result.witnessEventIDs.joined(separator: ", "))) but no matching runtime violated/assert-failed event"
                ))
            }
        }

        return CoherenceReport(disagreements: disagreements, evaluationResults: results)
    }

    /// Runtime events that falsify an obligation per SEM-7-02 / SEM-8-01.
    /// Prevented prohibition witnesses are excluded — they attest compliance.
    public static func falsifyingRuntimeEvents(
        document: ObligationDocument,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [String: [String]] {
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: context.runID,
            skillName: context.skillName,
            window: TraceWindow(end: context.evaluationInstant),
            pattern: TraceQueryPattern(tags: [.violated, .assertFailed])
        )

        var grouped: [String: [String]] = [:]

        for record in records {
            if record.tag == .violated, ObligationEvaluator.isPreventedViolation(record) {
                continue
            }

            if let obligationId = ObligationEvaluator.payloadObligationId(from: record) {
                grouped[obligationId, default: []].append(record.id)
                continue
            }

            if record.tag == .assertFailed,
               let message = record.payload?["message"]?.scalarDescription,
               let artifact = document.obligations.first(where: { $0.canonicalEnglish == message }) {
                grouped[artifact.id, default: []].append(record.id)
                continue
            }

            if record.tag == .violated,
               let tool = ObligationEvaluator.payloadToolID(from: record) ?? record.subject,
               let prohibition = document.obligations.first(where: {
                   $0.kind == .unreachability
                       && ProofIRReader.actionPattern(from: $0.actionProofIR).map {
                           ObligationEvaluator.normalizeToolID($0.toolID) == ObligationEvaluator.normalizeToolID(tool)
                       } == true
               }) {
                grouped[prohibition.id, default: []].append(record.id)
            }
        }

        for key in grouped.keys {
            grouped[key] = grouped[key]?.sorted()
        }
        return grouped
    }
}
