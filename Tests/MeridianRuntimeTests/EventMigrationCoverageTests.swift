import Foundation
import Testing
@testable import MeridianRuntime

@Suite("EventMigration coverage")
struct EventMigrationCoverageTests {

    private func event(
        _ kind: EventKind,
        payload: [String: Value] = [:],
        sequence: Int = 0
    ) -> Event {
        Event(
            timestamp: Date(timeIntervalSince1970: Double(sequence)),
            runID: "run-1",
            sequence: sequence,
            kind: kind,
            payload: payload
        )
    }

    @Test("TraceRecord(legacy:) maps every EventKind with subject priority")
    func legacyMappingMatrix() throws {
        var seq = 0
        func next(_ kind: EventKind, payload: [String: Value]) throws -> TraceRecord {
            defer { seq += 1 }
            return try TraceRecord(
                legacy: event(kind, payload: payload, sequence: seq),
                step: "s",
                skillName: "skill",
                skillVersionHash: "h",
                id: "id-\(seq)",
                ingestOrder: seq
            )
        }

        let workflow = try next(.workflowStarted, payload: ["workflow": .string("OrderFlow")])
        #expect(workflow.tag == .invoked)
        #expect(workflow.subject == "OrderFlow")

        let completed = try next(.workflowCompleted, payload: [:])
        #expect(completed.tag == .completed)
        #expect(completed.subject == "workflow")

        let cancelled = try next(.workflowCancelled, payload: ["kind": .string("signal")])
        #expect(cancelled.tag == .emitted)
        #expect(cancelled.outcome == .indeterminate)
        #expect(cancelled.subject == "signal")

        let invoke = try next(.invokeStart, payload: ["tool": .string("sendEmail")])
        #expect(invoke.tag == .invoked)
        #expect(invoke.subject == "sendEmail")

        let planError = try next(.planError, payload: ["event": .string("plan.x")])
        #expect(planError.tag == .judged)
        #expect(planError.outcome == .failure)
        #expect(planError.subject == "plan.x")

        let autonomyFail = try next(.autonomyStep, payload: [
            "tool": .string("act"),
            "status": .string("failure"),
        ])
        #expect(autonomyFail.outcome == .failure)

        let autonomyOK = try next(.autonomyEnd, payload: ["tool": .string("act")])
        #expect(autonomyOK.outcome == .success)

        let assertedIndeterminate = try next(.assertPassed, payload: [
            "outcome": .string(TruthValue.indeterminate.rawValue),
        ])
        #expect(assertedIndeterminate.tag == .asserted)
        #expect(assertedIndeterminate.outcome == .indeterminate)

        let emitError = try next(.emitError, payload: ["event": .string("x")])
        #expect(emitError.tag == .failed)
        #expect(emitError.operationalDetail == EventKind.emitError.rawValue)

        let violated = try next(.violated, payload: [
            "tool_id": .string("charge"),
            "disposition": .string("blocked"),
        ])
        #expect(violated.tag == .violated)
        #expect(violated.operationalDetail == "blocked")
        #expect(violated.subject == "charge")

        // Sweep remaining kinds so every switch arm is warm.
        for kind in EventKind.allCases {
            _ = try next(kind, payload: samplePayload(for: kind))
        }
    }

    private func samplePayload(for kind: EventKind) -> [String: Value] {
        switch kind {
        case .workflowStarted, .workflowCompleted, .workflowFailed:
            return ["workflow": .string("workflow")]
        case .invokeStart, .invokeEnd, .invokeError, .autonomyStep:
            return ["tool": .string("tool")]
        case .emit, .emitError:
            return ["event": .string("event")]
        case .waitStart:
            return ["kind": .string("signal")]
        case .assertPassed:
            return ["outcome": .string("true")]
        case .violated:
            return ["tool_id": .string("t"), "disposition": .string("prevented")]
        default:
            return ["message": .string(kind.rawValue)]
        }
    }
}
