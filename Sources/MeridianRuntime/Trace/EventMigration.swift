import Foundation

private struct LegacyTraceMapping {
    let tag: TraceTag
    let outcome: TraceOutcome?
    let operationalDetail: String?
    let subject: String?
}

private func legacyTraceMapping(for event: Event) -> LegacyTraceMapping {
    switch event.kind {
    case .workflowStarted:
        return LegacyTraceMapping(tag: .invoked, outcome: .success, operationalDetail: event.kind.rawValue, subject: event.payload["workflow"]?.scalarDescription ?? "workflow")
    case .workflowCompleted:
        return LegacyTraceMapping(tag: .completed, outcome: .success, operationalDetail: nil, subject: event.payload["workflow"]?.scalarDescription ?? "workflow")
    case .workflowFailed:
        return LegacyTraceMapping(tag: .failed, outcome: .failure, operationalDetail: nil, subject: event.payload["workflow"]?.scalarDescription ?? "workflow")
    case .workflowCancelled, .workflowSuspended, .workflowResumed, .bind, .waitStart, .waitResume:
        return LegacyTraceMapping(tag: .emitted, outcome: .indeterminate, operationalDetail: event.kind.rawValue, subject: legacySubject(for: event))
    case .invokeStart:
        return LegacyTraceMapping(tag: .invoked, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .invokeEnd:
        return LegacyTraceMapping(tag: .completed, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .invokeError:
        return LegacyTraceMapping(tag: .failed, outcome: .failure, operationalDetail: nil, subject: legacySubject(for: event))
    case .planStart, .planEnd:
        return LegacyTraceMapping(tag: .judged, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .planError, .planRejected:
        return LegacyTraceMapping(tag: .judged, outcome: .failure, operationalDetail: nil, subject: legacySubject(for: event))
    case .autonomyStart, .autonomyStep, .autonomyEnd:
        let outcome: TraceOutcome?
        if event.kind == .autonomyStep, event.payload["status"] == .string("failure") {
            outcome = .failure
        } else {
            outcome = .success
        }
        return LegacyTraceMapping(tag: .judged, outcome: outcome, operationalDetail: nil, subject: legacySubject(for: event))
    case .branchTaken, .branchEnded:
        return LegacyTraceMapping(tag: .branched, outcome: .success, operationalDetail: event.kind == .branchEnded ? event.kind.rawValue : nil, subject: legacySubject(for: event))
    case .iterateStart, .iterateIteration, .iterateEnd:
        return LegacyTraceMapping(tag: .iterated, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .assertPassed:
        let outcome: TraceOutcome = event.payload["outcome"] == .string(TruthValue.indeterminate.rawValue)
            ? .indeterminate
            : .success
        return LegacyTraceMapping(tag: .asserted, outcome: outcome, operationalDetail: nil, subject: legacySubject(for: event))
    case .assertFailed:
        return LegacyTraceMapping(tag: .assertFailed, outcome: .failure, operationalDetail: nil, subject: legacySubject(for: event))
    case .emit:
        return LegacyTraceMapping(tag: .emitted, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .emitError:
        return LegacyTraceMapping(tag: .failed, outcome: .failure, operationalDetail: event.kind.rawValue, subject: legacySubject(for: event))
    case .commit:
        return LegacyTraceMapping(tag: .committed, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .recoverEngaged:
        return LegacyTraceMapping(tag: .recovered, outcome: .success, operationalDetail: nil, subject: legacySubject(for: event))
    case .violated:
        let disposition = event.payload["disposition"]?.scalarDescription ?? "prevented"
        return LegacyTraceMapping(tag: .violated, outcome: .failure, operationalDetail: disposition, subject: event.payload["tool_id"]?.scalarDescription ?? legacySubject(for: event))
    }
}

private func legacySubject(for event: Event) -> String? {
    if let tool = event.payload["tool"]?.scalarDescription, !tool.isEmpty {
        return tool
    }
    if let emitted = event.payload["event"]?.scalarDescription, !emitted.isEmpty {
        return emitted
    }
    if let workflow = event.payload["workflow"]?.scalarDescription, !workflow.isEmpty {
        return workflow
    }
    if let kind = event.payload["kind"]?.scalarDescription, !kind.isEmpty {
        return kind
    }
    return nil
}

public extension TraceRecord {
    init(
        legacy event: Event,
        step: String,
        skillName: String,
        skillVersionHash: String,
        id: String,
        ingestOrder: Int,
        subject: String? = nil,
        subjectKey: String? = nil,
        payload: [String: Value]? = nil,
        hashedPayload: [String: Value]? = nil,
        witness: String? = nil
    ) throws {
        let mapping = legacyTraceMapping(for: event)
        let persistedPayload = payload ?? event.payload
        let canonicalPayload = hashedPayload ?? payload ?? event.payload
        self.init(
            id: id,
            at: event.timestamp,
            ingestOrder: ingestOrder,
            run: event.runID,
            step: step,
            skillName: skillName,
            skillVersionHash: skillVersionHash,
            tag: mapping.tag,
            subject: subject ?? mapping.subject,
            subjectKey: subjectKey,
            payload: persistedPayload.isEmpty ? nil : persistedPayload,
            payloadHash: try CanonicalJSON.sha256Hex(for: canonicalPayload),
            outcome: mapping.outcome,
            witness: witness,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: mapping.operationalDetail,
            legacyKind: event.kind.rawValue
        )
    }
}

public extension Event {
    init(fromSemantic record: TraceRecord) {
        let kind = EventKind(rawValue: record.legacyKind ?? "") ?? Event.projectedKind(from: record)
        self.init(
            timestamp: record.at,
            runID: record.run,
            sequence: record.ingestOrder,
            kind: kind,
            payload: record.payload ?? [:],
            sourceRange: nil,
            parentRunID: nil,
            parentSequence: nil
        )
    }

    private static func projectedKind(from record: TraceRecord) -> EventKind {
        switch record.tag {
        case .invoked:
            return .invokeStart
        case .completed:
            return record.subject == "workflow" ? .workflowCompleted : .invokeEnd
        case .failed:
            return record.subject == "workflow" ? .workflowFailed : .invokeError
        case .emitted:
            return .emit
        case .asserted:
            return .assertPassed
        case .assertFailed:
            return .assertFailed
        case .branched:
            if record.operationalDetail == EventKind.branchEnded.rawValue {
                return .branchEnded
            }
            return .branchTaken
        case .iterated:
            return .iterateIteration
        case .judged:
            return .planEnd
        case .committed:
            return .commit
        case .recovered:
            return .recoverEngaged
        case .violated:
            return .violated
        case .stateSnapshot:
            return .commit
        }
    }
}
